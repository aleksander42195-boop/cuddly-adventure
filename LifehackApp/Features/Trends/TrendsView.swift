import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TrendsView: View {
    @EnvironmentObject var app: AppState
    @State private var hrv7: [HealthKitService.HealthDataPoint] = []
    @State private var steps7: [HealthKitService.HealthDataPoint] = []
    @State private var loading: Bool = false
    @State private var days: Int = 7

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Trends")
                            .font(.largeTitle).bold()
                        Text("HRV, Steps over time")
                            .foregroundStyle(.secondary)
                        Picker("Range", selection: $days) {
                            Text("7d").tag(7)
                            Text("30d").tag(30)
                            Text("90d").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Trends range")
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
                                if let last = hrv7.last, pt.date == last.date {
                                    RuleMark(x: .value("Today", last.date))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.secondary)
                                    Annotation(position: .overlay, alignment: .topTrailing) {
                                        Text(String(format: "%.0f ms", last.value))
                                            .font(.caption2)
                                            .padding(4)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .frame(height: 160)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4))
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .accessibilityLabel("\(days)-day HRV average chart. Latest \(Int(hrv7.last?.value ?? 0)) milliseconds.")
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
                                if let last = steps7.last, pt.date == last.date {
                                    Annotation(position: .overlay, alignment: .topTrailing) {
                                        Text("\(Int(last.value))")
                                            .font(.caption2)
                                            .padding(4)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .frame(height: 160)
                            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                            .chartYAxis { AxisMarks(position: .leading) }
                            .accessibilityLabel("\(days)-day steps chart. Latest \(Int(steps7.last?.value ?? 0)) steps.")
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
        .onChange(of: days) { _, _ in Task { await loadTrends() } }
    }

    @MainActor
    private func loadTrends() async {
        loading = true
        async let hrv = app.healthService.hrvDailyAverage(days: days)
        async let steps = app.healthService.stepsDailyTotal(days: days)
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
