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

final class HealthKitService {
    private let store = HKHealthStore()
    private(set) var isAuthorized: Bool = false
    private let calendar = Calendar.current
    struct HealthDataPoint: Sendable, Hashable {
        let date: Date
        let value: Double
    }

    // Gate via Secrets: allow disabling HealthKit reads at runtime
    private var isHealthKitEnabled: Bool {
        Secrets.shared.healthKitEnabledFlag
    }

    // Minimal share types to improve authorization status detection.
    // Requesting share for workouts/mindfulness lets us reliably query status via HealthKit APIs.
    private var shareTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(mindful) }
        return set
    }

    private var readTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(active) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        // Critical for Today metrics
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { set.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { set.insert(rhr) }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(weight) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(mindful) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] readTypes includes \(set.count) types: \(set.map { $0.identifier }.joined(separator: ", "))")
        }
        return set
    }

    init() {
#if !targetEnvironment(simulator)
        Task {
            await requestAuthorizationIfNeeded()
        }
#endif
    }

    private func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            await updateAuthorizationStatus()
            if DeveloperFlags.verboseLogging {
                print("[HealthKit] requestAuthorizationIfNeeded -> isAuthorized=\(isAuthorized)")
            }
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { return false }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        await updateAuthorizationStatus()
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] requestAuthorization() -> isAuthorized=\(isAuthorized)")
        }
        return isAuthorized
    }

    @MainActor
    private func updateAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { self.isAuthorized = false; return }
        do {
            let status = try await store.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes)
            switch status {
            case .shouldRequest:
                self.isAuthorized = computeAuthorizationStatus()
            case .unknown, .unnecessary:
                self.isAuthorized = true
            @unknown default:
                self.isAuthorized = computeAuthorizationStatus()
            }
        } catch {
            if DeveloperFlags.verboseLogging { print("[HealthKit] getRequestStatusForAuthorization error: \(error)") }
            self.isAuthorized = computeAuthorizationStatus()
        }
    }

    func fetchTodaySnapshot() async throws -> TodaySnapshot? {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }

        let range = calendar.todayRange
        async let hrvMs = latestSDNN(in: range)
        async let resting = latestRestingHR(in: range)
        async let stepsTotal = sumSteps(in: range)

        var (hrv, rest, steps) = try await (hrvMs, resting, stepsTotal)

    // Fallbacks for days with no samples
    let hrvRecent: Double? = (try? await latestSDNNRecent(daysBack: 7)) ?? nil
    if hrv <= 0, let v = hrvRecent, v > 0 { hrv = v }
    let rhrRecent: Double? = (try? await latestRestingHRRecent(daysBack: 7)) ?? nil
    if rest <= 0, let v = rhrRecent, v > 0 { rest = v }
        let heur = deriveHeuristics(hrvMs: hrv, restingHR: rest, steps: steps)
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] TodaySnapshot hrv=\(hrv)ms rhr=\(rest)bpm steps=\(steps) -> stress=\(heur.stress), energy=\(heur.energy), battery=\(heur.battery)")
        }
        return TodaySnapshot(stress: heur.stress, energy: heur.energy, battery: heur.battery,
                             hrvSDNNms: hrv, restingHR: rest, steps: steps)
    }

    // Convenience: return placeholder instead of throwing (UI-friendly)
    func safeTodaySnapshot() async -> TodaySnapshot {
        do {
            if HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled {
                isAuthorized = computeAuthorizationStatus()
            }
            let snapshot = try await fetchTodaySnapshot() ?? .placeholder
            if DeveloperFlags.verboseLogging {
                print("[HealthKit] safeTodaySnapshot() -> success: \(snapshot)")
            }
            return snapshot
        } catch {
            if DeveloperFlags.verboseLogging {
                print("[HealthKit] safeTodaySnapshot() -> error: \(error), returning placeholder")
            }
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
    private func computeAuthorizationStatus() -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { return false }
        // For our Today metrics, consider authorized if at least one key type is authorized for reading
        var anyAuthorized = false
        let keys: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ]
        for key in keys.compactMap({ $0 }) {
            let status = store.authorizationStatus(for: key)
            if status == .sharingAuthorized { anyAuthorized = true }
            if DeveloperFlags.verboseLogging {
                print("[HealthKit] authorizationStatus(\(key.identifier)) = \(status.rawValue)")
            }
        }
        return anyAuthorized
    }

    private func latestSDNN(in range: ClosedRange<Date>) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.secondUnit(with: .milli)
        return try await latestQuantity(type: type, predicate: .defaultPredicate(for: range), unit: unit)
    }

    private func latestSDNNRecent(daysBack: Int) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit.secondUnit(with: .milli)
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -max(1, daysBack), to: end) ?? Date.distantPast
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        return try await latestQuantityOptional(type: type, predicate: pred, unit: unit)
    }

    private func latestRestingHR(in range: ClosedRange<Date>) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit(from: "count/min")
        return try await latestQuantity(type: type, predicate: .defaultPredicate(for: range), unit: unit)
    }

    private func latestRestingHRRecent(daysBack: Int) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitServiceError.notAvailable
        }
        let unit = HKUnit(from: "count/min")
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -max(1, daysBack), to: end) ?? Date.distantPast
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        return try await latestQuantityOptional(type: type, predicate: pred, unit: unit)
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
                if let error = error { 
                    if DeveloperFlags.verboseLogging {
                        print("[HealthKit] latestQuantity(\(type.identifier)) -> error: \(error)")
                    }
                    cont.resume(throwing: error)
                    return 
                }
                guard let sample = results?.first as? HKQuantitySample else {
                    if DeveloperFlags.verboseLogging {
                        print("[HealthKit] latestQuantity(\(type.identifier)) -> no samples found, returning 0")
                    }
                    cont.resume(returning: 0)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                if DeveloperFlags.verboseLogging {
                    print("[HealthKit] latestQuantity(\(type.identifier)) -> found sample: \(value) \(unit), date: \(sample.endDate)")
                }
                cont.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    private func latestQuantityOptional(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, error in
                if let error = error {
                    if DeveloperFlags.verboseLogging {
                        print("[HealthKit] latestQuantityOptional(\(type.identifier)) -> error: \(error)")
                    }
                    cont.resume(returning: nil)
                    return
                }
                guard let sample = results?.first as? HKQuantitySample else {
                    cont.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    private func sumQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { 
                    if DeveloperFlags.verboseLogging {
                        print("[HealthKit] sumQuantity(\(type.identifier)) -> error: \(error)")
                    }
                    cont.resume(throwing: error)
                    return 
                }
                let val = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                let intVal = Int(val.rounded())
                if DeveloperFlags.verboseLogging {
                    print("[HealthKit] sumQuantity(\(type.identifier)) -> sum: \(intVal) \(unit)")
                }
                cont.resume(returning: intVal)
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

    // MARK: - Metadata helpers
    /// Returns the endDate of the most recent HRV (SDNN) sample, optional daysBack window.
    func latestHRVSampleDate(daysBack: Int? = nil) async -> Date? {
        guard isAuthorized else { return nil }
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let end = Date()
        let pred: NSPredicate? = {
            if let days = daysBack, days > 0 {
                let start = calendar.date(byAdding: .day, value: -days, to: end) ?? Date.distantPast
                return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
            }
            return nil
        }()
        return await latestSampleDate(sampleType: type, predicate: pred)
    }

    /// Returns a compact authorization breakdown for core types used by the app.
    func authorizationBreakdown() -> [(name: String, authorized: Bool)] {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { return [] }
        let pairs: [(String, HKObjectType?)] = [
            ("HRV", HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)),
            ("Resting HR", HKObjectType.quantityType(forIdentifier: .restingHeartRate)),
            ("Steps", HKObjectType.quantityType(forIdentifier: .stepCount)),
            ("Sleep", HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
        ]
        return pairs.compactMap { (name, type) in
            guard let t = type else { return nil }
            let status = store.authorizationStatus(for: t)
            return (name: name, authorized: status == .sharingAuthorized)
        }
    }

    private func latestSampleDate(sampleType: HKSampleType, predicate: NSPredicate?) async -> Date? {
        await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let date = results?.first?.endDate
                cont.resume(returning: date)
            }
            self.store.execute(q)
        }
    }
}
#else
final class HealthKitService {
                await updateAuthorizationStatus()
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
    func latestHRVSampleDate(daysBack: Int? = nil) async -> Date? { nil }
    func authorizationBreakdown() -> [(name: String, authorized: Bool)] { [] }
}
#endif
