import SwiftUI

@main
struct LifehackWatchApp: App {
    @StateObject private var vm = WatchChatViewModel(engine: ChatServiceAdapter())

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(vm)
        }
    }
}
