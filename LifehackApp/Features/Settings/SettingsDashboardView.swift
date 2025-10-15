import SwiftUI

struct SettingsDashboardView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var coachEngineManager: CoachEngineManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingAuthorization = false
    @State private var profileSummary = ProfileSummary()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing) {
                    healthAccessCard
                    userMetricsCard
                    advancedSettingsCard
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Health Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadProfileSummary)
    }

    private var healthAccessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    Label("Health Access", systemImage: "heart.text.square")
                        .font(.headline)
                    Spacer()
                    statusBadge
                }

                Text("Manage your connection to Apple Health to keep activity and recovery metrics in sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.spacingS) {
                    Button {
                        guard !isRequestingAuthorization else { return }
                        Task {
                            isRequestingAuthorization = true
                            await app.requestHealthAuthorization()
                            isRequestingAuthorization = false
                        }
                    } label: {
                        Label(app.isHealthAuthorized ? "Review Permissions" : "Enable Health Access",
                              systemImage: app.isHealthAuthorized ? "checkmark.shield" : "heart.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    .disabled(isRequestingAuthorization)

                    if app.isHealthAuthorized {
                        Button {
                            app.tapHaptic()
                            Task { await app.refreshFromHealthIfAvailable() }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if app.isHealthAuthorized {
                Label("Authorized", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("Not Connected", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var userMetricsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Label("Profile & Metrics", systemImage: "person.crop.rectangle.stack")
                    .font(.headline)

                if profileSummary.hasSavedData {
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        if let name = profileSummary.fullName, !name.isEmpty {
                            Text(name)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        if let level = profileSummary.activityLevel {
                            Label(level.title, systemImage: "figure.run.square.stack")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let sleep = profileSummary.sleepHours {
                            Label(String(format: "%.1f hrs nightly", sleep), systemImage: "bed.double")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if profileSummary.fitnessGoalCount > 0 {
                            Label("\(profileSummary.fitnessGoalCount) active fitness goals", systemImage: "target")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Add your health profile to unlock personalised insights and coaching recommendations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    UserMetricsView()
                        .environmentObject(app)
                } label: {
                    Label(profileSummary.hasSavedData ? "Update Metrics" : "Add Metrics", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.tapHaptic() })
            }
        }
    }

    private var advancedSettingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Label("Advanced", systemImage: "gearshape")
                    .font(.headline)

                Text("Fine-tune notifications, app appearance, and AI coaching preferences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    SettingsView()
                        .environmentObject(coachEngineManager)
                } label: {
                    Label("Open Full Settings", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.tapHaptic() })
            }
        }
    }

    private func loadProfileSummary() {
        var summary = ProfileSummary()
        let defaults = UserDefaults.standard

        if let name = defaults.string(forKey: "user_full_name"), !name.isEmpty {
            summary.fullName = name
        }

        if let activityRaw = defaults.string(forKey: "user_activity_level"),
           let level = ActivityLevel(rawValue: activityRaw) {
            summary.activityLevel = level
        }

        if let hours = defaults.object(forKey: "user_sleep_hours") as? Double {
            summary.sleepHours = hours
        }

        if let goalsData = defaults.data(forKey: "user_fitness_goals"),
           let goals = try? JSONDecoder().decode(Set<FitnessGoal>.self, from: goalsData) {
            summary.fitnessGoalCount = goals.count
        }

        profileSummary = summary
    }
}

private struct ProfileSummary {
    var fullName: String? = nil
    var activityLevel: ActivityLevel? = nil
    var sleepHours: Double? = nil
    var fitnessGoalCount: Int = 0

    var hasSavedData: Bool {
        if let name = fullName, !name.isEmpty { return true }
        if activityLevel != nil { return true }
        if sleepHours != nil { return true }
        if fitnessGoalCount > 0 { return true }
        return false
    }
}

#Preview {
    SettingsDashboardView()
        .environmentObject(AppState())
        .environmentObject(CoachEngineManager())
}
