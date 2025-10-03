import Foundation

extension Notification.Name {
    /// Generic notification broadcast signaling that long-running operations must stop safely.
    static let appSafeShutdown = Notification.Name("app.safe.shutdown")

    /// Specific legacy notification used by HRV capture to stop measurement.
    static let hrvStopMeasurement = Notification.Name("hrv.stop.measurement")
}
