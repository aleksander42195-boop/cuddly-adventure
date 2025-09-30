import Foundation
import Combine
import WatchKit
import SwiftUI
import HealthKit

enum TrainingType: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case aerobic = "Aerobic"
    case threshold = "Threshold"
    case vo2max = "VO2 Max"
    case neuromuscular = "Neuromuscular"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .recovery: return "leaf.fill"
        case .aerobic: return "heart.fill"
        case .threshold: return "bolt.fill"
        case .vo2max: return "flame.fill"
        case .neuromuscular: return "lightning.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .recovery: return .green
        case .aerobic: return .blue
        case .threshold: return .orange
        case .vo2max: return .red
        case .neuromuscular: return .purple
        }
    }
    
    var description: String {
        switch self {
        case .recovery: return "Easy pace, active recovery"
        case .aerobic: return "Comfortable sustainable pace"
        case .threshold: return "Comfortably hard pace"
        case .vo2max: return "Hard, short intervals"
        case .neuromuscular: return "All-out sprints"
        }
    }
}

enum TrainingZone: Int, CaseIterable {
    case zone1 = 1, zone2, zone3, zone4, zone5
    
    var name: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Aerobic"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "VO2 Max"
        }
    }
    
    var color: Color {
        switch self {
        case .zone1: return .green
        case .zone2: return .blue
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
    
    func hrRange(basedOnHRV hrvValue: Double) -> ClosedRange<Int> {
        // Adapt zones based on HRV - higher HRV allows for higher training intensity
        let baseMax = 180 // Rough estimate, should be personalized
        let hrvFactor = min(max(hrvValue / 50.0, 0.8), 1.2) // Scale based on HRV
        let maxHR = Int(Double(baseMax) * hrvFactor)
        
        switch self {
        case .zone1: return Int(Double(maxHR) * 0.5)...Int(Double(maxHR) * 0.6)
        case .zone2: return Int(Double(maxHR) * 0.6)...Int(Double(maxHR) * 0.7)
        case .zone3: return Int(Double(maxHR) * 0.7)...Int(Double(maxHR) * 0.8)
        case .zone4: return Int(Double(maxHR) * 0.8)...Int(Double(maxHR) * 0.9)
        case .zone5: return Int(Double(maxHR) * 0.9)...maxHR
        }
    }
}

class WatchTrainingManager: ObservableObject {
    @Published var isTrainingActive = false
    @Published var currentTrainingType: TrainingType?
    @Published var currentZone: TrainingZone = .zone1
    @Published var currentHeartRate: Int = 0
    @Published var trainingDuration: TimeInterval = 0
    @Published var currentHRV: Double = 50.0 { // Default HRV value
        didSet {
            AppGroup.defaults.set(currentHRV, forKey: SharedKeys.hrvLastKnownMs)
        }
    }
    @Published var isLiveHRActive: Bool = false
    
    private var timer: Timer?
    private var trainingStartTime: Date?
    private var hapticManager = HapticsManager()
    private var lastZone: TrainingZone = .zone1
    private let hkManager = HealthKitWorkoutManager()
    private var useHealthKit: Bool {
        Secrets.shared.healthKitEnabledFlag && HKHealthStore.isHealthDataAvailable()
    }
    
    static let shared = WatchTrainingManager()
    
    private init() {
        // Load persisted HRV if available
        let saved = AppGroup.defaults.double(forKey: SharedKeys.hrvLastKnownMs)
        if saved > 0 {
            currentHRV = saved
        }
    }
    
    func startTraining(type: TrainingType) {
        guard !isTrainingActive else { return }
        
        isTrainingActive = true
        currentTrainingType = type
        trainingStartTime = Date()
        trainingDuration = 0
        
        // Start monitoring
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrainingMetrics()
        }

        if useHealthKit {
            hkManager.requestAuthorization { [weak self] ok in
                guard let self = self else { return }
                if ok {
                    self.hkManager.onHeartRate = { [weak self] hr in
                        guard let self = self else { return }
                        self.currentHeartRate = hr
                        self.updateTrainingZone()
                        if !self.isLiveHRActive { self.isLiveHRActive = true }
                    }
                    // Fetch latest HRV automatically
                    self.hkManager.fetchLatestHRV { [weak self] ms in
                        if let ms { self?.currentHRV = ms }
                    }
                    self.hkManager.startWorkout(activity: self.activityType(for: type))
                } else {
                    print("[WatchTraining] HealthKit authorization denied; falling back to simulation")
                }
            }
        }
        
        // Initial haptic feedback
        hapticManager.playStart()
        
        print("[WatchTraining] Started \(type.rawValue) training")
    }
    
    func endTraining() {
        guard isTrainingActive else { return }
        
        isTrainingActive = false
        timer?.invalidate()
        timer = nil
        
        let duration = trainingDuration
        let type = currentTrainingType?.rawValue ?? "Unknown"
        
        currentTrainingType = nil
        trainingStartTime = nil
        trainingDuration = 0
        currentZone = .zone1
        lastZone = .zone1
        
        // End haptic feedback
        hapticManager.playStop()

        if useHealthKit {
            hkManager.endWorkout()
        }
        isLiveHRActive = false
        
        print("[WatchTraining] Ended \(type) training. Duration: \(formatDuration(duration))")
    }
    
    private func updateTrainingMetrics() {
        guard let startTime = trainingStartTime else { return }
        
        trainingDuration = Date().timeIntervalSince(startTime)
        
        // Update HR: HealthKit stream updates currentHeartRate as it arrives.
        // If HK isn't in use or hasn't provided data yet, simulate as fallback.
        if !useHealthKit {
            simulateHeartRateUpdate()
        }
        
        // Update training zone based on current HR and HRV
        updateTrainingZone()
    }
    
    private func simulateHeartRateUpdate() {
        // In real implementation, this would come from HealthKit
        // For now, simulate varying heart rate
        let baseHR = 70
        let variability = Int.random(in: -10...30)
        currentHeartRate = baseHR + variability
    }

    private func activityType(for type: TrainingType) -> HKWorkoutActivityType {
        switch type {
        case .recovery: return .mindAndBody
        case .aerobic: return .other
        case .threshold: return .highIntensityIntervalTraining
        case .vo2max: return .running
        case .neuromuscular: return .functionalStrengthTraining
        }
    }
    
    private func updateTrainingZone() {
        // Determine current zone based on heart rate and HRV-adapted ranges
        for zone in TrainingZone.allCases.reversed() {
            let hrRange = zone.hrRange(basedOnHRV: currentHRV)
            if hrRange.contains(currentHeartRate) {
                if currentZone != zone {
                    // Zone changed - trigger haptic feedback
                    zoneChanged(from: currentZone, to: zone)
                    currentZone = zone
                }
                break
            }
        }
    }
    
    private func zoneChanged(from oldZone: TrainingZone, to newZone: TrainingZone) {
        print("[WatchTraining] Zone changed: \(oldZone.name) -> \(newZone.name)")
        
        // Haptic feedback for zone changes
        if newZone.rawValue > oldZone.rawValue {
            // Entering higher zone
            hapticManager.playZoneUp()
            if newZone == .zone5 {
                // Extra haptic for zone 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.hapticManager.playZone5()
                }
            }
        } else {
            // Entering lower zone
            hapticManager.playZoneDown()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Haptic feedback manager for training
class HapticsManager {
    func playStart() {
        WKInterfaceDevice.current().play(.start)
    }
    
    func playStop() {
        WKInterfaceDevice.current().play(.stop)
    }
    
    func playZoneUp() {
        WKInterfaceDevice.current().play(.notification)
    }
    
    func playZoneDown() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    func playZone5() {
        // Extra haptic for zone 5
        WKInterfaceDevice.current().play(.failure)
    }
}