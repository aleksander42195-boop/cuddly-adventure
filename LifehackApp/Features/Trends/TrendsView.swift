import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TrendsView: View {
    @EnvironmentObject var app: AppState
    @State private var hrv7: [HealthKitService.HealthDataPoint] = []
    @State private var steps7: [HealthKitService.HealthDataPoint] = []
    @State private var loading: Bool = false

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
                        HStack {
                            Text("HRV (SDNN) – last 7 days").font(.headline)
                            if loading { ProgressView().scaleEffect(0.8) }
                        }
#if canImport(Charts)
                        if hrv7.isEmpty {
                            Text("No data").foregroundStyle(.secondary)
                        } else {
                            Chart(hrv7, id: \.
date) { pt in
                                LineMark(
                                    x: .value("Date", pt.date, unit: .day),
                                    y: .value("HRV", pt.value)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.cyan)
                                PointMark(
                                    x: .value("Date", pt.date, unit: .day),
                                    y: .value("HRV", pt.value)
                                )
                                .foregroundStyle(.cyan.opacity(0.7))
                            }
                            .frame(height: 160)
                        }
#else
                        Text("Charts unavailable on this platform").foregroundStyle(.secondary)
#endif
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Steps – last 7 days").font(.headline)
                            if loading { ProgressView().scaleEffect(0.8) }
                        }
#if canImport(Charts)
                        if steps7.isEmpty {
                            Text("No data").foregroundStyle(.secondary)
                        } else {
                            Chart(steps7, id: \.
date) { pt in
                                BarMark(
                                    x: .value("Date", pt.date, unit: .day),
                                    y: .value("Steps", pt.value)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .frame(height: 160)
                        }
#else
                        Text("Charts unavailable on this platform").foregroundStyle(.secondary)
#endif
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Trends")
        .task { await loadTrends() }
        .refreshable { await loadTrends() }
    }

    @MainActor
    private func loadTrends() async {
        loading = true
        async let hrv = app.healthService.hrvDailyAverage(days: 7)
        async let steps = app.healthService.stepsDailyTotal(days: 7)
        let hrvRes = (try? await hrv) ?? []
        let stepsRes = (try? await steps) ?? []
        hrv7 = hrvRes
        steps7 = stepsRes
        loading = false
    }
}

#Preview {
    TrendsView().environmentObject(AppState())
}
