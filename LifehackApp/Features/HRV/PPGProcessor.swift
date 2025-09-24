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
    private var samples: [Double] = []   // normalized intensity samples
    private var timestamps: [Double] = []
    private var lastSDNN: Double = 0

    // Config
    private let sampleRate: Double = 30.0 // approx; depends on device
    private let windowSeconds: Double = 45 // sliding window for SDNN

    func start() throws {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "PPG", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        // Orientation/connection
        output.connections.first?.videoOrientation = .portrait

        // Enable torch if desired
        if device.hasTorch && (delegate?.ppgProcessorRequiresTorch(self) ?? true) {
            try? device.lockForConfiguration()
            device.torchMode = .on
            try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel * 0.6)
            device.unlockForConfiguration()
        }

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
        samples.removeAll()
        timestamps.removeAll()
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

        // Append and keep sliding window
        samples.append(sample)
        timestamps.append(t)
        dropOldSamples(olderThan: t - windowSeconds)

        // Simple detrend + bandpass-like via moving average subtraction
        let filtered = movingAverageDetrend(samples, window: Int(sampleRate * 0.8))

        // Peak detection for RR intervals (basic method with refractory period)
        let (rr, hr) = detectRRAndHR(filtered: filtered, times: timestamps, minRR: 0.3, maxRR: 2.0)

        if let last = filtered.last { DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateSignal: last) } }
        if hr > 0 { DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didUpdateHeartRate: hr) } }

        let sdnn = sdnnMs(rr)
        if sdnn > 0, abs(sdnn - lastSDNN) > 1 {
            lastSDNN = sdnn
            DispatchQueue.main.async { self.delegate?.ppgProcessor(self, didComputeSDNN: sdnn) }
        }
    }

    private func dropOldSamples(olderThan cutoff: Double) {
        while let firstT = timestamps.first, firstT < cutoff {
            timestamps.removeFirst()
            samples.removeFirst()
        }
    }

    private func movingAverageDetrend(_ x: [Double], window: Int) -> [Double] {
        guard window > 1, x.count > window else { return x }
        var result = [Double](repeating: 0, count: x.count)
        var acc = 0.0
        for i in 0..<x.count {
            acc += x[i]
            if i >= window { acc -= x[i - window] }
            let mean = i >= window - 1 ? acc / Double(window) : acc / Double(i + 1)
            result[i] = x[i] - mean
        }
        return result
    }

    private func detectRRAndHR(filtered: [Double], times: [Double], minRR: Double, maxRR: Double) -> ([Double], Double) {
        guard filtered.count == times.count, filtered.count > 3 else { return ([], 0) }
        var peaks: [Int] = []
        let refractory = Int(sampleRate * 0.3)
        for i in 1..<(filtered.count - 1) {
            if filtered[i] > filtered[i - 1] && filtered[i] > filtered[i + 1] {
                if peaks.last.map({ i - $0 > refractory }) ?? true {
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
        let hr = rr.last.map { 60.0 / $0 } ?? 0
        return (rr, hr)
    }

    private func sdnnMs(_ rr: [Double]) -> Double {
        guard rr.count >= 5 else { return 0 }
        let mean = rr.reduce(0, +) / Double(rr.count)
        let variance = rr.reduce(0) { $0 + pow($1 - mean, 2) } / Double(rr.count)
        return sqrt(variance) * 1000.0
    }
}
