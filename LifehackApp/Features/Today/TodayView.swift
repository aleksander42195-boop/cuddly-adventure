import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
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
                    }
                }

                Button {
                    app.tapHaptic()
                    app.refreshFromHealthIfAvailable()
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
            app.refreshFromHealthIfAvailable()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Today")
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
