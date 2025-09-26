import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme
    @State private var studyOfTheDay: Study? = nil
    @State private var studyError: String? = nil
    @State private var showingHRVExplanation = false
    @State private var showingChatGPTLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                topControlsSection
                healthPermissionSection
                metricsSection
                hrvSection
                studySection
                activitySection
                aiCoachSection
                sleepSection
                refreshButton
            }
            .padding()
        }
        .refreshable {
            await app.refreshFromHealthIfAvailable()
            studyOfTheDay = StudyRecommender.shared.selectStudy(for: app.today)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: ProfileView()) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingHRVExplanation) {
            NavigationView {
                HRVCameraView()
                    .navigationTitle("HRV Camera")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingHRVExplanation = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingChatGPTLogin) {
            NavigationView {
                StreamingCoachView()
                    .navigationTitle("AI Health Coach")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingChatGPTLogin = false
                            }
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today metrics. Stress \(Int(app.today.stress * 100)) percent. " +
            "Energy \(Int(app.today.energy * 100)) percent. " +
            "Battery \(Int(app.today.battery * 100)) percent. " +
            "HRV \(app.today.hrvLabel). Steps \(app.today.steps)."
        )
    }
    
    private var topControlsSection: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 16) {
                cameraButton
                settingsButton
            }
        }
    }
    
    private var cameraButton: some View {
        Button {
            app.tapHaptic()
            showingHRVExplanation = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.cyan)
                .clipShape(Circle())
                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Learn about HRV Camera")
    }
    
    private var settingsButton: some View {
        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.orange)
                .clipShape(Circle())
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .onTapGesture { app.tapHaptic() }
        .accessibilityLabel("Open Settings")
    }
    
    private var healthPermissionSection: some View {
        Group {
            if !app.isHealthAuthorized {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Health Access")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text("Enable HealthKit permissions to start tracking your heart rate variability and fitness metrics.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Button("Enable Health Access") {
                            Task { await app.requestHealthAuthorization() }
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    }
                }
            }
        }
    }
    
    private var metricsSection: some View {
        MetricCardView(
            energy: app.today.energy,
            battery: app.today.battery,
            stress: app.today.stress,
            hrvSDNN: app.today.hrvSDNNms,
            sleepHours: app.lastNightSleepHours
        )
    }
    
    private var hrvSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text("HRV (SDNN)")
                    .font(.headline)
                
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
                        Button("Allow Health") { 
                            Task { await app.requestHealthAuthorization() } 
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    }
                }
            }
        }
    }
    
    private var studySection: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    HStack(spacing: 8) {
                        Text("Study of the day")
                            .font(.headline)
                        Spacer()
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Verified from PubMed")
                    }

                    Group {
                        if let s = studyOfTheDay {
                            Text(s.title)
                                .font(.subheadline)
                                .bold()
                            Text("\(s.authors) • \(s.journal) (\(s.year))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(s.takeaways.prefix(3)).indices, id: \.self) { i in
                                Text("• \(s.takeaways[i])")
                                    .font(.caption)
                            }
                        } else {
                            HStack { ProgressView().scaleEffect(0.8); Text("Loading...").font(.caption).foregroundStyle(.secondary) }
                        }
                    }

                    HStack {
                        if let s = studyOfTheDay, let url = s.url {
                            Link("Open", destination: url)
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                        }
                        Button(BookmarkStore.shared.isBookmarked(slug: studyOfTheDay?.slug ?? "") ? "Saved" : "Save") {
                            if let slug = studyOfTheDay?.slug { BookmarkStore.shared.toggle(slug: slug) }
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                        Spacer()
                        Button {
                            Task { await reloadStudy(force: true) }
                        } label: {
                            Label("Refresh Study", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    }

                    // Last updated + error
                    HStack {
                        if let last = DailyStudyService.shared.lastCachedDate {
                            let rel = RelativeDateTimeFormatter()
                            Text("Updated \(rel.localizedString(for: last, relativeTo: Date()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let err = studyError { Text(err).font(.caption2).foregroundStyle(.red) }
                    }
                }
                .task { await reloadStudy(force: false) }
            }
        }
    }

    private func reloadStudy(force: Bool) async {
        studyError = nil
        // Choose topic based on current health context
        let hrv = app.today.hrvSDNNms
        let stress = app.today.stress
        let sleep = app.lastNightSleepHours
        let energy = app.today.energy
        let battery = app.today.battery

        let topic: DailyStudyService.Topic = {
            // 1) High stress or low HRV => stress-focused literature
            if (hrv > 0 && hrv < 20) || stress >= 0.66 {
                return .stress
            }
            // 2) Poor sleep (outside 7-9h) => sleep
            if !(7.0...9.0).contains(sleep) && sleep > 0 {
                return .sleep
            }
            // 3) Low energy or battery => general nutrition/wellness
            if energy < 0.33 || battery < 0.33 {
                return .nutrition
            }
            // 4) Default to HRV
            return .hrv
        }()

        if force {
            if let remote = await DailyStudyService.shared.forceRefresh(preferred: topic) {
                studyOfTheDay = remote
                return
            } else {
                studyError = "Could not refresh"
            }
        } else {
            if let remote = await DailyStudyService.shared.studyOfTheDay(preferred: topic) {
                studyOfTheDay = remote
                return
            }
        }
        // Fallback to local recommender
        studyOfTheDay = StudyRecommender.shared.selectStudy(for: app.today)
    }

    // Note: DailyStudyService references removed to ensure build without extra target setup.
    
    private var activitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text("Activity")
                    .font(.headline)
                
                ActivityPyramid(mets: app.todayMETHours)
                
                Text(String(format: "MET-h: %.1f", app.todayMETHours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var aiCoachSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.headline)
                        .foregroundStyle(.purple)
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
                                .foregroundStyle(.purple)
                            Text("Setup AI Coach")
                        }
                    }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    
                    Spacer()
                }
            }
        }
    }
    
    private var sleepSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.blue)
                    Text("Sleep")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Last Night")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.1f", app.lastNightSleepHours)) hours")
                            .font(.title2.monospacedDigit())
                            .bold()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Zodiac")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(Zodiac.from(date: app.birthdate).rawValue)
                            .font(.title3)
                            .bold()
                    }
                }
                
                // Sleep score placeholder (you can enhance this later)
                HStack {
                    Text("Sleep Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Good") // Placeholder - can be calculated based on sleep hours
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.green)
                }
            }
        }
    }
    
    private var refreshButton: some View {
        VStack(spacing: 8) {
            // Sync status
            HStack {
                Text("Last sync:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(app.lastSyncStatusText)
                    .font(.caption)
                    .foregroundStyle(app.isSyncing ? .blue : .secondary)
            }
            
            // Manual sync button
            Button {
                app.tapHaptic()
                app.triggerManualSync()
            } label: {
                HStack {
                    if app.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Label(app.isSyncing ? "Syncing..." : "Sync Health Data", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            .disabled(app.isSyncing)
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
