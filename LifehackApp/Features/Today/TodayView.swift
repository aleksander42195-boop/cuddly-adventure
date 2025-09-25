import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme
    @State private var studyOfTheDay: Study? = nil
    @State private var showingHRVExplanation = false
    @State private var showingChatGPTLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                // Top section with battery ring and controls
                HStack {
                    BatteryPaletteRing(value: app.today.battery)
                    Spacer()
                    
                    // Camera and Settings buttons
                    HStack(spacing: 16) {
                        // Camera button
                        Button {
                            app.tapHaptic()
                            showingHRVExplanation = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .accessibilityLabel("Learn about HRV Camera")
                        
                        // Settings cogwheel - golden sandy style
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.8, green: 0.6, blue: 0.2), Color(red: 0.9, green: 0.7, blue: 0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color(red: 0.8, green: 0.6, blue: 0.2).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .onTapGesture { app.tapHaptic() }
                        .accessibilityLabel("Open Settings")
                    }
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
                        ActivityPyramid(mets: app.todayMETHours)
                        Text(String(format: "MET-h: %.1f", app.todayMETHours))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // AI Coach Menu Card
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.headline)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("AI Health Coach")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text("Get personalized insights based on your health data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Button {
                                app.tapHaptic()
                                showingChatGPTLogin = true
                            } label: {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.purple, .pink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Text("Setup AI Coach")
                                }
                            }
                            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            
                            Spacer()
                        }
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
                NavigationLink(destination: ProfileView()) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingHRVExplanation) {
            HRVCameraExplanationView()
        }
        .sheet(isPresented: $showingChatGPTLogin) {
            ChatGPTLoginView()
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
