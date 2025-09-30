import SwiftUI

struct TrainingModeView: View {
    @StateObject private var trainingManager = TrainingModeManager.shared
    @EnvironmentObject private var app: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            if trainingManager.isTrainingActive {
                activeTrainingCard
            } else {
                trainingReadinessCard
            }
            
            trainingStudiesSection
        }
    }
    
    private var activeTrainingCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse)
                    
                    Text("Training Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text(formatDuration(trainingManager.currentTrainingDuration))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.green)
                }
                
                Text("Stay focused on your breathing and form. Your HRV is being monitored for optimal training intensity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("End Training") {
                    trainingManager.endTraining()
                    app.triggerManualSync() // Refresh metrics after training
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                .tint(.orange)
            }
        }
    }
    
    private var trainingReadinessCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                    
                    Text("Training Readiness")
                        .font(.headline)
                    
                    Spacer()
                    
                    readinessIndicator
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HRV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(app.today.hrvSDNNms, specifier: "%.0f")ms")
                            .font(.subheadline.bold())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resting HR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(app.today.restingHR, specifier: "%.0f") bpm")
                            .font(.subheadline.bold())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recovery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(100 - app.today.stressPercent)%")
                            .font(.subheadline.bold())
                            .foregroundColor(recoveryColor)
                    }
                    
                    Spacer()
                }
                
                Button("Start Training") {
                    trainingManager.startTraining()
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                .tint(.green)
            }
        }
    }
    
    private var readinessIndicator: some View {
        let readiness = calculateReadiness()
        return Circle()
            .fill(readinessColor(readiness))
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 2)
            )
    }
    
    private var trainingStudiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Insights")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trainingStudies, id: \.id) { study in
                        TrainingStudyCard(study: study)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var trainingStudies: [Study] {
        // Filter studies for training category
        return HRVStudies.all.filter { $0.category == .training }.prefix(3).map { $0 }
    }
    
    private var recoveryColor: Color {
        let recovery = 100 - app.today.stressPercent
        if recovery >= 80 { return .green }
        if recovery >= 60 { return .orange }
        return .red
    }
    
    private func calculateReadiness() -> Double {
        // Simple readiness calculation based on HRV, RHR, and stress
        let hrvScore = min(app.today.hrvSDNNms / 50.0, 1.0) // Normalize around 50ms
        let rhrScore = max(0, 1.0 - (app.today.restingHR - 60) / 30.0) // Normalize around 60 bpm
        let stressScore = (100 - Double(app.today.stressPercent)) / 100.0
        
        return (hrvScore + rhrScore + stressScore) / 3.0
    }
    
    private func readinessColor(_ readiness: Double) -> Color {
        if readiness >= 0.8 { return .green }
        if readiness >= 0.6 { return .orange }
        return .red
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TrainingStudyCard: View {
    let study: Study
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(study.title)
                .font(.caption.bold())
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Text(study.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            if let insight = study.takeaways.first {
                Text("💡 \(insight)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 200)
    }
}

#Preview {
    TrainingModeView()
        .environmentObject(AppState())
}