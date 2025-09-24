import Foundation
#if canImport(HealthKit)
import HealthKit

enum HealthKitServiceError: Error {
    case notAvailable
    case notAuthorized
}

final class HealthKitService {
    private let store = HKHealthStore()
    private(set) var isAuthorized: Bool = false

    private var readTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { set.insert(active) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { set.insert(mindful) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }

    init() {
#if !targetEnvironment(simulator)
        Task { await requestAuthorizationIfNeeded() }
#endif
    }

    private func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
        return true
    }

    func fetchTodaySnapshot() async throws -> TodaySnapshot? {
        guard isAuthorized else { throw HealthKitServiceError.notAuthorized }

        async let stress = latestSDNN(in: calendar.todayRange)
        async let energy = latestRestingHR(in: calendar.todayRange)
        async let battery = sumSteps(in: calendar.todayRange)

        let (hrvMs, resting, stepsTotal) = try await (stress, energy, battery)

        return TodaySnapshot(stress: stress, energy: energy, battery: battery,
                             hrvSDNNms: hrvMs, restingHR: resting, steps: stepsTotal)
    }

    // Convenience: return placeholder instead of throwing (UI-friendly)
    func safeTodaySnapshot() async -> TodaySnapshot {
        do {
            return try await fetchTodaySnapshot() ?? .placeholder
        } catch {
            return .placeholder
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
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, results, error in
            // Handle results
        }
        store.execute(query)
        // Await results
    }

    private func sumQuantity(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Int {
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .sum) { _, result, error in
            // Handle results
        }
        store.execute(query)
        // Await results
    }
}
#else
final class HealthKitService {
    private(set) var isAuthorized: Bool = false
    func requestAuthorization() async throws -> Bool { false }
    func fetchTodaySnapshot() async throws -> TodaySnapshot? { .placeholder }
    func safeTodaySnapshot() async -> TodaySnapshot { .placeholder }
}
#endif
