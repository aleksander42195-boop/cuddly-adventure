import Foundation

final class PPGProcessorDelegateAdapter: NSObject, PPGProcessorDelegate {
    typealias Handler = (Double) -> Void
    private let onSignalHandler: Handler
    private let onHRHandler: Handler
    private let onSDNNHandler: Handler
    private let wantsTorchHandler: () -> Bool

    init(onSignal: @escaping Handler, onHR: @escaping Handler, onSDNN: @escaping Handler, wantsTorch: @escaping () -> Bool) {
        self.onSignalHandler = onSignal
        self.onHRHandler = onHR
        self.onSDNNHandler = onSDNN
        self.wantsTorchHandler = wantsTorch
    }

    func ppgProcessor(_ p: PPGProcessor, didUpdateSignal value: Double) { onSignalHandler(value) }
    func ppgProcessor(_ p: PPGProcessor, didUpdateHeartRate bpm: Double) { onHRHandler(bpm) }
    func ppgProcessor(_ p: PPGProcessor, didComputeSDNN ms: Double) { onSDNNHandler(ms) }
    func ppgProcessorRequiresTorch(_ p: PPGProcessor) -> Bool { wantsTorchHandler() }
}
