import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var engineManager: CoachEngineManager
    @EnvironmentObject private var app: AppState
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var selectedIconKey: String? = AppIconManager.currentKey()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing) {
                    // HealthKit Access
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Health").font(.headline)
                            if app.isHealthAuthorized {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                    Text("Tilgang til Health er gitt")
                                        .foregroundStyle(.secondary)
                                }
                                // Permissions status line
                                let statuses = app.healthService.authorizationBreakdown()
                                if !statuses.isEmpty {
                                    let summary = statuses.map { "\($0.name): \($0.authorized ? "✅" : "❌")" }.joined(separator: " · ")
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button("Gi tilgang til Health") {
                                    Task { await app.requestHealthAuthorization() }
                                }
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Connected Apps").font(.headline)
                            NavigationLink("Manage Connections") { ConnectedAppsView() }
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
            .onAppear {
                selectedIconKey = AppIconManager.currentKey()
                if !app.isHealthAuthorized {
                    Task { await app.requestHealthAuthorization() }
                }
            }
        }
    }
}

#Preview { SettingsView().environmentObject(CoachEngineManager()) }
