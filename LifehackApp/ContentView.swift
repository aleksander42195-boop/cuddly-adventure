import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppState.Tab.today)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(AppState.Tab.journal)
            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "leaf") }
                .tag(AppState.Tab.nutrition)
            CoachingView()
                .tabItem { Label("Coach", systemImage: "brain.head.profile") }
                .tag(AppState.Tab.coach)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppState.Tab.settings)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(CoachEngineManager())
}
