import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

import SwiftUI

@main
struct LifehackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var coachEngineManager = CoachEngineManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize app lifecycle management directly
        AppTheme.configureGlobal()
        NotificationsManager.shared.configure()
        // Start global lifecycle monitor for safe shutdowns
        LifecycleManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .environmentObject(coachEngineManager)
                .onAppear {
                    AppTheme.configureGlobal()
                    AppBootstrap.configureNotifications()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    private func setupAppLifecycle() {
        // Setup global configuration for app lifecycle
        setupGlobalConfiguration()
        setupExceptionHandling()
        
        // Initialize services
        NotificationsManager.shared.configure()
        NotificationsManager.shared.registerCategories()
        NotificationsManager.shared.requestAuthorizationIfNeeded()
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
        #if canImport(UIKit)
        NSSetUncaughtExceptionHandler { exception in
            print("Uncaught exception: \(exception)")
            // Save critical state before potential crash
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "app_last_crash")
            UserDefaults.standard.synchronize()
            AppGroup.defaults.synchronize()
        }
        #endif
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase?, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("App moved to background - saving state")
            AppBootstrap.saveAppState()
            saveForBackground()
            NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
        case .inactive:
            print("App became inactive - cleaning up operations")
            AppBootstrap.cleanupActiveOperations()
            NotificationCenter.default.post(name: .appSafeShutdown, object: nil)
        case .active:
            print("App became active - restoring state")
            AppBootstrap.restoreAppState()
        @unknown default:
            break
        }
    }
    
    private func saveForBackground() {
        // Save state when app goes to background
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "app_last_background")
        UserDefaults.standard.synchronize()
        AppGroup.defaults.synchronize()
    }
}
