import SwiftUI

struct RootTabView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ContentView()
            .environmentObject(appState)
    }
}

#Preview {
    RootTabView()
        .environmentObject(CoachEngineManager())
}
