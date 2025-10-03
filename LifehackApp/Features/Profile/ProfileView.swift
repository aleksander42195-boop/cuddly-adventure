import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                if !app.isHealthAuthorized {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            HStack {
                                Image(systemName: "heart.fill").foregroundStyle(.pink)
                                Text("Health Access").font(.headline)
                                Spacer()
                            }
                            Text("Allow Health access to personalize your profile and metrics.")
                                .foregroundStyle(.secondary)
                            Button("Enable Health Access") {
                                Task { await app.requestHealthAuthorization() }
                            }
                            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                        }
                    }
                }
                GlassCard {
                    HStack(alignment: .center, spacing: AppTheme.spacing) {
                        Image(systemName: "person.circle.fill").font(.system(size: 72))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Profile").font(.title.bold())
                            Text("Manage personal details and health preferences")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Birthdate").font(.headline)
                        DatePicker("Select birthdate", selection: $app.birthdate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Text("Zodiac: \(Zodiac.from(date: app.birthdate).rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("User Metrics").font(.headline)
                        NavigationLink("Health Settings") { 
                            UserMetricsView()
                        }
                        NavigationLink("Privacy & Data") { 
                            PrivacySettingsView()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview { NavigationStack { ProfileView() } }
