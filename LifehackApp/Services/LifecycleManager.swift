import Foundation
import UIKit

/// Posts a global safe-shutdown notification when the app is interrupted, backgrounded, or terminating.
/// Any long-running operation (camera capture, network streams, timers) can observe `.appSafeShutdown` and stop cleanly.
final class LifecycleManager {
    static let shared = LifecycleManager()
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        let add: (Notification.Name) -> Void = { name in
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.broadcastSafeShutdown()
            }
            self.observers.append(token)
        }

        add(UIApplication.willResignActiveNotification)
        add(UIApplication.didEnterBackgroundNotification)
        add(UIApplication.willTerminateNotification)
    }

    func stop() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func broadcastSafeShutdown() {
        // Notify feature-specific listeners first (legacy compatibility), then generic safe-shutdown.
        NotificationCenter.default.post(name: .hrvStopMeasurement, object: nil)
        NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
        // Give shared app bootstrap a chance to clean up as well.
        AppBootstrap.cleanupActiveOperations()
    }
}
