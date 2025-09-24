//
//  AppDelegate.swift
//  LifehackApp
//
//  Created for iOS device compatibility management
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Initialize device manager
        let deviceManager = DeviceManager.shared
        
        // Log current device info for debugging
        if let currentDevice = deviceManager.getCurrentDevice() {
            print("App launched on: \(deviceManager.getDeviceDisplayName(for: currentDevice))")
        } else {
            print("App launched on unknown device")
        }
        
        // Notifications
        NotificationsManager.shared.configure()
    NotificationsManager.shared.registerCategories()
        NotificationsManager.shared.requestAuthorizationIfNeeded()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle custom actions first
        NotificationsManager.shared.handleAction(response: response)
        if let urlString = response.notification.request.content.userInfo["studyURL"] as? String,
           let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        completionHandler()
    }
}
