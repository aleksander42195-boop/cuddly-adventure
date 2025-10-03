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

    // Note: There is no synchronous API to check read authorization. We treat the
    // overall isAuthorized flag as the single source of truth for UI display.

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
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(hr) }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { set.insert(spo2) }
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
        // Optimistically treat Health as connected for read flows; detailed reconciliation runs later.
        self.isAuthorized = true
        Task { await updateAuthorizationStatus() }
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] requestAuthorization() -> isAuthorized=\(isAuthorized)")
        }
        return isAuthorized
    }

    @MainActor
    private func updateAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { self.isAuthorized = false; return }
        do {
            let status: HKAuthorizationRequestStatus = try await withCheckedThrowingContinuation { cont in
                store.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { status, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: status)
                    }
                }
            }
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
        // Sedentary stress: elevated HR while low steps in short windows
        let sedentaryStress = await sedentaryStressScore(in: range, restingHR: rest)
        // Keep existing proxies for energy and battery
        let heur = deriveHeuristics(hrvMs: hrv, restingHR: rest, steps: steps)
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] TodaySnapshot hrv=\(hrv)ms rhr=\(rest)bpm steps=\(steps) -> sedentaryStress=\(sedentaryStress), energy=\(heur.energy), battery=\(heur.battery)")
        }
        return TodaySnapshot(stress: sedentaryStress, energy: heur.energy, battery: heur.battery,
                             hrvSDNNms: hrv, restingHR: rest, steps: steps)
    }

    // Convenience: return placeholder instead of throwing (UI-friendly)
    func safeTodaySnapshot() async -> TodaySnapshot {
        do {
            // Do not mutate isAuthorized here; authorization is managed by explicit requests
            // and updateAuthorizationStatus(). Recomputing here could incorrectly downgrade
            // the state (e.g., when only read types are granted).
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

    // MARK: Sleep Score (Last Night)
    struct SleepScore: Sendable {
        let score: Double // 0..1
        let timeInBedHours: Double
        let asleepHours: Double
        let awakeMinutes: Double
        let avgHRduringSleep: Double?
        let avgHRVduringSleepMs: Double?
        let avgSpO2: Double?
        let minSpO2: Double?
    }

    /// Compute a last-night sleep score using duration, restlessness (awake minutes),
    /// HRV, heart rate and SpO2. Windows: yesterday 18:00 -> today 12:00.
    func lastNightSleepScore() async throws -> SleepScore {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.notAvailable
        }

        // Window
        let cal = calendar
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!
        let start = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
        let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: startOfToday)!
        let range: ClosedRange<Date> = start...end

        // Fetch sleep samples
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let sleepSamples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            self.store.execute(q)
        }

        // Partition intervals
        let intervals = partitionSleepIntervals(sleepSamples: sleepSamples, window: range)
        let timeInBed = intervals.timeInBed
        let asleep = intervals.asleep
        let awake = intervals.awake

        // Compute metrics in parallel
        async let avgHR = averageHeartRateDuring(intervals: asleep)
        async let avgHRV = averageHRVDuring(intervals: asleep)
        async let spo2Stats = spo2StatsDuring(intervals: asleep)

        let (avgHRVms, avgHRbpm, (avgSpO2, minSpO2)) = (
            try? await avgHRV,
            try? await avgHR,
            (try? await spo2Stats) ?? (nil, nil)
        )

        // Derived measures
        let asleepHours = asleep.totalDuration / 3600.0
        let timeInBedHours = timeInBed.totalDuration / 3600.0
        let awakeMinutes = awake.totalDuration / 60.0

        // Individual sub-scores (0..1)
        let durationScore = min(1.0, asleepHours / 8.0)
        let restlessnessScore = max(0.0, 1.0 - min(1.0, awakeMinutes / 45.0))
        let hrvScore: Double? = avgHRVms.map { v in
            // Map 30..110 ms to 0..1
            let s = (v - 30.0) / (110.0 - 30.0)
            return max(0.0, min(1.0, s))
        }
        let hrScore: Double? = avgHRbpm.map { v in
            // Map 45..75 bpm to 1..0 (lower is better)
            let s = (75.0 - v) / 30.0
            return max(0.0, min(1.0, s))
        }
        let spo2Score: Double? = avgSpO2.map { v in
            // Map 90%..98% to 0..1
            let s = (v - 0.90) / 0.08
            return max(0.0, min(1.0, s))
        }

        // Weights (renormalize if some metrics are missing)
        var weighted: [(Double, Double)] = [] // (score, weight)
        weighted.append((durationScore, 0.35))
        weighted.append((restlessnessScore, 0.25))
        if let s = hrvScore { weighted.append((s, 0.15)) }
        if let s = hrScore { weighted.append((s, 0.15)) }
        if let s = spo2Score { weighted.append((s, 0.10)) }
        let totalW = weighted.reduce(0.0) { $0 + $1.1 }
        let score = totalW > 0 ? weighted.reduce(0.0) { $0 + $1.0 * ($1.1 / totalW) } : 0

        let result = SleepScore(
            score: score,
            timeInBedHours: timeInBedHours,
            asleepHours: asleepHours,
            awakeMinutes: awakeMinutes,
            avgHRduringSleep: avgHRbpm,
            avgHRVduringSleepMs: avgHRVms,
            avgSpO2: avgSpO2,
            minSpO2: minSpO2
        )
        if DeveloperFlags.verboseLogging { print("[HealthKit] SleepScore -> \(result)") }
        return result
    }

    // Partition sleep samples into union intervals
    private func partitionSleepIntervals(sleepSamples: [HKCategorySample], window: ClosedRange<Date>) -> (timeInBed: IntervalSet, asleep: IntervalSet, awake: IntervalSet) {
        var inBed = IntervalSet()
        var asleep = IntervalSet()
        var awake = IntervalSet()
        for s in sleepSamples {
            let start = max(s.startDate, window.lowerBound)
            let end = min(s.endDate, window.upperBound)
            guard end > start else { continue }
            inBed.add(start: start, end: end)
            // Values: 0=inBed, 1=asleepUnspecified; in iOS 16+: 3=core,4=deep,5=rem; 2=awake
            if s.value == 2 { awake.add(start: start, end: end) }
            else if s.value == 1 || s.value == 3 || s.value == 4 || s.value == 5 {
                asleep.add(start: start, end: end)
            }
        }
        return (inBed, asleep, awake)
    }

    // Average HR during specific intervals (time-weighted)
    private func averageHeartRateDuring(intervals: IntervalSet) async throws -> Double? {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let unit = HKUnit(from: "count/min")
        guard let bounds = intervals.bounds else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: bounds.lowerBound, end: bounds.upperBound, options: .strictEndDate)
        let samples: [HKQuantitySample] = try await quantitySamples(type: hrType, predicate: pred)
        if samples.isEmpty { return nil }
        var num = 0.0
        var den = 0.0
        for s in samples {
            let o = intervals.overlapDuration(start: s.startDate, end: s.endDate)
            guard o > 0 else { continue }
            let v = s.quantity.doubleValue(for: unit)
            num += v * o
            den += o
        }
        return den > 0 ? num / den : nil
    }

    private func averageHRVDuring(intervals: IntervalSet) async throws -> Double? {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let unit = HKUnit.secondUnit(with: .milli)
        guard let bounds = intervals.bounds else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: bounds.lowerBound, end: bounds.upperBound, options: .strictEndDate)
        let samples: [HKQuantitySample] = try await quantitySamples(type: hrvType, predicate: pred)
        if samples.isEmpty { return nil }
        // Simple average over samples (HRV is instantaneous)
        let vals = samples.map { $0.quantity.doubleValue(for: unit) }
        let avg = vals.reduce(0, +) / Double(vals.count)
        return avg
    }

    private func spo2StatsDuring(intervals: IntervalSet) async throws -> (avg: Double?, min: Double?) {
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return (nil, nil) }
        let unit = HKUnit.percent()
        guard let bounds = intervals.bounds else { return (nil, nil) }
        let pred = HKQuery.predicateForSamples(withStart: bounds.lowerBound, end: bounds.upperBound, options: .strictEndDate)
        let samples: [HKQuantitySample] = try await quantitySamples(type: spo2Type, predicate: pred)
        if samples.isEmpty { return (nil, nil) }
        let vals = samples.map { $0.quantity.doubleValue(for: unit) }
        let avg = vals.reduce(0, +) / Double(vals.count)
        let minV = vals.min()
        return (avg, minV)
    }

    private func quantitySamples(type: HKQuantityType, predicate: NSPredicate?) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            self.store.execute(q)
        }
    }

    // Lightweight interval set for union/overlap calculations
    private struct IntervalSet {
        private(set) var intervals: [ClosedRange<Date>] = []
        mutating func add(start: Date, end: Date) {
            guard end > start else { return }
            intervals.append(start...end)
            intervals = merge(intervals)
        }
        var totalDuration: TimeInterval { intervals.reduce(0) { $0 + $1.upperBound.timeIntervalSince($1.lowerBound) } }
        var bounds: ClosedRange<Date>? {
            guard let first = intervals.first, let last = intervals.last else { return nil }
            return min(first.lowerBound, intervals.map { $0.lowerBound }.min()!) ... max(last.upperBound, intervals.map { $0.upperBound }.max()!)
        }
        func overlapDuration(start: Date, end: Date) -> TimeInterval {
            var total: TimeInterval = 0
            for r in intervals {
                let s = max(start, r.lowerBound)
                let e = min(end, r.upperBound)
                if e > s { total += e.timeIntervalSince(s) }
            }
            return total
        }
        private func merge(_ arr: [ClosedRange<Date>]) -> [ClosedRange<Date>] {
            guard !arr.isEmpty else { return [] }
            let sorted = arr.sorted { $0.lowerBound < $1.lowerBound }
            var out: [ClosedRange<Date>] = [sorted[0]]
            for r in sorted.dropFirst() {
                let last = out.removeLast()
                if r.lowerBound <= last.upperBound { out.append(last.lowerBound ... max(last.upperBound, r.upperBound)) }
                else { out.append(last); out.append(r) }
            }
            return out
        }
    }

    // Heuristic computation (factored for future refinement)
    private func deriveHeuristics(hrvMs: Double, restingHR: Double, steps: Int) -> (stress: Double, energy: Double, battery: Double) {
        let stress = max(0.0, min(1.0, 1.0 - (hrvMs / 100.0)))
        let energy = max(0.0, min(1.0, (100.0 - restingHR) / 100))
        let battery = max(0.0, min(1.0, Double(steps) / 8000.0))
        return (stress, energy, battery)
    }

    // MARK: Sedentary Stress
    /// Computes a sedentary stress score for the provided range by combining 5-minute
    /// average heart rate with step counts. Minutes with very low steps are considered sedentary;
    /// elevated HR above resting baseline in those windows contributes to stress load.
    /// Normalization is chosen so ~60 minutes at +15 bpm maps near 1.0.
    private func sedentaryStressScore(in range: ClosedRange<Date>, restingHR: Double) async -> Double {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        // 5-minute bins to reduce noise and cost
        let interval = DateComponents(minute: 5)
        let anchor = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let hrUnit = HKUnit(from: "count/min")
        let stepsUnit = HKUnit.count()

        // Build collections in parallel
        async let hrPointsAsync: [HealthDataPoint] = statisticsSeries(
            type: hrType, options: .discreteAverage, unit: hrUnit, range: range, interval: interval, anchor: anchor
        )
        async let stepsPointsAsync: [HealthDataPoint] = statisticsSeries(
            type: stepsType, options: .cumulativeSum, unit: stepsUnit, range: range, interval: interval, anchor: anchor
        )

        let (hrPoints, stepsPoints) = await ((try? hrPointsAsync) ?? [], (try? stepsPointsAsync) ?? [])
        if hrPoints.isEmpty { return 0 }

        // Index steps by timestamp for quick join
        var stepsByDate: [Date: Double] = [:]
        for p in stepsPoints { stepsByDate[p.date] = p.value }

        // Parameters
        let sedentaryStepsThreshold = 3.0 // ~ no walking in 5 minutes
        let hrBuffer = max(5.0, 0.08 * restingHR) // ignore tiny bumps (<~8% or <5bpm)
        let baseline = max(40.0, restingHR) // reasonable floor

        var load = 0.0
        var sedentaryMinutes = 0.0
        for hp in hrPoints {
            let steps = stepsByDate[hp.date] ?? 0
            let isSedentary = steps <= sedentaryStepsThreshold
            guard isSedentary else { continue }
            sedentaryMinutes += 5.0
            let delta = max(0.0, hp.value - (baseline + hrBuffer))
            // Integrate delta over the window size (5 minutes)
            load += delta * 5.0
        }

        if sedentaryMinutes <= 0 { return 0 }
        // Normalize: 60 min at +15 bpm -> 1.0 => denom = 15 * 60 = 900
        let normalized = min(1.0, load / 900.0)
        if DeveloperFlags.verboseLogging {
            print("[HealthKit] sedentaryStress: load=\(Int(load)) baseline=\(baseline) buffer=\(Int(hrBuffer)) sedMin=\(Int(sedentaryMinutes)) -> score=\(normalized))")
        }
        return normalized
    }

    /// Generic statistics collection to produce regular-interval series for a type.
    private func statisticsSeries(type: HKQuantityType, options: HKStatisticsOptions, unit: HKUnit, range: ClosedRange<Date>, interval: DateComponents, anchor: Date) async throws -> [HealthDataPoint] {
        return try await withCheckedThrowingContinuation { cont in
            let predicate = NSPredicate.defaultPredicate(for: range)
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: options, anchorDate: anchor, intervalComponents: interval)
            q.initialResultsHandler = { _, collection, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let collection = collection else { cont.resume(returning: []); return }
                var out: [HealthDataPoint] = []
                collection.enumerateStatistics(from: range.lowerBound, to: range.upperBound) { stats, _ in
                    let value: Double
                    switch options {
                    case .cumulativeSum:
                        value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteAverage:
                        value = stats.averageQuantity()?.doubleValue(for: unit) ?? 0
                    default:
                        value = 0
                    }
                    out.append(.init(date: stats.startDate, value: value))
                }
                cont.resume(returning: out)
            }
            self.store.execute(q)
        }
    }

    // MARK: Queries
    private func computeAuthorizationStatus() -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), isHealthKitEnabled else { return false }
        // authorizationStatus(for:) reports share permission status.
        // Use only share types here; read types are not reflected by this API.
        var anyAuthorized = false
        for shareType in shareTypes {
            let status = store.authorizationStatus(for: shareType)
            if status == .sharingAuthorized { anyAuthorized = true }
            if DeveloperFlags.verboseLogging {
                print("[HealthKit] share authorizationStatus(\(shareType.identifier)) = \(status.rawValue)")
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
        let mapping: [(String, HKObjectType?)] = [
            ("HRV", HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)),
            ("Resting HR", HKObjectType.quantityType(forIdentifier: .restingHeartRate)),
            ("Steps", HKObjectType.quantityType(forIdentifier: .stepCount)),
            ("Sleep", HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
        ]
        // We cannot synchronously query read-authorization per type. For UI purposes,
        // reflect the overall authorization state uniformly for the listed types.
        let granted = isAuthorized
        return mapping.compactMap { (name, maybeType) in
            guard maybeType != nil else { return nil }
            return (name: name, authorized: granted)
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
    private(set) var isAuthorized: Bool = false
    func requestAuthorization() async throws -> Bool { false }
    func fetchTodaySnapshot() async throws -> TodaySnapshot? { .placeholder }
    func safeTodaySnapshot() async -> TodaySnapshot { .placeholder }
    struct HealthDataPoint: Sendable, Hashable { let date: Date; let value: Double }
    func hrvDailyAverage(days: Int) async throws -> [HealthDataPoint] { [] }
    func stepsDailyTotal(days: Int) async throws -> [HealthDataPoint] { [] }
    func restingHRDailyAverage(days: Int) async throws -> [HealthDataPoint] { [] }
    func todayMETHours() async throws -> Double { 0 }
    func energyProxyDaily(days: Int) async -> [HealthDataPoint] { [] }
    func rollingAverage(_ series: [HealthDataPoint], window: Int) -> [HealthDataPoint] { series }
    func lastNightSleepHours() async throws -> Double { 0 }
    // Keep API parity with HealthKit-enabled build for simulator and other platforms
    struct SleepScore: Sendable {
        let score: Double
        let timeInBedHours: Double
        let asleepHours: Double
        let awakeMinutes: Double
        let avgHRduringSleep: Double?
        let avgHRVduringSleepMs: Double?
        let avgSpO2: Double?
        let minSpO2: Double?
    }
    func lastNightSleepScore() async throws -> SleepScore {
        return SleepScore(
            score: 0,
            timeInBedHours: 0,
            asleepHours: 0,
            awakeMinutes: 0,
            avgHRduringSleep: nil,
            avgHRVduringSleepMs: nil,
            avgSpO2: nil,
            minSpO2: nil
        )
    }
    func latestHRVSampleDate(daysBack: Int? = nil) async -> Date? { nil }
    func authorizationBreakdown() -> [(name: String, authorized: Bool)] { [] }
}
#endif
