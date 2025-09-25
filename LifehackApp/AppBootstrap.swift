import Foundation
import UserNotifications
import UIKit

enum AppBootstrap {
    private static let lastLaunchKey = "app_last_successful_launch"
    private static let appStateKey = "app_persistent_state"
    
    static func configureNotifications() {
        NotificationsManager.shared.configure()
        NotificationsManager.shared.registerCategories()
        NotificationsManager.shared.requestAuthorizationIfNeeded()
        UNUserNotificationCenter.current().delegate = NotificationsManager.shared
    }
    
    static func saveAppState() {
        let currentTime = Date().timeIntervalSince1970
        UserDefaults.standard.set(currentTime, forKey: lastLaunchKey)
        
        // Save app state dictionary
        let appState: [String: Any] = [
            "lastActiveTime": currentTime,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        ]
        
        UserDefaults.standard.set(appState, forKey: appStateKey)
        UserDefaults.standard.synchronize()
        
        // Also save to app group for widget/extension access
        AppGroup.defaults.set(currentTime, forKey: lastLaunchKey)
        AppGroup.defaults.synchronize()
    }
    
    static func restoreAppState() {
        let lastLaunch = UserDefaults.standard.double(forKey: lastLaunchKey)
        let currentTime = Date().timeIntervalSince1970
        
        // Check if app was cleanly shut down (last launch was recent)
        let timeSinceLastLaunch = currentTime - lastLaunch
        
        if timeSinceLastLaunch > 300 { // 5 minutes
            // App may have crashed or been force-killed, perform cleanup
            performCrashRecovery()
        }
        
        // Update last launch time
        UserDefaults.standard.set(currentTime, forKey: lastLaunchKey)
        UserDefaults.standard.synchronize()
    }
    
    static func cleanupActiveOperations() {
        // Cancel any background tasks
        UIApplication.shared.endBackgroundTask(.invalid)
        
        // Clean up network operations
        URLSession.shared.invalidateAndCancel()
        
        // Force save any pending UserDefaults
        UserDefaults.standard.synchronize()
        AppGroup.defaults.synchronize()
    }
    
    private static func performCrashRecovery() {
        // Clear any corrupted temporary data
        clearTemporaryData()
        
        // Reset any flags that might prevent proper startup
        UserDefaults.standard.removeObject(forKey: "pendingOperations")
        UserDefaults.standard.synchronize()
    }
    
    private static func clearTemporaryData() {
        // Clear temporary files and caches
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDir)
            for file in tempFiles {
                let filePath = (tempDir as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
        } catch {
            print("Failed to clear temporary data: \(error)")
        }
    }
}
