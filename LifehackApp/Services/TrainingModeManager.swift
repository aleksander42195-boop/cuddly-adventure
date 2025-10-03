import Foundation
import Combine

/// Detects and manages training mode state across the app
class TrainingModeManager: ObservableObject {
    @Published var isTrainingActive = false
    @Published var trainingStartTime: Date?
    @Published var currentTrainingDuration: TimeInterval = 0
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    static let shared = TrainingModeManager()
    
    private init() {
        // Auto-detect training based on user activity patterns
        // This could be enhanced with HealthKit workout sessions
        startTrainingDetection()
    }
    
    func startTraining() {
        guard !isTrainingActive else { return }
        
        isTrainingActive = true
        trainingStartTime = Date()
        currentTrainingDuration = 0
        
        // Start tracking duration
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        
        print("[TrainingMode] Training session started")
    }
    
    func endTraining() {
        isTrainingActive = false
        timer?.invalidate()
        timer = nil
        
        let duration = currentTrainingDuration
        trainingStartTime = nil
        currentTrainingDuration = 0
        
        print("[TrainingMode] Training session ended. Duration: \(formatDuration(duration))")
    }
    
    private func updateDuration() {
        guard let startTime = trainingStartTime else { return }
        currentTrainingDuration = Date().timeIntervalSince(startTime)
    }
    
    private func startTrainingDetection() {
        // Could integrate with HealthKit workout detection
        // For now, we'll rely on manual start/stop
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}