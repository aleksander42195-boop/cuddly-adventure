import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Trends")
                            .font(.largeTitle).bold()
                        Text("HRV, Stress, Energy, Steps (7/30/90 days)")
                            .foregroundStyle(.secondary)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HRV (SDNN) Trend")
                            .font(.headline)
                        Text("Charts coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stress / Energy Balance")
                            .font(.headline)
                        Text("Charts coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Trends")
    }
}

#Preview {
    TrendsView().environmentObject(AppState())
}
