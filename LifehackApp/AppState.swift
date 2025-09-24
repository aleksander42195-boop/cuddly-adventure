import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case today, journal, trends }

    @Published var selectedTab: Tab = .today
    @Published var isOnboardingPresented: Bool = false
    @Published var hapticsEnabled: Bool = true

    // Today snapshot used by TodayView
    @Published var today: TodaySnapshot = .empty

    let haptics = HapticsManager()
    let healthService = HealthKitService()

    init() { Task { await refreshFromHealthIfAvailable() } }

    @MainActor
    func refreshFromHealthIfAvailable() async {
        let snap = await healthService.safeTodaySnapshot()
        today = snap
    }

    var isHealthAuthorized: Bool { healthService.isAuthorized }
    func requestHealthAuthorization() async {
        _ = try? await healthService.requestAuthorization()
        await refreshFromHealthIfAvailable()
    }

    func tapHaptic() {
        guard hapticsEnabled else { return }
        HapticsManager.shared.tap()
    }
}
