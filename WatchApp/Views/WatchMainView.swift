import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject private var vm: WatchChatViewModel
    
    var body: some View {
        TabView {
            // Training View
            WatchTrainingView()
                .tabItem {
                    Label("Training", systemImage: "heart.fill")
                }
                .tag(0)
            
            // Chat View
            WatchChatView()
                .tabItem {
                    Label("Coach", systemImage: "message.fill")
                }
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    WatchMainView()
        .environmentObject(WatchChatViewModel(engine: ChatServiceAdapter()))
}