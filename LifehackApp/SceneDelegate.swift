import UIKit
import SwiftUI

/// SceneDelegate wraps the existing SwiftUI ContentView if UIKit lifecycle is ever enabled.
/// Current app still launches via SwiftUI @main; this file is inert until Info.plist SceneManifest is configured.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let appState = AppState()

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let rootSwiftUI = ContentView()
            .environmentObject(appState)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootSwiftUI)
        self.window = window
        window.makeKeyAndVisible()
    }
}
