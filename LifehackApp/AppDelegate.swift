import UIKit

/// Optional UIKit AppDelegate scaffold (not active while SwiftUI @main exists).
/// Keep for future migration if you remove the SwiftUI @main entry point.
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Placeholder: configure analytics, logging, etc.
        return true
    }

    // Scene lifecycle is handled by SceneDelegate (below) when enabled in Info.plist
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
