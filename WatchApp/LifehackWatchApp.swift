import SwiftUI

@main
struct LifehackWatchApp: App {
    @StateObject private var vm = WatchChatViewModel(engine: ChatServiceAdapter())

    var body: some Scene {
        WindowGroup {
            WatchChatView()
                .environmentObject(vm)
        }
    }
}
