import SwiftUI

struct WatchTrainingSettingsView: View {
    @StateObject private var trainingManager = WatchTrainingManager.shared
    @State private var showingHRVInput = false
    @State private var newHRVValue: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // HRV Configuration
                VStack(spacing: 8) {
                    Text("HRV Configuration")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        newHRVValue = String(Int(trainingManager.currentHRV))
                        showingHRVInput = true
                    }) {
                        VStack(spacing: 4) {
                            Text("Current HRV")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("\(Int(trainingManager.currentHRV)) ms")
                                .font(.title3)
                                .foregroundColor(.cyan)
                            Text("Tap to update")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Training Zone Info
                VStack(spacing: 8) {
                    Text("Training Zones")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(TrainingZone.allCases, id: \.rawValue) { zone in
                        let hrRange = zone.hrRange(basedOnHRV: trainingManager.currentHRV)
                        
                        HStack {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zone \(zone.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(zone.name)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("\(hrRange.lowerBound)-\(hrRange.upperBound)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                // Haptic Settings
                VStack(spacing: 8) {
                    Text("Haptic Feedback")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 4) {
                        Text("Zone changes trigger haptic feedback")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Text("Zone 5 has extra haptic intensity")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingHRVInput) {
            HRVInputView(currentValue: trainingManager.currentHRV) { newValue in
                trainingManager.currentHRV = newValue
            }
        }
    }
}

struct HRVInputView: View {
    let currentValue: Double
    let onUpdate: (Double) -> Void
    @State private var inputValue: String
    @Environment(\.dismiss) private var dismiss
    
    init(currentValue: Double, onUpdate: @escaping (Double) -> Void) {
        self.currentValue = currentValue
        self.onUpdate = onUpdate
        self._inputValue = State(initialValue: String(Int(currentValue)))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Update HRV")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Enter your latest HRV measurement")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            TextField("HRV (ms)", text: $inputValue)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
                
                Button("Update") {
                    if let newValue = Double(inputValue), newValue > 0 {
                        onUpdate(newValue)
                    }
                    dismiss()
                }
                .foregroundColor(.cyan)
            }
        }
        .padding()
        .background(Color.black)
    }
}

#Preview {
    WatchTrainingSettingsView()
}