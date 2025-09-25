import Foundation
import AVFoundation
import CoreImage
import Accelerate

protocol PPGProcessorDelegate: AnyObject {
    func ppgProcessor(_ p: PPGProcessor, didUpdateSignal value: Double)
    func ppgProcessor(_ p: PPGProcessor, didUpdateHeartRate bpm: Double)
    func ppgProcessor(_ p: PPGProcessor, didComputeSDNN ms: Double)
    func ppgProcessorRequiresTorch(_ p: PPGProcessor) -> Bool
}

final class PPGProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: PPGProcessorDelegate?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)
    private let queue = DispatchQueue(label: "ppg.processor.queue")

    // Signal processing state
    private var rawSamples: [Double] = []    // normalized intensity samples
    private var filteredSamples: [Double] = []
    private var timestamps: [Double] = []
    private var lastSDNN: Double = 0

    // Config
    private let sampleRate: Double = 30.0 // approx; depends on device
    private let windowSeconds: Double = 45 // sliding window for SDNN
    private let warmupSeconds: Double = 8

    // Band-pass filter params (~0.7–3.5 Hz)
    private let cutoffLowHz: Double = 0.7
    private let cutoffHighHz: Double = 3.5
    private var hpY: Double = 0
    private var hpXPrev: Double = 0
    private var lpY: Double = 0
    private var cameraDevice: AVCaptureDevice?

    func start() throws {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "PPG", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"])
        }
        let input = try AVCaptureDeviceInput(device: device)
    if session.canAddInput(input) { session.addInput(input) }
    cameraDevice = device

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        // Orientation/connection
        output.connections.first?.videoOrientation = .portrait

        // Enable torch if desired
        applyTorchState()

        session.commitConfiguration()
        session.startRunning()
    }

    func stop() {
        if let device = (session.inputs.first as? AVCaptureDeviceInput)?.device, device.hasTorch {
            try? device.lockForConfiguration()
            if device.isTorchActive { device.torchMode = .off }
            device.unlockForConfiguration()
        }
        session.stopRunning()
        rawSamples.removeAll()
        filteredSamples.removeAll()
        timestamps.removeAll()
        hpY = 0; hpXPrev = 0; lpY = 0
    }

    func setTorch(enabled: Bool) {
        guard let device = cameraDevice, device.hasTorch else { return }
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
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let t = time.seconds

        // Compute mean intensity from luma plane (Y) in a central ROI
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

        let width = CVPixelBufferGetWidthOfPlane(pb, 0)
        let height = CVPixelBufferGetHeightOfPlane(pb, 0)
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pb, 0) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)

        // Central 40% ROI
        let roiW = width * 2 / 5
        let roiH = height * 2 / 5
        let startX = (width - roiW) / 2
        let startY = (height - roiH) / 2

        var sum: UInt64 = 0
        for y in 0..<roiH {
            let row = base.advanced(by: (startY + y) * bytesPerRow + startX)
            let buf = UnsafeBufferPointer<UInt8>(start: row.assumingMemoryBound(to: UInt8.self), count: roiW)
            sum += buf.reduce(0) { $0 + UInt64($1) }
        }
        let mean = Double(sum) / Double(roiW * roiH) / 255.0

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

        if let last = filtered.last { DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateSignal: last) } }
        let duration = (timestamps.last ?? 0) - (timestamps.first ?? 0)
        if hr > 0, duration >= warmupSeconds { DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateHeartRate: hr) } }

        let sdnn = sdnnMs(rr)
        if sdnn > 0, duration >= warmupSeconds, abs(sdnn - lastSDNN) > 1 {
            lastSDNN = sdnn
            DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didComputeSDNN: sdnn) }
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
        if rr.isEmpty { hr = 0 } else {
            let tail = Array(rr.suffix(5)).sorted()
            let median = tail[tail.count / 2]
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
