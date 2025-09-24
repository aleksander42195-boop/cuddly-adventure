import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case today, journal, trends }

    @Published var selectedTab: Tab = .today
    @Published var isOnboardingPresented: Bool = false
    @Published var hapticsEnabled: Bool = true
    @AppStorage("user_birthdate") var birthdate: Date = ISO8601DateFormatter().date(from: "1990-01-01T00:00:00Z") ?? Date()
    @Published var lastNightSleepHours: Double = 0
    @Published var todayMETHours: Double = 0

    // Today snapshot used by TodayView
    @Published var today: TodaySnapshot = .empty

    let haptics = HapticsManager()
    let healthService = HealthKitService()

    init() { Task { await refreshFromHealthIfAvailable() } }

    @MainActor
    func refreshFromHealthIfAvailable() async {
        let snap = await healthService.safeTodaySnapshot()
        today = snap
        NotificationsManager.shared.scheduleStudySuggestions(basedOn: snap)
        let sleep = (try? await healthService.lastNightSleepHours()) ?? 0
        lastNightSleepHours = sleep
        let mets = (try? await healthService.todayMETHours()) ?? 0
        todayMETHours = mets
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
