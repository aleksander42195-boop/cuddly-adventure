import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme
    @State private var studyOfTheDay: Study? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                // Top battery ring palette (left aligned)
                HStack {
                    BatteryPaletteRing(value: app.today.battery)
                    Spacer()
                }
                .padding(.horizontal)

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
                    VStack(spacing: AppTheme.spacing) {
                        StressGauge(stress: app.today.stress)
                        HStack(spacing: AppTheme.spacing) {
                            MetricRing(title: "Energy",  value: app.today.energy,  systemImage: "flame")
                            Spacer()
                        }
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
                        if app.isHealthAuthorized {
                            TodayHRVSparkline()
                                .frame(height: 60)
                                .accessibilityLabel("7-day HRV sparkline. Latest \(app.today.hrvLabel).")
                        }
#endif
                        if !app.isHealthAuthorized {
                            HStack {
                                Spacer()
                                Button("Allow Health") { Task { await app.requestHealthAuthorization() } }
                                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        }
                    }
                }

                if let s = studyOfTheDay ?? StudyRecommender.shared.loadTodaysStudy() {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Study of the day").font(.headline)
                            Text(s.title).font(.subheadline).bold()
                            Text("\(s.authors) • \(s.journal) (\(s.year))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let first = s.takeaways.first { Text(first).font(.caption) }
                            HStack {
                                if let url = s.url {
                                    Link("Open", destination: url)
                                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                                }
                                Button(BookmarkStore.shared.isBookmarked(slug: s.slug) ? "Saved" : "Save") {
                                    BookmarkStore.shared.toggle(slug: s.slug)
                                }
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        }
                    }
                }

                // Sleep card with zodiac and last-night duration
                StarrySleepCard(zodiac: Zodiac.from(date: app.birthdate), hours: app.lastNightSleepHours)

                // Activity pyramid (using steps as proxy to METs for now)
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Activity").font(.headline)
                        ActivityPyramid(mets: Double(app.today.steps) / 1000.0)
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
            studyOfTheDay = StudyRecommender.shared.selectStudy(for: app.today)
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
