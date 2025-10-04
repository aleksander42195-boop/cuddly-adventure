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

    // Config
    private let sampleRate: Double = 30.0 // approx; depends on device
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

    // Expose session for preview rendering
    var captureSession: AVCaptureSession { session }

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
                if dev.activeVideoMinFrameDuration != CMTime(value: 1, timescale: 30) {
                    dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
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
            Self.logger.notice("PPG session running; applying torch state")
            // Apply desired torch after session starts to avoid configuration conflicts
            self.applyTorchState()
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
    }

    func setTorch(enabled: Bool) {
        guard let device = cameraDevice, device.hasTorch else { return }
    let torchState = enabled ? "ON" : "OFF"
    Self.logger.notice("PPG torch set to \(torchState, privacy: .public)")
        try? device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if enabled {
            device.torchMode = .on
            try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel * 0.6)
        } else {
            device.torchMode = .off
        }
    }

    private func applyTorchState() {
        let wants = delegate?.ppgProcessorRequiresTorch(self) ?? true
        setTorch(enabled: wants)
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        @autoreleasepool {
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

            // Central 40% ROI, sample every 4th pixel in x/y to reduce work ~16x
            let roiW = width * 2 / 5
            let roiH = height * 2 / 5
            let startX = (width - roiW) / 2
            let startY = (height - roiH) / 2
            let stride = 4

            var sum: UInt64 = 0
            var count: Int = 0
            for y in stride(from: 0, to: roiH, by: stride) {
                let rowBase = base.advanced(by: (startY + y) * bytesPerRow + startX)
                let ptr = rowBase.assumingMemoryBound(to: UInt8.self)
                var x = 0
                while x < roiW {
                    sum &+= UInt64(ptr[x])
                    count &+= 1
                    x &+= stride
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
            dropOldSamples(olderThan: t - windowSeconds)

            // Use filteredSamples for HR/RR estimation
            let filtered = filteredSamples

            // Peak detection with adaptive thresholds
            let (rr, hr) = detectRRAndHR(filtered: filtered, times: timestamps, minRR: 0.3, maxRR: 2.0)

            // Throttle signal callback to main thread
            if let last = filtered.last {
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

            let sdnn = sdnnMs(rr)
            if sdnn > 0, duration >= warmupSeconds, abs(sdnn - lastSDNN) > 1 {
                lastSDNN = sdnn
                DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didComputeSDNN: sdnn) }
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

    private func detectRRAndHR(filtered: [Double], times: [Double], minRR: Double, maxRR: Double) -> ([Double], Double) {
        guard filtered.count == times.count, filtered.count > 5 else { return ([], 0) }
        // Adaptive threshold based on recent window statistics
        let window = min(Int(sampleRate * 3.0), filtered.count)
        let recent = Array(filtered.suffix(window))
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.reduce(0) { $0 + pow($1 - mean, 2) } / Double(recent.count)
        let std = max(1e-6, sqrt(variance))
        let threshold = mean + 0.5 * std

        var peaks: [Int] = []
        let refractorySamples = Int(sampleRate * minRR * 0.8) // a bit stricter
        
        // Ensure we have enough samples for safe indexing
        guard filtered.count >= 5 else { return ([], 0) }
        
        for i in 2..<(filtered.count - 2) {
            let y0 = filtered[i - 1]
            let y1 = filtered[i]
            let y2 = filtered[i + 1]
            // Local maximum + above dynamic threshold
            if y1 > y0 && y1 > y2 && y1 > threshold {
                if peaks.last.map({ i - $0 > refractorySamples }) ?? true {
                    peaks.append(i)
                }
            }
        }
        guard peaks.count >= 2 else { return ([], 0) }
        var rr: [Double] = []
        for i in 1..<peaks.count {
            let dt = times[peaks[i]] - times[peaks[i - 1]]
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
