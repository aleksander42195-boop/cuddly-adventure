import Foundation
import BackgroundTasks
import UIKit

final class HealthDataSyncService {
    static let shared = HealthDataSyncService()
    
    private let backgroundTaskIdentifier = "com.lifehack.LifehackApp.healthsync"
    private var syncTimer: Timer?
    private weak var appState: AppState?
    
    private init() {}
    
    func configure(with appState: AppState) {
        self.appState = appState
        registerBackgroundTask()
        startPeriodicSync()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    // MARK: - Periodic Sync (30 minutes)
    
    func startPeriodicSync() {
        stopPeriodicSync()
        
        // Schedule sync every 30 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthDataSync()
            }
        }
        
        // Schedule background task for when app goes to background
        scheduleBackgroundSync()
        
        print("[HealthSync] Started periodic sync every 30 minutes")
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("[HealthSync] Stopped periodic sync")
    }
    
    // MARK: - Background Sync
    
    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[HealthSync] Scheduled background sync for 30 minutes from now")
        } catch {
            print("[HealthSync] Failed to schedule background sync: \(error)")
        }
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("[HealthSync] Background sync started")
        
        // Schedule the next background sync
        scheduleBackgroundSync()
        
        let syncTask = Task {
            await performHealthDataSync()
        }
        
        task.expirationHandler = {
            syncTask.cancel()
            print("[HealthSync] Background sync expired")
        }
        
        Task {
            await syncTask.value
            task.setTaskCompleted(success: true)
            print("[HealthSync] Background sync completed")
        }
    }
    
    // MARK: - Health Data Sync
    
    @MainActor
    private func performHealthDataSync() async {
        guard let appState = appState else { 
            print("[HealthSync] AppState not available")
            return 
        }
        
        print("[HealthSync] Starting health data sync...")
        
        // Perform the actual health data refresh
        await appState.refreshFromHealthIfAvailable()
        
        // Save updated state
        appState.saveState()
        
        // Log sync completion with timestamp
        let timestamp = DateFormatter.localizedString(from: Date(), 
                                                    dateStyle: .none, 
                                                    timeStyle: .medium)
        print("[HealthSync] Health data sync completed at \(timestamp)")
        
        // Store last sync timestamp
        UserDefaults.standard.set(Date(), forKey: "lastHealthSync")
        
        // Optionally trigger a success haptic if app is active
        if UIApplication.shared.applicationState == .active {
            appState.successHaptic()
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func triggerManualSync() async {
        print("[HealthSync] Manual sync triggered")
        await performHealthDataSync()
    }
    
    // MARK: - Sync Status
    
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: "lastHealthSync") as? Date
    }
    
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastSyncDate else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
}

// MARK: - App Lifecycle Integration

extension HealthDataSyncService {
    func handleAppWillEnterForeground() {
        // Check if we need to sync when app comes back to foreground
        if let timeSince = timeSinceLastSync, timeSince > 30 * 60 {
            Task {
                await performHealthDataSync()
            }
        }
    }
    
    func handleAppDidEnterBackground() {
        // Schedule background sync when app goes to background
        scheduleBackgroundSync()
    }
}