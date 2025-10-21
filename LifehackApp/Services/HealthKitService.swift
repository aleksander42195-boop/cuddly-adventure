import Foundation
#if canImport(HealthKit)
import HealthKit

enum HealthKitServiceError: Error {
    case notAvailable
    case notAuthorized
}

private extension Calendar {
    var todayRange: ClosedRange<Date> {
        let start = startOfDay(for: Date())
        let end = date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
        return start...end
    }
}

private extension NSPredicate {
    static func defaultPredicate(for range: ClosedRange<Date>) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: range.lowerBound, end: range.upperBound, options: .strictEndDate)
    }
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let store = HKHealthStore()
    @Published private(set) var isAuthorized: Bool = false
    private let calendar = Calendar.current
    
    // User profile data
    @Published var userBirthDate: Date?
    @Published var userSex: HKBiologicalSex?
    @Published var userHeight: Double? // in centimeters
    @Published var userWeight: Double? // in kilograms
    struct HealthDataPoint: Sendable, Hashable {
        let date: Date
        let value: Double
    }

    private var readTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(active) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(weight) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(mindful) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        
        // Add workout/exercise types
        set.insert(HKObjectType.workoutType())
        if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(exerciseTime) }
        if let standTime = HKObjectType.quantityType(forIdentifier: .appleStandTime) { set.insert(standTime) }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { set.insert(distance) }
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) { set.insert(cycling) }
        if let swimming = HKObjectType.quantityType(forIdentifier: .distanceSwimming) { set.insert(swimming) }
        if let stairs = HKObjectType.quantityType(forIdentifier: .flightsClimbed) { set.insert(stairs) }
        
        // Add additional types for comprehensive health tracking
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(heartRate) }
        if let hrvSDNN = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { set.insert(hrvSDNN) }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { set.insert(restingHR) }
        if let height = HKObjectType.quantityType(forIdentifier: .height) { set.insert(height) }
        
        return set
    }
    
    private var writeTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let weight = HKSampleType.quantityType(forIdentifier: .bodyMass) { set.insert(weight) }
        if let height = HKSampleType.quantityType(forIdentifier: .height) { set.insert(height) }
        return set
    }
    
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async throws {
        guard isHealthKitAvailable() else {
            throw HealthKitServiceError.notAvailable
        }
        
        // Create separate sets for different types
        let allReadTypes = readTypes
        
        try await store.requestAuthorization(toShare: writeTypes, read: allReadTypes)
        
        await MainActor.run {
            self.checkAuthorizationStatus()
        }
        await loadUserData()
    }
    
    @MainActor
    private func checkAuthorizationStatus() {
        // Check if we have authorization for key health types
        let keyTypes: [HKObjectType] = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let hasAuthorization = keyTypes.allSatisfy { type in
            store.authorizationStatus(for: type) == .sharingAuthorized
        }
        
        isAuthorized = hasAuthorization
    }
    
    @MainActor
    private func loadUserData() async {
        await loadBirthDate()
        await loadBiologicalSex()
        await loadLatestHeight()
        await loadLatestWeight()
    }
    
    @MainActor
    private func loadBirthDate() async {
        do {
            let dateOfBirth = try store.dateOfBirthComponents()
            userBirthDate = Calendar.current.date(from: dateOfBirth)
        } catch {
            print("Error loading birth date: \(error)")
        }
    }
    
    @MainActor
    private func loadBiologicalSex() async {
        do {
            let biologicalSex = try store.biologicalSex()
            userSex = biologicalSex.biologicalSex
        } catch {
            print("Error loading biological sex: \(error)")
        }
    }
    
    @MainActor
    private func loadLatestHeight() async {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { return }
        
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }

            let heightValue = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
            Task { @MainActor [weak self] in
                self?.userHeight = heightValue
            }
        }
        
        store.execute(query)
    }
    
    @MainActor
    private func loadLatestWeight() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }

            let weightValue = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            Task { @MainActor [weak self] in
                self?.userWeight = weightValue
            }
        }
        
        store.execute(query)
    }
    
    func saveHeight(_ height: Double) async throws {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            throw HealthKitServiceError.notAvailable
        }
        
        let heightQuantity = HKQuantity(unit: HKUnit.meterUnit(with: .centi), doubleValue: height)
        let heightSample = HKQuantitySample(
            type: heightType,
            quantity: heightQuantity,
            start: Date(),
            end: Date()
        )
        
        try await store.save(heightSample)
        
        await MainActor.run {
            userHeight = height
        }
    }
    
    func saveWeight(_ weight: Double) async throws {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitServiceError.notAvailable
        }
        
        let weightQuantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight)
        let weightSample = HKQuantitySample(
            type: weightType,
            quantity: weightQuantity,
            start: Date(),
            end: Date()
        )
        
        try await store.save(weightSample)
        
        await MainActor.run {
            userWeight = weight
        }
    }
    
    // Get recent HRV data
    func getRecentHRVData(days: Int = 7) async -> [HKQuantitySample]? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching HRV data: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: samples as? [HKQuantitySample])
            }
            
            self.store.execute(query)
        }
    }
    
    // Get recent heart rate data
    func getRecentHeartRateData(days: Int = 7) async -> [HKQuantitySample]? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching heart rate data: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: samples as? [HKQuantitySample])
            }
            
            self.store.execute(query)
        }
    }

    init() {
#if !targetEnvironment(simulator)
        Task {
            await requestAuthorizationIfNeeded()
            await checkAuthorizationStatus()
            await loadUserData()
        }
#endif
    }

    private func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func fetchTodaySnapshot() async throws -> TodaySnapshot? {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }

        let range = calendar.todayRange
        async let hrvMs = latestSDNN(in: range)
        async let resting = latestRestingHR(in: range)
        async let stepsTotal = sumSteps(in: range)

        let (hrv, rest, steps) = try await (hrvMs, resting, stepsTotal)
        let heur = deriveHeuristics(hrvMs: hrv, restingHR: rest, steps: steps)
        return TodaySnapshot(stress: heur.stress, energy: heur.energy, battery: heur.battery,
                             hrvSDNNms: hrv, restingHR: rest, steps: steps)
    }

    // Convenience: return placeholder instead of throwing (UI-friendly)
    func safeTodaySnapshot() async -> TodaySnapshot {
        do {
            return try await fetchTodaySnapshot() ?? .placeholder
        } catch {
            return .placeholder
        }
    }

    // MARK: Daily Series (for Trends)
    func hrvDailyAverage(days: Int) async throws -> [HealthDataPoint] {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.secondUnit(with: .milli)
        return try await dailyStatistics(
            type: type,
            options: .discreteAverage,
            unit: unit,
            days: days
        )
    }

    func stepsDailyTotal(days: Int) async throws -> [HealthDataPoint] {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.count()
        return try await dailyStatistics(
            type: type,
            options: .cumulativeSum,
            unit: unit,
            days: days
        )
    }

    func restingHRDailyAverage(days: Int) async throws -> [HealthDataPoint] {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit(from: "count/min")
        return try await dailyStatistics(
            type: type,
            options: .discreteAverage,
            unit: unit,
            days: days
        )
    }

    // Simple energy proxy series using heuristics from available series
    func energyProxyDaily(days: Int) async -> [HealthDataPoint] {
        // Use steps as a crude proxy; normalize to 0..1 scale, then *100 for readability
        let steps = (try? await stepsDailyTotal(days: days)) ?? []
        let mapped = steps.map { HealthDataPoint(date: $0.date, value: min(1.0, $0.value / 8000.0) * 100.0) }
        return mapped
    }

    // Rolling average smoother
    func rollingAverage(_ series: [HealthDataPoint], window: Int) -> [HealthDataPoint] {
        guard window > 1, series.count >= window else { return series }
        var acc = 0.0
        var out: [HealthDataPoint] = []
        for i in 0..<series.count {
            acc += series[i].value
            if i >= window { acc -= series[i - window].value }
            let smoothed = i >= window - 1 ? acc / Double(window) : acc / Double(i + 1)
            out.append(.init(date: series[i].date, value: smoothed))
        }
        return out
    }

    // Shared daily stats helper
    private func dailyStatistics(type: HKQuantityType, options: HKStatisticsOptions, unit: HKUnit, days: Int) async throws -> [HealthDataPoint] {
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: calendar.date(byAdding: .day, value: 1, to: endDate), options: .strictEndDate)
        let anchor = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: options, anchorDate: anchor, intervalComponents: interval)
            q.initialResultsHandler = { _, collection, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let collection = collection else { cont.resume(returning: []); return }
                var points: [HealthDataPoint] = []
                collection.enumerateStatistics(from: startDate, to: self.calendar.date(byAdding: .day, value: 1, to: endDate)!) { stats, _ in
                    let date = stats.startDate
                    let value: Double
                    switch options {
                    case .cumulativeSum:
                        value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteAverage:
                        value = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                    default:
                        value = 0
                    }
                    points.append(.init(date: date, value: value))
                }
                cont.resume(returning: points)
            }
            self.store.execute(q)
        }
    }

    // MARK: Sleep
    func lastNightSleepHours() async throws -> Double {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.notAvailable
        }

        // Define a "last night" window: yesterday 18:00 to today 12:00
        let cal = calendar
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!
        let start = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
        let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: startOfToday)!
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                let samples = (results as? [HKCategorySample]) ?? []
                let asleepValues: Set<Int> = {
                    var v: Set<Int> = [1] // asleepUnspecified
                    if #available(iOS 16.0, *) {
                        v.formUnion([3,4,5]) // core, deep, rem raw values
                    }
                    return v
                }()
                var total: TimeInterval = 0
                for s in samples {
                    guard asleepValues.contains(s.value) else { continue }
                    let overlapStart = max(s.startDate, start)
                    let overlapEnd = min(s.endDate, end)
                    if overlapEnd > overlapStart { total += overlapEnd.timeIntervalSince(overlapStart) }
                }
                cont.resume(returning: total / 3600.0)
            }
            self.store.execute(q)
        }
    }

    // Heuristic computation (factored for future refinement)
    private func deriveHeuristics(hrvMs: Double, restingHR: Double, steps: Int) -> (stress: Double, energy: Double, battery: Double) {
        let stress = max(0.0, min(1.0, 1.0 - (hrvMs / 100.0)))
        let energy = max(0.0, min(1.0, (100.0 - restingHR) / 100))
        let battery = max(0.0, min(1.0, Double(steps) / 8000.0))
        return (stress, energy, battery)
    }

    // MARK: Queries
    private func latestSDNN(in range: ClosedRange<Date>) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.secondUnit(with: .milli)
        return try await latestQuantity(type: type, predicate: .defaultPredicate(for: range), unit: unit)
    }

    private func latestRestingHR(in range: ClosedRange<Date>) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit(from: "count/min")
        return try await latestQuantity(type: type, predicate: .defaultPredicate(for: range), unit: unit)
    }

    private func sumSteps(in range: ClosedRange<Date>) async throws -> Int {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.count()
        return try await sumQuantity(type: type, predicate: .defaultPredicate(for: range), unit: unit)
    }

    private func latestQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let q = results?.first as? HKQuantitySample else {
                    cont.resume(returning: 0)
                    return
                }
                cont.resume(returning: q.quantity.doubleValue(for: unit))
            }
            self.store.execute(q)
        }
    }

    private func sumQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { cont.resume(throwing: error); return }
                let val = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: Int(val.rounded()))
            }
            self.store.execute(q)
        }
    }

    // MARK: BodyMass & MET
    private func latestBodyMassKg() async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.gramUnit(with: .kilo)
        return try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let q = results?.first as? HKQuantitySample else { cont.resume(returning: 0); return }
                cont.resume(returning: q.quantity.doubleValue(for: unit))
            }
            self.store.execute(q)
        }
    }

    func todayMETHours() async throws -> Double {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.kilocalorie()
        // sum active energy today
        let range = calendar.todayRange
        let kcal: Double = try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: .defaultPredicate(for: range), options: .cumulativeSum) { _, result, error in
                if let error = error { cont.resume(throwing: error); return }
                let val = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            self.store.execute(q)
        }
        // latest body mass
        let kg = try await latestBodyMassKg()
        guard kg > 0 else { return 0 }
        // MET-hours approx = kcal / kg
        return kcal / kg
    }
    
    // MARK: - Exercise/Workout Methods
    
    /// Fetch recent workouts within the specified number of days
    func fetchRecentWorkouts(days: Int = 7) async throws -> [HKWorkout] {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), 
                                    predicate: predicate, 
                                    limit: HKObjectQueryNoLimit, 
                                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                
                let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                cont.resume(returning: workouts)
            }
            
            store.execute(query)
        }
    }
    
    /// Get today's exercise minutes (Apple Exercise Time)
    func todayExerciseMinutes() async throws -> Double {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitServiceError.notAvailable
        }
        
        let range = calendar.todayRange
        let unit = HKUnit.minute()
        
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: exerciseType, 
                                        quantitySamplePredicate: .defaultPredicate(for: range), 
                                        options: .cumulativeSum) { _, result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                
                let minutes = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: minutes)
            }
            
            store.execute(query)
        }
    }
    
    /// Get total distance walked/run today
    func todayWalkingRunningDistance() async throws -> Double {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitServiceError.notAvailable
        }
        
        let range = calendar.todayRange
        let unit = HKUnit.meterUnit(with: .kilo) // kilometers
        
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: distanceType, 
                                        quantitySamplePredicate: .defaultPredicate(for: range), 
                                        options: .cumulativeSum) { _, result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                
                let distance = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: distance)
            }
            
            store.execute(query)
        }
    }
    
    /// Get weekly exercise statistics
    func weeklyExerciseStats() async throws -> (totalMinutes: Double, totalWorkouts: Int, avgDuration: Double) {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        
        // Get recent workouts from the past 7 days
        let workouts = try await fetchRecentWorkouts(days: 7)
        let totalWorkouts = workouts.count
        
        // Calculate total duration in minutes
        let totalMinutes = workouts.reduce(0) { total, workout in
            total + workout.duration / 60.0 // Convert seconds to minutes
        }
        
        let avgDuration = totalWorkouts > 0 ? totalMinutes / Double(totalWorkouts) : 0
        
        return (totalMinutes: totalMinutes, totalWorkouts: totalWorkouts, avgDuration: avgDuration)
    }
    
    /// Get exercise data points for charting
    func exerciseDataPoints(days: Int = 30) async throws -> [HealthDataPoint] {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitServiceError.notAvailable
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let unit = HKUnit.minute()
        
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                
                var dailyStats: [Date: Double] = [:]
                
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let date = statistics.startDate
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    dailyStats[date] = value
                }
                
                let dataPoints = dailyStats.map { date, value in
                    HealthDataPoint(date: date, value: value)
                }.sorted { $0.date < $1.date }
                
                cont.resume(returning: dataPoints)
            }
            
            store.execute(query)
        }
    }
}
#else
final class HealthKitService {
    private(set) var isAuthorized: Bool = false
    func requestAuthorization() async throws -> Bool { false }
    func fetchTodaySnapshot() async throws -> TodaySnapshot? { .placeholder }
    func safeTodaySnapshot() async -> TodaySnapshot { .placeholder }
    struct HealthDataPoint: Sendable, Hashable { let date: Date; let value: Double }
    func hrvDailyAverage(days: Int) async throws -> [HealthDataPoint] { [] }
    func stepsDailyTotal(days: Int) async throws -> [HealthDataPoint] { [] }
    func restingHRDailyAverage(days: Int) async throws -> [HealthDataPoint] { [] }
    func energyProxyDaily(days: Int) async -> [HealthDataPoint] { [] }
    func rollingAverage(_ series: [HealthDataPoint], window: Int) -> [HealthDataPoint] { series }
    func lastNightSleepHours() async throws -> Double { 0 }
    
    // Exercise/Workout mock methods
    func fetchRecentWorkouts(days: Int = 7) async throws -> [Any] { [] }
    func todayExerciseMinutes() async throws -> Double { 0 }
    func todayWalkingRunningDistance() async throws -> Double { 0 }
    func weeklyExerciseStats() async throws -> (totalMinutes: Double, totalWorkouts: Int, avgDuration: Double) { 
        (totalMinutes: 0, totalWorkouts: 0, avgDuration: 0) 
    }
    func exerciseDataPoints(days: Int = 30) async throws -> [HealthDataPoint] { [] }
}
#endif
