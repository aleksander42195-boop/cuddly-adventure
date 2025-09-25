import SwiftUI
import HealthKit

struct PrivacySettingsView: View {
    @EnvironmentObject var app: AppState
    
    @State private var healthKitEnabled = false
    @State private var notificationsEnabled = false
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = false
    @State private var locationEnabled = false
    @State private var dataExportEnabled = false
    
    @State private var showingDeleteAlert = false
    @State private var showingDataExport = false
    @State private var showingHealthKitPermissions = false
    
    var body: some View {
        NavigationView {
            List {
                dataCollectionSection
                permissionsSection
                dataManagementSection
                privacyPolicySection
            }
            .navigationTitle("Privacy & Data")
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear {
                loadPrivacySettings()
            }
            .alert("Delete All Data", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllUserData()
                }
            } message: {
                Text("This will permanently delete all your health data, metrics, and preferences. This action cannot be undone.")
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .sheet(isPresented: $showingHealthKitPermissions) {
                HealthKitPermissionsView()
            }
        }
    }
    
    private var dataCollectionSection: some View {
        Section {
            Toggle("HealthKit Integration", isOn: $healthKitEnabled)
                .onChange(of: healthKitEnabled) { _, newValue in
                    handleHealthKitToggle(newValue)
                }
            
            Toggle("Push Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    handleNotificationsToggle(newValue)
                }
            
            Toggle("Anonymous Analytics", isOn: $analyticsEnabled)
                .onChange(of: analyticsEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "analytics_enabled")
                }
            
            Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                .onChange(of: crashReportingEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "crash_reporting_enabled")
                }
            
