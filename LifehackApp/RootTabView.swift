import SwiftUI

struct RootTabView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack {
            // Ensure we have a background
            AppTheme.background
                .ignoresSafeArea()
            
            ContentView()
                .environmentObject(appState)
        }
        .appThemeTokens(AppTheme.tokens())
    }
}

#Preview {
    RootTabView()
        .environmentObject(CoachEngineManager())
}
