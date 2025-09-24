import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case today, journal, nutrition, coach, settings }

    @Published var selectedTab: Tab = .today
    @Published var isOnboardingPresented: Bool = false
    @Published var hapticsEnabled: Bool = true

    // Shared data
    @Published var dailyMetrics: [Metric] = []
    @Published var chatHistory: [ChatMessage] = []

    let haptics = HapticsManager()
    let healthService: HealthDataProviding = HealthKitService()

    init() { Task { await loadInitialData() } }

    func loadInitialData() async {
        do {
            dailyMetrics = try await healthService.fetchTodayMetrics()
        } catch {
            print("[AppState] Failed to load metrics: \(error)")
        }
    }

    func tapHaptic() {
        guard hapticsEnabled else { return }
        HapticsManager.shared.tap()
    }
}
