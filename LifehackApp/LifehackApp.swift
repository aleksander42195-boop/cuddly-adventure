import SwiftUI
import UIKit

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
