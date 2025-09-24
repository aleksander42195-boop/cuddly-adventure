import SwiftUI

@main
struct LifehackApp: App {
    @StateObject private var engineManager = CoachEngineManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(engineManager)
                .onAppear { AppTheme.configureGlobal() }
        }
    }
}
