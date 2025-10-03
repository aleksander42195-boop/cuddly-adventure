//
//  AppDelegate.swift
//  LifehackApp
//
//  Created for iOS device compatibility management
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Initialize app lifecycle management
        setupAppLifecycle()
        // Start global lifecycle observer to broadcast safe-shutdown signals
        LifecycleManager.shared.start()
        
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
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // App moved to background - save critical state
        print("App entering background - saving state")
        AppBootstrap.saveAppState()
        // Broadcast safe shutdown
        NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // App becoming inactive - prepare for possible termination
        print("App will resign active - preparing for inactive")
        AppBootstrap.cleanupActiveOperations()
        // Broadcast safe shutdown
        NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // App became active - restore state if needed
        print("App became active - restoring state")
        AppBootstrap.restoreAppState()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // App will terminate - save critical state
        print("App will terminate - performing final save")
        saveForTermination()
        // Broadcast safe shutdown
        NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
    }
    
    private func setupAppLifecycle() {
        // Setup global configuration for app lifecycle
        setupGlobalConfiguration()
        setupExceptionHandling()
    }
    
    private func setupGlobalConfiguration() {
        // Configure global app settings
        UserDefaults.standard.register(defaults: [
            "app_initialized": true,
            "first_launch": !UserDefaults.standard.bool(forKey: "has_launched_before")
        ])
        
        // Mark that we've launched before
        UserDefaults.standard.set(true, forKey: "has_launched_before")
        UserDefaults.standard.synchronize()
    }
    
    private func setupExceptionHandling() {
        // Setup crash handling to prevent corruption
        NSSetUncaughtExceptionHandler { exception in
            print("Uncaught exception: \(exception)")
            // Save critical state before potential crash
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "app_last_crash")
            UserDefaults.standard.synchronize()
            AppGroup.defaults.synchronize()
        }
    }
    
    private func saveForTermination() {
        // Perform final cleanup before termination
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "app_last_termination")
        UserDefaults.standard.synchronize()
        AppGroup.defaults.synchronize()
        
        // Give the system time to save
        Thread.sleep(forTimeInterval: 0.1)
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