            Toggle("Location Services", isOn: $locationEnabled)
                .onChange(of: locationEnabled) { _, newValue in
                    handleLocationToggle(newValue)
                }
        } header: {
            Text("Data Collection")
        } footer: {
            Text("We only collect data necessary to provide personalized health insights. All data is stored securely on your device.")
        }
    }
    
    private var permissionsSection: some View {
        Section {
            Button("Manage HealthKit Permissions") {
                showingHealthKitPermissions = true
            }
            .foregroundStyle(.blue)
            
            Button("Notification Settings") {
                openNotificationSettings()
            }
            .foregroundStyle(.blue)
            
            Button("Privacy Settings") {
                openPrivacySettings()
            }
            .foregroundStyle(.blue)
        } header: {
            Text("Permissions")
        } footer: {
            Text("Manage app permissions in iOS Settings or review specific HealthKit data types.")
        }
    }
    
    private var dataManagementSection: some View {
        Section {
            Button("Export My Data") {
                showingDataExport = true
            }
            .foregroundStyle(.blue)
            
            Button("View Data Usage") {
                // Navigate to data usage view
            }
            .foregroundStyle(.blue)
            
            Button("Clear Cache") {
                clearCache()
            }
            .foregroundStyle(.orange)
            
            Button("Delete All Data") {
                showingDeleteAlert = true
            }
            .foregroundStyle(.red)
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export your data for backup or delete everything to start fresh.")
        }
    }
    
    private var privacyPolicySection: some View {
        Section("Legal") {
            Link("Privacy Policy", destination: URL(string: "https://your-privacy-policy-url.com")!)
                .foregroundStyle(.blue)
            
            Link("Terms of Service", destination: URL(string: "https://your-terms-url.com")!)
                .foregroundStyle(.blue)
            
            Link("Data Processing Agreement", destination: URL(string: "https://your-dpa-url.com")!)
                .foregroundStyle(.blue)
            
            HStack {
                Text("App Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    // MARK: - Functions
    
    private func loadPrivacySettings() {
        healthKitEnabled = app.isHealthAuthorized
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        analyticsEnabled = UserDefaults.standard.bool(forKey: "analytics_enabled")
        crashReportingEnabled = UserDefaults.standard.bool(forKey: "crash_reporting_enabled")
        locationEnabled = UserDefaults.standard.bool(forKey: "location_enabled")
        dataExportEnabled = UserDefaults.standard.bool(forKey: "data_export_enabled")
    }
    
    private func handleHealthKitToggle(_ enabled: Bool) {
        if enabled {
            Task {
                await app.requestHealthAuthorization()
                healthKitEnabled = app.isHealthAuthorized
            }
        } else {
            // Can't programmatically disable HealthKit, redirect to Settings
            openHealthKitSettings()
            healthKitEnabled = app.isHealthAuthorized
        }
    }
    
    private func handleNotificationsToggle(_ enabled: Bool) {
        if enabled {
            Task {
                await app.requestNotificationPermission()
                // Update toggle based on actual permission
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()
                notificationsEnabled = settings.authorizationStatus == .authorized
                UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled")
            }
        } else {
            UserDefaults.standard.set(false, forKey: "notifications_enabled")
            openNotificationSettings()
        }
    }
    
    private func handleLocationToggle(_ enabled: Bool) {
        if enabled {
            // Request location permission through app delegate or location manager
            // For now, just redirect to settings
            openLocationSettings()
        } else {
            UserDefaults.standard.set(false, forKey: "location_enabled")
            openLocationSettings()
        }
    }
    
    private func clearCache() {
        // Clear any cached data
        let cacheKeys = [
            "cached_health_data",
            "cached_analytics",
            "temp_measurements",
            "processed_hrv_data"
        ]
        
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        app.successHaptic()
    }
    
    private func deleteAllUserData() {
        // Clear all user data
        let userDataKeys = [
            "user_full_name",
            "user_birth_date",
            "user_gender",
            "user_height",
            "user_weight",
            "user_systolic_bp",
            "user_diastolic_bp",
            "user_resting_hr",
            "user_blood_type",
            "user_activity_level",
            "user_sleep_hours",
            "user_fitness_goals",
            "user_allergies",
            "user_medications",
            "user_medical_conditions",
            "onboarding_completed",
            "notifications_enabled",
            "analytics_enabled",
            "crash_reporting_enabled",
            "location_enabled"
        ]
        
        for key in userDataKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        app.successHaptic()
    }
    
    private func openHealthKitSettings() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacySettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportProgress: Double = 0.0
    @State private var isExporting = false
    @State private var exportComplete = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !exportComplete {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("Export Your Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your health data will be exported as a JSON file that you can save or share.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    if isExporting {
                        ProgressView(value: exportProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(Int(exportProgress * 100))% Complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(isExporting ? "Exporting..." : "Start Export") {
                        startExport()
                    }
                    .disabled(isExporting)
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    
                    Text("Export Complete")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your data has been successfully exported.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Data Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.05
            
            if exportProgress >= 1.0 {
                timer.invalidate()
                isExporting = false
                exportComplete = true
                
                // TODO: Implement actual data export
                exportUserData()
            }
        }
    }
    
    private func exportUserData() {
        // Create export data structure
        let exportData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown",
            "user_profile": getUserProfileData(),
            "health_metrics": getHealthMetricsData(),
            "preferences": getPreferencesData()
        ]
        
        // Convert to JSON and share
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            shareExportData(jsonData)
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func getUserProfileData() -> [String: Any] {
        return [
            "full_name": UserDefaults.standard.string(forKey: "user_full_name") ?? "",
            "gender": UserDefaults.standard.string(forKey: "user_gender") ?? "",
            "height": UserDefaults.standard.double(forKey: "user_height"),
            "weight": UserDefaults.standard.double(forKey: "user_weight"),
            "activity_level": UserDefaults.standard.string(forKey: "user_activity_level") ?? "",
            "sleep_hours": UserDefaults.standard.double(forKey: "user_sleep_hours")
        ]
    }
    
    private func getHealthMetricsData() -> [String: Any] {
        return [
            "systolic_bp": UserDefaults.standard.string(forKey: "user_systolic_bp") ?? "",
            "diastolic_bp": UserDefaults.standard.string(forKey: "user_diastolic_bp") ?? "",
            "resting_hr": UserDefaults.standard.string(forKey: "user_resting_hr") ?? "",
            "blood_type": UserDefaults.standard.string(forKey: "user_blood_type") ?? "",
            "allergies": UserDefaults.standard.string(forKey: "user_allergies") ?? "",
            "medications": UserDefaults.standard.string(forKey: "user_medications") ?? "",
            "medical_conditions": UserDefaults.standard.string(forKey: "user_medical_conditions") ?? ""
        ]
    }
    
    private func getPreferencesData() -> [String: Any] {
        return [
            "notifications_enabled": UserDefaults.standard.bool(forKey: "notifications_enabled"),
            "analytics_enabled": UserDefaults.standard.bool(forKey: "analytics_enabled"),
            "crash_reporting_enabled": UserDefaults.standard.bool(forKey: "crash_reporting_enabled"),
            "onboarding_completed": UserDefaults.standard.bool(forKey: "onboarding_completed")
        ]
    }
    
    private func shareExportData(_ data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("health_data_export.json")
        
        do {
            try data.write(to: tempURL)
            
            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true)
                }
            }
        } catch {
            print("Failed to write export file: \(error)")
        }
    }
}

struct HealthKitPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    
    private let healthKitDataTypes = [
        ("Heart Rate", "heart.fill"),
        ("Blood Pressure", "heart.circle"),
        ("Step Count", "figure.walk"),
        ("Weight", "scalemass"),
        ("Height", "ruler"),
        ("Sleep Analysis", "bed.double"),
        ("Active Energy", "flame"),
        ("Exercise Time", "stopwatch")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HealthKit Integration")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This app can read and write health data to provide personalized insights. You can control which data types are shared.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Available Data Types") {
                    ForEach(healthKitDataTypes, id: \.0) { dataType in
                        HStack {
                            Image(systemName: dataType.1)
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            Text(dataType.0)
                            
                            Spacer()
                            
                            // Show status based on app's health authorization
                            Image(systemName: app.isHealthAuthorized ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(app.isHealthAuthorized ? .green : .gray)
                        }
                    }
                }
                
                Section {
                    Button("Request HealthKit Access") {
                        Task {
                            await app.requestHealthAuthorization()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    
                    Button("Open Health App") {
                        openHealthApp()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                }
            }
            .navigationTitle("HealthKit Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
            .environmentObject(AppState())
    }
}