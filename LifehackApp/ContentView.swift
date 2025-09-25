import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem {
                    ZStack(alignment: .topTrailing) {
                        Label("Today", systemImage: "sun.max")
                        if !appState.isHealthAuthorized {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -6)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .tag(AppState.Tab.today)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(AppState.Tab.journal)
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppState.Tab.trends)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(CoachEngineManager())
}
