import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engineManager: CoachEngineManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var selectedIconKey: String? = AppIconManager.currentKey()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                // Health Settings Section
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Health").font(.headline)
                        NavigationLink("Health & Profile Settings") { 
                            HealthSettingsView()
                        }
                        NavigationLink("Privacy Settings") { 
                            PrivacySettingsView() 
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Coach").font(.headline)
                        NavigationLink("Coach Engine") { CoachEngineSettingsView() }
                        NavigationLink("HRV Studies") { StudiesView() }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Appearance").font(.headline)
                        Picker("App Icon", selection: Binding(
                            get: { selectedIconKey ?? "__primary__" },
                            set: { newVal in
                                let key: String? = (newVal == "__primary__") ? nil : newVal
                                selectedIconKey = key
                                AppIconManager.set(key: key)
                            }
                        )) {
                            ForEach(AppIconManager.options) { opt in
                                Text(opt.title).tag(opt.key ?? "__primary__")
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Preferences").font(.headline)
                        Toggle("Notifications", isOn: $notificationsEnabled)
                        Toggle("Haptics", isOn: $hapticsEnabled)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("About").font(.headline)
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                                .foregroundStyle(.secondary)
                        }
                        if let url = URL(string: "https://example.com/privacy") {
                            Link("Privacy Policy", destination: url)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Innstillinger")
        .onAppear { selectedIconKey = AppIconManager.currentKey() }
    }
}

// Temporary inline HealthSettingsView until file inclusion issue is resolved
struct HealthSettingsView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("userName") private var userName: String = ""
    @State private var isRequestingAuthorization = false
    @State private var authorizationMessage: String? = nil
    @State private var authorizationSucceeded: Bool? = nil
    
    private var healthService: HealthKitService { app.healthService }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                // Authorization Section
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("HealthKit Authorization")
                            .font(.headline)
                        
                        if healthService.isAuthorized {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Authorized")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button {
                                Task { @MainActor in
                                    guard !isRequestingAuthorization else { return }
                                    isRequestingAuthorization = true
                                    authorizationMessage = nil
                                    authorizationSucceeded = nil
                                    let granted = await app.requestHealthAuthorization()
                                    authorizationSucceeded = granted
                                    if granted {
                                        authorizationMessage = "Health access enabled."
                                        app.successHaptic()
                                    } else {
                                        authorizationMessage = "Authorization was not granted. You can enable access in the Health app."
                                        app.tapHaptic()
                                    }
                                    isRequestingAuthorization = false
                                }
                            }
                            label: {
                                HStack(spacing: AppTheme.spacingS) {
                                    if isRequestingAuthorization {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    }
                                    Text("Request Authorization")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            .disabled(isRequestingAuthorization)
                        }

                        if let message = authorizationMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle((authorizationSucceeded ?? false) ? Color.green : Color.orange)
                                .padding(.top, AppTheme.spacingXS)
                        }
                    }
                }
                
                // Profile Section
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Profile")
                            .font(.headline)
                        
                        TextField("Name", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Connect Apple Health to sync your health data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Exercise Data Section
                if healthService.isAuthorized {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Today's Activity")
                                .font(.headline)
                            
                            ExerciseStatsView()
                                .environmentObject(healthService)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Health Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Exercise stats component
struct ExerciseStatsView: View {
    @EnvironmentObject private var healthService: HealthKitService
    @State private var exerciseMinutes: Double = 0
    @State private var walkingDistance: Double = 0
    @State private var weeklyStats: (totalMinutes: Double, totalWorkouts: Int, avgDuration: Double) = (0, 0, 0)
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            if isLoading {
                ProgressView("Loading exercise data...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Exercise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(exerciseMinutes)) min")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km", walkingDistance))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(weeklyStats.totalWorkouts) workouts")
                            .font(.subheadline)
                        Text(String(format: "%.0f min total", weeklyStats.totalMinutes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Avg Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f min", weeklyStats.avgDuration))
                            .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await loadExerciseData()
        }
    }
    
    private func loadExerciseData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let exerciseData = healthService.todayExerciseMinutes()
            async let distanceData = healthService.todayWalkingRunningDistance()
            async let weeklyData = healthService.weeklyExerciseStats()
            
            exerciseMinutes = try await exerciseData
            walkingDistance = try await distanceData
            weeklyStats = try await weeklyData
        } catch {
            print("Error loading exercise data: \(error)")
        }
    }
}

#Preview { SettingsView().environmentObject(CoachEngineManager()) }
