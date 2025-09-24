import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCamera: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max") }
                    .tag(AppState.Tab.today)
                JournalView()
                    .tabItem { Label("Journal", systemImage: "book.closed") }
                    .tag(AppState.Tab.journal)
                TrendsView()
                    .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(AppState.Tab.trends)
            }

            Button {
                showCamera = true
            } label: {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(18)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
            .accessibilityLabel("Open Camera for HRV measurement")
            .sheet(isPresented: $showCamera) { HRVCameraView() }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(CoachEngineManager())
}
