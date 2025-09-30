import SwiftUI
import WatchKit

struct WatchTrainingView: View {
    @StateObject private var trainingManager = WatchTrainingManager.shared
    @State private var selectedTrainingType: TrainingType = .aerobic
    
    var body: some View {
        if trainingManager.isTrainingActive {
            activeTrainingView
        } else {
            trainingSelectionView
        }
    }
    
    private var trainingSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Training")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Training Type Selection
                VStack(spacing: 8) {
                    Text("Select Training Type")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(TrainingType.allCases) { type in
                        Button(action: {
                            selectedTrainingType = type
                            trainingManager.startTraining(type: type)
                        }) {
                            HStack {
                                Image(systemName: type.systemImage)
                                    .foregroundColor(type.color)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Text(type.description)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // HRV Status
                VStack(spacing: 4) {
                    Text("Current HRV")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(Int(trainingManager.currentHRV)) ms")
                        .font(.title3)
                        .foregroundColor(.cyan)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private var activeTrainingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Training Type Header
                if let currentType = trainingManager.currentTrainingType {
                    HStack {
                        Image(systemName: currentType.systemImage)
                            .foregroundColor(currentType.color)
                        Text(currentType.rawValue)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                // Training Duration
                Text(formatDuration(trainingManager.trainingDuration))
                    .font(.largeTitle.monospacedDigit())
                    .foregroundColor(.cyan)
                
                // Current Zone Display
                VStack(spacing: 8) {
                    Text("Training Zone")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Zone \(trainingManager.currentZone.rawValue)")
                        .font(.title2)
                        .foregroundColor(trainingManager.currentZone.color)
                    
                    Text(trainingManager.currentZone.name)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                .background(trainingManager.currentZone.color.opacity(0.2))
                .cornerRadius(12)
                
                // Heart Rate
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Heart Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(trainingManager.currentHeartRate) BPM")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    // HR Zone Range
                    let hrRange = trainingManager.currentZone.hrRange(basedOnHRV: trainingManager.currentHRV)
                    Text("\(hrRange.lowerBound)-\(hrRange.upperBound) BPM")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // Zone Visualization
                zoneVisualization
                
                // End Training Button
                Button("End Training") {
                    trainingManager.endTraining()
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private var zoneVisualization: some View {
        VStack(spacing: 4) {
            Text("Training Zones")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 2) {
                ForEach(TrainingZone.allCases, id: \.rawValue) { zone in
                    Rectangle()
                        .fill(zone == trainingManager.currentZone ? zone.color : zone.color.opacity(0.3))
                        .frame(height: zone == trainingManager.currentZone ? 20 : 15)
                        .cornerRadius(2)
                }
            }
            
            HStack {
                Text("Z1")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("Z5")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
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