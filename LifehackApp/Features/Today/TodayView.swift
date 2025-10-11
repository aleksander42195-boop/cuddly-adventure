import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.themeTokens) private var theme
    @State private var studyOfTheDay: Study? = nil
    @State private var studyError: String? = nil
    @State private var showingChatGPTLogin = false
    
    // Activity data from HealthKit
    @State private var activeMinutes: Double = 0
    @State private var walkingDistance: Double = 0
    @StateObject private var healthService = HealthKitService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                topControlsSection
                healthPermissionSection
                
                // New Advanced Health Card replacing the simple metrics
                AdvancedHealthCard(
                    energy: app.today.energy,
                    battery: app.today.battery,
                    stress: app.today.stress,
                    hrvSDNN: app.today.hrvSDNNms,
                    sleepHours: app.lastNightSleepHours,
                    steps: app.today.steps
                )
                
                // Advanced Study Card replacing simple study section
                AdvancedStudyCard(
                    study: studyOfTheDay,
                    isLoading: studyOfTheDay == nil && studyError == nil,
                    onRefresh: { Task { await reloadStudy(force: true) } },
                    onBookmark: { 
                        if let slug = studyOfTheDay?.slug { 
                            BookmarkStore.shared.toggle(slug: slug) 
                        }
                    },
                    onOpen: {
                        if let study = studyOfTheDay, let url = study.url {
                            UIApplication.shared.open(url)
                        }
                    },
                    isBookmarked: BookmarkStore.shared.isBookmarked(slug: studyOfTheDay?.slug ?? "")
                )
                
                // Advanced Trends Card (new addition)
                AdvancedTrendsCard(
                    weeklyEnergyData: generateWeeklyData(for: .energy),
                    weeklyStressData: generateWeeklyData(for: .stress),
                    weeklyHRVData: generateWeeklyData(for: .hrv)
                )
                
                // Advanced AI Coach Card replacing simple AI section
                AdvancedAICoachCard(
                    energyLevel: app.today.energy,
                    stressLevel: app.today.stress,
                    sleepHours: app.lastNightSleepHours,
                    recentTrend: "stable",
                    onStartCoaching: {
                        app.tapHaptic()
                        showingChatGPTLogin = true
                    }
                )
                
                // Advanced Activity Card
                AdvancedActivityCard(
                    metHours: app.todayMETHours,
                    steps: app.today.steps,
                    activeMinutes: activeMinutes,
                    walkingDistance: walkingDistance
                )
                
                // Advanced Sleep Card
                AdvancedSleepCard(
                    sleepHours: app.lastNightSleepHours,
                    bedtime: calculateBedtime(),
                    wakeTime: calculateWakeTime(),
                    sleepEfficiency: calculateSleepEfficiency(),
                    zodiacSign: Zodiac.from(date: app.birthdate).rawValue
                )
                refreshButton
            }
            .padding()
            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
        }
        .refreshable {
            await app.refreshFromHealthIfAvailable()
            studyOfTheDay = StudyRecommender.shared.selectStudy(for: app.today)
            await loadActivityData()
        }
        .task {
            await loadActivityData()
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
            
            settingsButton
        }
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
    
    // Helper functions for sleep card data
    private func calculateBedtime() -> Date? {
        // Estimate bedtime based on sleep duration and wake time
        // This is a placeholder - you could enhance this with actual HealthKit sleep data
        let calendar = Calendar.current
        let now = Date()
        let estimatedWakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        return calendar.date(byAdding: .hour, value: -Int(app.lastNightSleepHours), to: estimatedWakeTime)
    }
    
    private func calculateWakeTime() -> Date? {
        // Estimate wake time - this could be enhanced with actual HealthKit data
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)
    }
    
    private func calculateSleepEfficiency() -> Double {
        // Calculate sleep efficiency based on sleep hours
        // This is a simplified calculation - in a real app you'd use actual sleep stages data
        let optimalSleep = 8.0
        let deviation = abs(app.lastNightSleepHours - optimalSleep)
        return max(0.4, 1.0 - (deviation / 4.0))
    }
    
    // Load activity data from HealthKit
    private func loadActivityData() async {
        do {
            async let exerciseData = healthService.todayExerciseMinutes()
            async let distanceData = healthService.todayWalkingRunningDistance()
            
            let (exercise, distance) = try await (exerciseData, distanceData)
            
            await MainActor.run {
                activeMinutes = exercise
                walkingDistance = distance
            }
        } catch {
            print("Error loading activity data: \(error)")
            // Use placeholder values on error
            await MainActor.run {
                activeMinutes = 25.0
                walkingDistance = 3.2
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
    
    // Helper function to generate sample weekly data for trends
    private func generateWeeklyData(for metric: TrendMetricType) -> [DailyMetric] {
        return (0..<7).map { days in
            let baseValue: Double
            let variance: Double
            
            switch metric {
            case .energy:
                baseValue = app.today.energy
                variance = 0.2
            case .stress:
                baseValue = app.today.stress
                variance = 0.15
            case .hrv:
                baseValue = min(1.0, app.today.hrvSDNNms / 50.0)
                variance = 0.25
            }
            
            let randomVariation = Double.random(in: -variance...variance)
            let value = max(0, min(1.0, baseValue + randomVariation))
            
            return DailyMetric(
                date: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                value: value
            )
        }.reversed()
    }
    
    private enum TrendMetricType {
        case energy, stress, hrv
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
