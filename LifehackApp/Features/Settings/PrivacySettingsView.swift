import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var shareDataForResearch = false
    @State private var allowAnalytics = false
    @State private var exportingHealthData = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Data Privacy")
                            .font(.headline)
                        
                        Text("Your health data is private and secure. All sensitive information is encrypted and stored locally on your device.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("HealthKit Data")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Health Access")
                                        .font(.subheadline)
                                    Text("Allow access to HealthKit data")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                if app.isHealthAuthorized {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Grant Access") {
                                        Task {
                                            await app.requestHealthAuthorization()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            
                            if app.isHealthAuthorized {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Data Types Accessed:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Label("Heart Rate Variability", systemImage: "heart")
                                        .font(.caption)
                                    Label("Resting Heart Rate", systemImage: "heart.pulse")
                                        .font(.caption)
                                    Label("Steps Count", systemImage: "figure.walk")
                                        .font(.caption)
                                    Label("Sleep Analysis", systemImage: "moon.zzz")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Research & Analytics")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $shareDataForResearch) {
                                VStack(alignment: .leading) {
                                    Text("Contribute to Research")
                                        .font(.subheadline)
                                    Text("Share anonymous data to help improve health research")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Toggle(isOn: $allowAnalytics) {
                                VStack(alignment: .leading) {
                                    Text("Usage Analytics")
                                        .font(.subheadline)
                                    Text("Help improve app performance and features")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Data Export")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export your health data for personal use or to share with healthcare providers.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            
                            Button("Export Health Data") {
                                exportingHealthData = true
                            }
                            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            .disabled(exportingHealthData)
                            
                            if exportingHealthData {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Preparing export...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Data Deletion")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Delete all locally stored app data. This will not affect your HealthKit data.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            
                            Button("Delete All App Data") {
                                // TODO: Implement data deletion
                                app.tapHaptic()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Privacy & Data")
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            loadPrivacySettings()
        }
        .onDisappear {
            savePrivacySettings()
        }
        .fileExporter(
            isPresented: $exportingHealthData,
            document: HealthDataDocument(),
            contentType: .json,
            defaultFilename: "health_data_export"
        ) { result in
            exportingHealthData = false
            switch result {
            case .success(let url):
                print("Health data exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
    
    private func loadPrivacySettings() {
        shareDataForResearch = UserDefaults.standard.bool(forKey: "share_data_for_research")
        allowAnalytics = UserDefaults.standard.bool(forKey: "allow_analytics")
    }
    
    private func savePrivacySettings() {
        UserDefaults.standard.set(shareDataForResearch, forKey: "share_data_for_research")
        UserDefaults.standard.set(allowAnalytics, forKey: "allow_analytics")
    }
}

// Simple document for health data export
private struct HealthDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init() {
        // Create a simple JSON export of current health data
        let exportData = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "app_version": "1.0.0",
            "note": "This is a sample export. Actual implementation would include real health data."
        ]
        
        self.data = (try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)) ?? Data()
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
            .environmentObject(AppState())
    }
}