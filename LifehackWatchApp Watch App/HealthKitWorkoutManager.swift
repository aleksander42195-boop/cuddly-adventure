import Foundation
import Combine
import HealthKit

final class HealthKitWorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?

    @Published var currentHeartRate: Int = 0

    var onHeartRate: ((Int) -> Void)?

    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let workoutType = HKObjectType.workoutType()

    func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToShare: Set = [workoutType]
        let typesToRead: Set = [heartRateType, hrvType, workoutType]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    func startWorkout(activity: HKWorkoutActivityType = .other) {
        let config = HKWorkoutConfiguration()
        config.activityType = activity
        config.locationType = .unknown

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            // On watchOS, HKWorkoutSession doesn't expose a device property in this context. Pass nil to use current.
            builder = session.map { _ in HKLiveWorkoutBuilder(healthStore: healthStore, configuration: config, device: nil) }

            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date(), completion: { [weak self] _, _ in
                self?.beginHeartRateStreaming()
            })
        } catch {
            print("[HKWorkout] Failed to start: \(error)")
        }
    }

    func endWorkout() {
        heartRateQuery.map { healthStore.stop($0) }
        heartRateQuery = nil
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        session?.stopActivity(with: Date())
        session?.end()
        session = nil
        builder = nil
    }

    private func beginHeartRateStreaming() {
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.handle(samples: samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handle(samples: samples)
        }
        healthStore.execute(query)
        heartRateQuery = query
    }

    private func handle(samples: [HKSample]?) {
        guard let qSamples = samples as? [HKQuantitySample] else { return }
        guard let last = qSamples.last else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let hr = Int(last.quantity.doubleValue(for: bpmUnit))
        DispatchQueue.main.async {
            self.currentHeartRate = hr
            self.onHeartRate?(hr)
        }
    }

    func fetchLatestHRV(completion: @escaping (Double?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // HealthKit HRV SDNN unit is milliseconds
            let unit = HKUnit.secondUnit(with: .milli)
            let ms = sample.quantity.doubleValue(for: unit)
            DispatchQueue.main.async { completion(ms) }
        }
        healthStore.execute(query)
    }
}
