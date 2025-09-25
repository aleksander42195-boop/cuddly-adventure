import Foundation
import UserNotifications

enum AppBootstrap {
    static func configureNotifications() {
        NotificationsManager.shared.configure()
        NotificationsManager.shared.registerCategories()
        NotificationsManager.shared.requestAuthorizationIfNeeded()
        UNUserNotificationCenter.current().delegate = NotificationsManager.shared
    }
}
