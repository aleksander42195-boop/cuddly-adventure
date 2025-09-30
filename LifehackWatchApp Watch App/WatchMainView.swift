import SwiftUI

struct WatchMainView: View {
    var body: some View {
        TabView {
            // Training View
            WatchTrainingView()
                .tabItem {
                    Label("Training", systemImage: "heart.fill")
                }
                .tag(0)
            
            // Settings View
            WatchTrainingSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    WatchMainView()
}