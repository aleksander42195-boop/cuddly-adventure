import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                if !app.isHealthAuthorized {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Label("Health permissions needed", systemImage: "heart.text.square")
                                .font(.headline)
                            Text("Allow Health access to fetch HRV, Resting HR and Steps.")
                                .foregroundStyle(.secondary)
                            HStack {
                                Spacer()
                                Button("Allow in Health") {
                                    Task { await app.requestHealthAuthorization() }
                                }
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        }
                    }
                }
                GlassCard {
                    HStack(spacing: AppTheme.spacingL) {
                        MetricRing(title: "Stress",  value: app.today.stress,  systemImage: "bolt.heart")
                        MetricRing(title: "Energy",  value: app.today.energy,  systemImage: "flame")
                        MetricRing(title: "Battery", value: app.today.battery, systemImage: "battery.100")
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("HRV (SDNN)").font(.headline)
                        Text(app.today.hrvLabel)
                            .font(.title2.monospacedDigit())
                        Text("Resting HR: \(app.today.restingHR, specifier: "%.0f") bpm · Steps: \(app.today.steps)")
                            .foregroundStyle(.secondary)
#if canImport(Charts)
                        TodayHRVSparkline()
                            .frame(height: 60)
                            .accessibilityLabel("7-day HRV sparkline. Latest \(app.today.hrvLabel).")
#endif
                    }
                }

                Button {
                    app.tapHaptic()
                    Task { await app.refreshFromHealthIfAvailable() }
                } label: {
                    Label("Refresh from Health", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Today metrics. Stress \(Int(app.today.stress * 100)) percent. " +
                "Energy \(Int(app.today.energy * 100)) percent. " +
                "Battery \(Int(app.today.battery * 100)) percent. " +
                "HRV \(app.today.hrvLabel). Steps \(app.today.steps)."
            )
        }
        .refreshable {
            await app.refreshFromHealthIfAvailable()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 12) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppState())
}

#Preview("TodayView") {
    let state = AppState()
    state.today = .placeholder
    return NavigationView {
        TodayView()
            .environmentObject(state)
            .appThemeTokens(AppTheme.tokens())
    }
}

#if canImport(Charts)
private struct TodayHRVSparkline: View {
    @EnvironmentObject var app: AppState
    @State private var points: [HealthKitService.HealthDataPoint] = []
    var body: some View {
        Chart(points, id: \.date) { pt in
            LineMark(x: .value("Date", pt.date, unit: .day), y: .value("HRV", pt.value))
                .interpolationMethod(.monotone)
                .foregroundStyle(.cyan)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .task { await load() }
    }
    private func load() async {
        let data = (try? await app.healthService.hrvDailyAverage(days: 7)) ?? []
        await MainActor.run { points = data }
    }
}
#endif
