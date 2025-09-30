import SwiftUI
import WatchKit

struct WatchTrainingView: View {
    @State private var isTrainingActive = false
    @State private var trainingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingEnd = false
    
    private let trainingTips = [
        "Keep your wrist relaxed during HRV measurements",
        "Breathe naturally - don't force your breath",
        "Stay still for accurate heart rate readings", 
        "Focus on your current sensations",
        "Let your body guide the intensity",
        "Recovery is as important as the work"
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            if !isTrainingActive {
                startScreen
            } else {
                activeTrainingScreen
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopTraining()
        }
    }
    
    private var startScreen: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
                .symbolEffect(.pulse)
            
            Text("HRV Training")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Tap to start your mindful training session")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start Training") {
                startTraining()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
    }
    
    private var activeTrainingScreen: some View {
        VStack(spacing: 8) {
            // Timer display
            Text(formatDuration(trainingDuration))
                .font(.title2.monospacedDigit())
                .foregroundColor(.green)
            
            // Heart rate indicator
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, isActive: isTrainingActive)
                
                Text("Training Active")
                    .font(.caption)
            }
            
            // Random training tip
            if let tip = trainingTips.randomElement() {
                Text(tip)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            
            // End training button
            Button("End Training") {
                showingEnd = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding()
        .alert("End Training?", isPresented: $showingEnd) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                stopTraining()
            }
        } message: {
            Text("Your training session will be saved.")
        }
    }
    
    private func startTraining() {
        isTrainingActive = true
        trainingDuration = 0
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            trainingDuration += 1
        }
    }
    
    private func stopTraining() {
        isTrainingActive = false
        timer?.invalidate()
        timer = nil
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.stop)
        
        // Could save training session here
        // saveTrainingSession(duration: trainingDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    WatchTrainingView()
}