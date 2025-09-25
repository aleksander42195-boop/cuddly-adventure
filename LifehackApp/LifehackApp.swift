import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct LifehackApp: App {
    @StateObject private var engineManager = CoachEngineManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(engineManager)
                .onAppear {
                    AppTheme.configureGlobal()
                    AppBootstrap.configureNotifications()
                }
        }
    }
}
