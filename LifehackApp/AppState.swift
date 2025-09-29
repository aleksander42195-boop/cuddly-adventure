import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case today, journal, trends, profile }

    @Published var selectedTab: Tab = .today
    // Cross-tab intent routing (e.g., Today -> Profile -> Settings)
    @Published var pendingOpenSettings: Bool = false
    @Published var isOnboardingPresented: Bool = false
    @Published var hapticsEnabled: Bool = true
    // iOS 17-compatible persistence: store birthdate as timestamp and expose a @Published Date for bindings
    @AppStorage("user_birthdate_ts") private var birthdateTimestamp: Double = ISO8601DateFormatter().date(from: "1990-01-01T00:00:00Z")?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @Published var birthdate: Date = Date() {
        didSet { birthdateTimestamp = birthdate.timeIntervalSince1970 }
    }
    @Published var lastNightSleepHours: Double = 0
    @Published var todayMETHours: Double = 0

    // Today snapshot used by TodayView
    @Published var today: TodaySnapshot = .empty

    let haptics = HapticsManager.shared
    let healthService = HealthKitService()
    // Manual sync state (UI bindings)
    @Published var isSyncing: Bool = false
    
    // Last sync info (stored in UserDefaults by key "lastHealthSync")
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: "lastHealthSync") as? Date
    }
    
    var lastSyncStatusText: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    init() {
        // Initialize published birthdate from persisted timestamp
        birthdate = Date(timeIntervalSince1970: birthdateTimestamp)
        
        // Restore app state
        restorePersistedState()
        
        // Setup background refresh
        setupBackgroundRefresh()
        
        Task { await refreshFromHealthIfAvailable() }
    }
    
    private func restorePersistedState() {
        // Restore any critical app state that needs to persist across launches
        if let savedTab = UserDefaults.standard.object(forKey: "selectedTab") as? String {
            switch savedTab {
            case "journal": selectedTab = .journal
            case "trends": selectedTab = .trends
            case "profile": selectedTab = .profile
            default: selectedTab = .today
            }
        }
    }
    
    private func setupBackgroundRefresh() {
        // Setup periodic state saving
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveState()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveState()
            }
        }
    }
    
    func saveState() {
        // Save current state
        let tabString: String
        switch selectedTab {
        case .today: tabString = "today"
        case .journal: tabString = "journal"
        case .trends: tabString = "trends"
        case .profile: tabString = "profile"
        }
        UserDefaults.standard.set(tabString, forKey: "selectedTab")
        UserDefaults.standard.synchronize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    func refreshFromHealthIfAvailable() async {
        if DeveloperFlags.verboseLogging {
            print("[AppState] refreshFromHealthIfAvailable() called, current today: \(today)")
        }
        let snap = await healthService.safeTodaySnapshot()
        today = snap
        NotificationsManager.shared.scheduleStudySuggestions(basedOn: snap)
        let sleep = (try? await healthService.lastNightSleepHours()) ?? 0
        lastNightSleepHours = sleep
        let mets = (try? await healthService.todayMETHours()) ?? 0
        todayMETHours = mets
        if DeveloperFlags.verboseLogging {
            print("[AppState] refreshFromHealthIfAvailable() completed, new today: \(today), sleep: \(sleep)h, mets: \(mets)")
        }
    }

    var isHealthAuthorized: Bool { 
        let authorized = healthService.isAuthorized
        if DeveloperFlags.verboseLogging {
            print("[AppState] isHealthAuthorized -> \(authorized)")
        }
        return authorized
    }
    func requestHealthAuthorization() async {
        if DeveloperFlags.verboseLogging {
            print("[AppState] requestHealthAuthorization() called")
        }
        _ = try? await healthService.requestAuthorization()
        await refreshFromHealthIfAvailable()
    }

    func tapHaptic() {
        guard hapticsEnabled else { return }
        HapticsManager.shared.tap()
    }
    
    func successHaptic() {
        guard hapticsEnabled else { return }
        HapticsManager.shared.success()
    }
    
    // MARK: - Manual Sync Trigger (UI)
    func triggerManualSync() {
        guard !isSyncing else { return }
        Task { await performManualSync() }
    }
    
    @MainActor
    private func performManualSync() async {
        isSyncing = true
        defer { isSyncing = false }
        await refreshFromHealthIfAvailable()
        UserDefaults.standard.set(Date(), forKey: "lastHealthSync")
        UserDefaults.standard.synchronize()
        successHaptic()
    }
    
    func requestNotificationPermission() async {
        NotificationsManager.shared.requestAuthorizationIfNeeded()
    }
}
