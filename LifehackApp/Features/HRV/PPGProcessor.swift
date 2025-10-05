import Foundation
import AVFoundation
import CoreImage
import Accelerate
import OSLog
import QuartzCore

protocol PPGProcessorDelegate: AnyObject {
    func ppgProcessor(_ p: PPGProcessor, didUpdateSignal value: Double)
    func ppgProcessor(_ p: PPGProcessor, didUpdateHeartRate bpm: Double)
    func ppgProcessor(_ p: PPGProcessor, didComputeSDNN ms: Double)
    func ppgProcessorRequiresTorch(_ p: PPGProcessor) -> Bool
    func ppgProcessorDidStartStreaming(_ p: PPGProcessor)
}

final class PPGProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let logger = Logger(subsystem: "com.lifehack.LifehackApp", category: "PPG")
    weak var delegate: PPGProcessorDelegate?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)
    private let queue = DispatchQueue(label: "ppg.processor.queue")
    private var isRunning = false

    // Signal processing state
    private var rawSamples: [Double] = []    // normalized intensity samples
    private var filteredSamples: [Double] = []
    private var timestamps: [Double] = []
    private var lastSDNN: Double = 0
    private var lastComputeStamp: CFTimeInterval = 0
    private let computeInterval: CFTimeInterval = 0.25 // run HR/SDNN detection at most 4 Hz

    // Config
    private let sampleRate: Double = 20.0 // target; we cap device FPS to reduce load
    private let windowSeconds: Double = 180 // sliding window for SDNN (3 minutes)
    private let warmupSeconds: Double = 8

    // Band-pass filter params (~0.7–3.5 Hz)
    private let cutoffLowHz: Double = 0.7
    private let cutoffHighHz: Double = 3.5
    private var hpY: Double = 0
    private var hpXPrev: Double = 0
    private var lpY: Double = 0
    private var cameraDevice: AVCaptureDevice?
    private var lastSignalDispatch: CFTimeInterval = 0
    private let signalDispatchInterval: CFTimeInterval = 0.1 // 10 Hz max to UI
    private var didReceiveFirstFrame = false
    private var startDeadline: DispatchTime?
    private var thermalObserver: NSObjectProtocol?
    private var sessionObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var interruptionEndedObserver: NSObjectProtocol?
    private var torchRampWorkItem: DispatchWorkItem?
    private var torchRampID: Int = 0
    private var currentTorchTargetFraction: Float = 0.25 // 0..1 user-level fraction
    private var currentThermalState: ProcessInfo.ThermalState = .nominal

    // Expose session for preview rendering
    var captureSession: AVCaptureSession { session }

    override init() {
        super.init()
        // Observe thermal state to reduce load if device overheats
        thermalObserver = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            let state = ProcessInfo.processInfo.thermalState
            self.currentThermalState = state
            Self.logger.notice("Thermal state changed: \(state.rawValue, privacy: .public)")
            switch state {
            case .nominal:
                break
            case .fair:
                break
            case .moderate:
                // Dim torch in moderate state to reduce heat
                self.queue.async { [weak self] in
                    guard let self, let dev = self.cameraDevice, dev.hasTorch else { return }
                    if dev.isTorchActive {
                        let dimmed = max(0.1, self.currentTorchTargetFraction * 0.5)
                        self.applyTorchLevelFraction(dimmed)
                        Self.logger.notice("PPG torch dimmed due to moderate thermal: targetFraction=\(self.currentTorchTargetFraction, privacy: .public) -> dim \(dimmed, privacy: .public)")
                    }
                }
            case .serious, .critical:
                // Turn off torch to reduce heat
                self.queue.async { self.setTorch(enabled: false) }
            @unknown default:
                break
            }
        }
    }

    func start() throws {
        if isRunning { return }
        // Prepare camera input synchronously to throw if unavailable
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "PPG", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        cameraDevice = device
        // Configure and start on the processing queue to avoid blocking UI
        queue.async {
            Self.logger.notice("PPG start: configuring session")
            self.session.beginConfiguration()
            // Lower resolution reduces pixel buffer allocations and CPU load
            self.session.sessionPreset = .low
            if self.session.inputs.isEmpty, self.session.canAddInput(input) { self.session.addInput(input) }
            self.output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            self.output.alwaysDiscardsLateVideoFrames = true
            // Prefer luma-only and cap frame rate to reduce memory pressure
            if let dev = self.cameraDevice {
                try? dev.lockForConfiguration()
                // Cap FPS to ~20 to avoid buffer pressure
                if dev.activeVideoMinFrameDuration != CMTime(value: 1, timescale: 20) {
                    dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                    dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 20)
                }
                dev.unlockForConfiguration()
            }
            self.output.setSampleBufferDelegate(self, queue: self.queue)
            if self.session.outputs.isEmpty, self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
            // Orientation/connection
            if #available(iOS 17.0, *) {
                self.output.connections.first?.videoRotationAngle = 0
            } else {
                self.output.connections.first?.videoOrientation = .portrait
            }
            self.session.commitConfiguration()
            // Torch configuration requires locking the device; do it safely on queue
            if let dev = self.cameraDevice, dev.hasTorch {
                try? dev.lockForConfiguration()
                if dev.isTorchActive { dev.torchMode = .off }
                dev.unlockForConfiguration()
            }
            // Start session on a non-main queue, but ensure we don't block UI
            self.session.startRunning()
            self.isRunning = true
            self.didReceiveFirstFrame = false
            self.startDeadline = .now() + .seconds(8)
            Self.logger.notice("PPG session running; awaiting first frame before torch")
            // Observe runtime errors to notify UI promptly
            self.sessionObserver = NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError, object: self.session, queue: nil) { [weak self] n in
                guard let self, let err = n.userInfo?[AVCaptureSessionErrorKey] as? NSError else { return }
                Self.logger.error("AVCaptureSession runtime error: \(err.localizedDescription, privacy: .public)")
                // Stop to allow UI to restart
                self.stop()
            }
            // Observe interruptions (e.g., camera in use by another app)
            self.interruptionObserver = NotificationCenter.default.addObserver(forName: .AVCaptureSessionWasInterrupted, object: self.session, queue: nil) { [weak self] n in
                guard let self else { return }
                Self.logger.notice("AVCaptureSession was interrupted: \(String(describing: n.userInfo), privacy: .public)")
                // Turn off torch immediately
                self.queue.async { self.setTorch(enabled: false) }
            }
            self.interruptionEndedObserver = NotificationCenter.default.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: self.session, queue: nil) { [weak self] _ in
                guard let self else { return }
                Self.logger.notice("AVCaptureSession interruption ended")
                // Auto-retry if we intended to run but session isn't running
                self.queue.async {
                    if self.isRunning && !self.session.isRunning {
                        Self.logger.notice("PPG auto-retry after interruption end")
                        self.softRestartConservative()
                    }
                }
            }
        }
    }

    func stop() {
        if !isRunning { return }
        queue.async {
            Self.logger.notice("PPG stop: stopping session and torch")
            if let device = (self.session.inputs.first as? AVCaptureDeviceInput)?.device, device.hasTorch {
                try? device.lockForConfiguration()
                if device.isTorchActive { device.torchMode = .off }
                device.unlockForConfiguration()
            }
            if self.session.isRunning { self.session.stopRunning() }
            self.isRunning = false
            self.rawSamples.removeAll()
            self.filteredSamples.removeAll()
            self.timestamps.removeAll()
            self.hpY = 0; self.hpXPrev = 0; self.lpY = 0
            Self.logger.notice("PPG stopped and buffers cleared")
        }
    }

    deinit {
        stop()
        if let obs = thermalObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = sessionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionEndedObserver { NotificationCenter.default.removeObserver(obs) }
    }

    func setTorch(enabled: Bool, ramp: Bool = false) {
        guard let device = cameraDevice, device.hasTorch else { return }
        // Cancel any ongoing ramp
        queue.async {
            self.torchRampWorkItem?.cancel(); self.torchRampWorkItem = nil
            self.torchRampID &+= 1
            let rampID = self.torchRampID
            let torchState = enabled ? "ON" : "OFF"
            Self.logger.notice("PPG torch set to \(torchState, privacy: .public) ramp=\(ramp, privacy: .public)")
            guard enabled else {
                try? device.lockForConfiguration(); if device.isTorchActive { device.torchMode = .off }; device.unlockForConfiguration(); return
            }
            // Don't enable torch in serious/critical thermal
            if self.currentThermalState == .serious || self.currentThermalState == .critical {
                Self.logger.notice("PPG torch enable suppressed due to thermal state \(self.currentThermalState.rawValue, privacy: .public)")
                return
            }
            guard device.isTorchModeSupported(.on) else { return }
            // Effective target fraction from user defaults (0..1)
            let stored = UserDefaults.standard.double(forKey: "ppgTorchLevel")
            var targetFraction = Float(stored > 0 ? stored : 0.25)
            if self.currentThermalState == .moderate {
                targetFraction = max(0.1, min(targetFraction * 0.5, targetFraction))
            }
            self.currentTorchTargetFraction = targetFraction
            let maxLevel = min(AVCaptureDevice.maxAvailableTorchLevel, 1.0)
            let targetLevel = maxLevel * targetFraction
            // Start level for ramp
            let startLevel = min(targetLevel, maxLevel * 0.10)
            if ramp {
                try? device.lockForConfiguration()
                device.torchMode = .on
                try? device.setTorchModeOn(level: startLevel)
                device.unlockForConfiguration()
                // Ramp in steps to target over ~1.2s
                let steps = 6
                let stepDuration: TimeInterval = 0.2
                for i in 1...steps {
                    let delay = stepDuration * Double(i)
                    self.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self else { return }
                        // Cancel if a new ramp started
                        guard self.torchRampID == rampID else { return }
                        guard let dev = self.cameraDevice, dev.hasTorch else { return }
                        let fraction = Float(i) / Float(steps)
                        let level = startLevel + (targetLevel - startLevel) * fraction
                        try? dev.lockForConfiguration()
                        if dev.isTorchModeSupported(.on) { try? dev.setTorchModeOn(level: level) }
                        dev.unlockForConfiguration()
                    }
                }
            } else {
                try? device.lockForConfiguration()
                device.torchMode = .on
                try? device.setTorchModeOn(level: targetLevel)
                device.unlockForConfiguration()
            }
        }
    }

    private func applyTorchState() {
        let wants = delegate?.ppgProcessorRequiresTorch(self) ?? true
        setTorch(enabled: wants)
    }

    private func applyTorchLevelFraction(_ fraction: Float) {
        guard let device = cameraDevice, device.hasTorch else { return }
        let maxLevel = min(AVCaptureDevice.maxAvailableTorchLevel, 1.0)
        let level = maxLevel * fraction
        try? device.lockForConfiguration()
        if device.isTorchModeSupported(.on) {
            if !device.isTorchActive { device.torchMode = .on }
            try? device.setTorchModeOn(level: level)
        }
        device.unlockForConfiguration()
    }

    // Conservative soft restart: lower preset and fps, keep torch off; used if no frames arrive
    func softRestartConservative(completion: (() -> Void)? = nil) {
        queue.async {
            Self.logger.notice("PPG softRestartConservative invoked")
            if self.session.isRunning { self.session.stopRunning() }
            self.session.beginConfiguration()
            // Keep existing input
            self.session.sessionPreset = .vga640x480
            if let dev = self.cameraDevice {
                try? dev.lockForConfiguration()
                dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
                dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                if dev.hasTorch && dev.isTorchActive { dev.torchMode = .off }
                dev.unlockForConfiguration()
            }
            self.session.commitConfiguration()
            self.didReceiveFirstFrame = false
            self.lastSignalDispatch = 0
            self.startDeadline = .now() + .seconds(8)
            self.session.startRunning()
            self.isRunning = true
            Self.logger.notice("PPG soft restart completed; waiting for frames")
            if let completion { DispatchQueue.main.async { completion() } }
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            if !didReceiveFirstFrame {
                didReceiveFirstFrame = true
                DispatchQueue.main.async { self.delegate?.ppgProcessorDidStartStreaming(self) }
            }
            guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let t = time.seconds

            // Compute mean intensity from luma plane (Y) in a central ROI, with subsampling for performance
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

            let width = CVPixelBufferGetWidthOfPlane(pb, 0)
            let height = CVPixelBufferGetHeightOfPlane(pb, 0)
            guard let base = CVPixelBufferGetBaseAddressOfPlane(pb, 0) else { return }
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)

            // Central ~30% ROI, sample every 6th pixel in x/y to reduce work further
            let roiW = max(1, width * 3 / 10)
            let roiH = max(1, height * 3 / 10)
            let startX = (width - roiW) / 2
            let startY = (height - roiH) / 2
            let step = 6

            var sum: UInt64 = 0
            var count: Int = 0
            for y in Swift.stride(from: 0, to: roiH, by: step) {
                let rowBase = base.advanced(by: (startY + y) * bytesPerRow + startX)
                let ptr = rowBase.assumingMemoryBound(to: UInt8.self)
                var x = 0
                while x < roiW {
                    sum &+= UInt64(ptr[x])
                    count &+= 1
                    x &+= step
                }
            }
            guard count > 0 else { return }
            let mean = Double(sum) / Double(count) / 255.0

            // Invert (blood volume pulse correlates with lower intensity when finger covers lens)
            let sample = 1.0 - mean

            // Band-pass filter (HP then LP) and append
            let band = bandpass(sample)
            rawSamples.append(sample)
            filteredSamples.append(band)
            timestamps.append(t)
            // Bound arrays by trimming occasionally (avoid per-frame O(n) removeFirst)
            let maxSamples = Int(sampleRate * 200) // keep ~10 seconds extra headroom beyond target window
            if filteredSamples.count > maxSamples {
                let drop = filteredSamples.count - maxSamples
                filteredSamples.removeFirst(drop)
                rawSamples.removeFirst(min(drop, rawSamples.count))
                timestamps.removeFirst(min(drop, timestamps.count))
            }

            // Use filteredSamples for HR/RR estimation, but compute at most 4 Hz and only on a recent window
            var rr: [Double] = []
            var hr: Double = 0
            let nowStamp = CACurrentMediaTime()
            if nowStamp - lastComputeStamp >= computeInterval {
                lastComputeStamp = nowStamp
                // Take a recent window (e.g., last 120s) to reduce compute
                let computeWindow: Double = min(120, windowSeconds)
                let tLast = timestamps.last ?? t
                var startIdx = 0
                // Find first index within window by scanning backwards (cheap at these sizes)
                for i in (0..<(timestamps.count)).reversed() {
                    if tLast - timestamps[i] <= computeWindow { startIdx = i } else { break }
                }
                let filteredSlice = filteredSamples[startIdx..<filteredSamples.count]
                let timeSlice = timestamps[startIdx..<timestamps.count]
                (rr, hr) = detectRRAndHR(filtered: filteredSlice, times: timeSlice, minRR: 0.3, maxRR: 2.0)
            }

            // Throttle signal callback to main thread
            if let last = filteredSamples.last {
                let now = CACurrentMediaTime()
                if now - lastSignalDispatch >= signalDispatchInterval {
                    lastSignalDispatch = now
                    DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateSignal: last) }
                }
            }

            let duration = (timestamps.last ?? 0) - (timestamps.first ?? 0)
            if hr > 0, duration >= warmupSeconds {
                DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateHeartRate: hr) }
            }

            if !rr.isEmpty {
                let sdnn = sdnnMs(rr)
                if sdnn > 0, duration >= warmupSeconds, abs(sdnn - lastSDNN) > 1 {
                    lastSDNN = sdnn
                    DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didComputeSDNN: sdnn) }
                }
            }
        }
    }

    private func dropOldSamples(olderThan cutoff: Double) {
        while let firstT = timestamps.first, firstT < cutoff {
            timestamps.removeFirst()
            rawSamples.removeFirst()
            filteredSamples.removeFirst()
        }
    }

    // Simple 1st-order HP then LP to approximate band-pass
    private func bandpass(_ x: Double) -> Double {
        // High-pass
        let dt = 1.0 / sampleRate
        let rcHigh = 1.0 / (2 * Double.pi * cutoffLowHz)
        let alphaHigh = rcHigh / (rcHigh + dt)
        hpY = alphaHigh * (hpY + x - hpXPrev)
        hpXPrev = x
        // Low-pass
        let rcLow = 1.0 / (2 * Double.pi * cutoffHighHz)
        let alphaLow = dt / (rcLow + dt)
        lpY = lpY + alphaLow * (hpY - lpY)
        return lpY
    }

    private func detectRRAndHR(filtered: ArraySlice<Double>, times: ArraySlice<Double>, minRR: Double, maxRR: Double) -> ([Double], Double) {
        guard filtered.count == times.count, filtered.count > 5 else { return ([], 0) }
        // Adaptive threshold based on recent window statistics
        let window = min(Int(sampleRate * 3.0), filtered.count)
        let recent = filtered.suffix(window)
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recent.count)
        let std = max(1e-6, sqrt(variance))
        let threshold = mean + 0.5 * std

        var peaks: [Int] = []
        let refractorySamples = Int(sampleRate * minRR * 0.8) // a bit stricter
        
        // Ensure we have enough samples for safe indexing
        guard filtered.count >= 5 else { return ([], 0) }
        
        let base = filtered.startIndex
        for i in (base+2)..<(filtered.endIndex - 2) {
            let y0 = filtered[i - 1]
            let y1 = filtered[i]
            let y2 = filtered[i + 1]
            // Local maximum + above dynamic threshold
            if y1 > y0 && y1 > y2 && y1 > threshold {
                if peaks.last.map({ (i - (base + $0)) > refractorySamples }) ?? true {
                    peaks.append(i - base)
                }
            }
        }
        guard peaks.count >= 2 else { return ([], 0) }
        var rr: [Double] = []
        for i in 1..<peaks.count {
            let dt = times[base + peaks[i]] - times[base + peaks[i - 1]]
            if dt >= minRR && dt <= maxRR { rr.append(dt) }
        }
        // Heart rate from median of last few RR for stability
        let hr: Double
        if rr.isEmpty { 
            hr = 0 
        } else {
            let tail = Array(rr.suffix(5)).sorted()
            guard !tail.isEmpty else { hr = 0; return (rr, hr) }
            
            // Proper median calculation
            let median = tail.count % 2 == 1 
                ? tail[tail.count / 2] 
                : (tail[tail.count / 2 - 1] + tail[tail.count / 2]) / 2.0
            hr = 60.0 / median
        }
        return (rr, hr)
    }

    private func sdnnMs(_ rr: [Double]) -> Double {
        guard rr.count >= 5 else { return 0 }
        let mean = rr.reduce(0, +) / Double(rr.count)
        let variance = rr.reduce(0) { $0 + pow($1 - mean, 2) } / Double(rr.count)
        return sqrt(variance) * 1000.0
    }
}
