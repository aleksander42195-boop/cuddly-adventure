import Foundation

final class SleepService {
    static let shared = SleepService()
    private init() {}

    func lastNightSleepHours() async -> Double {
        // TODO: Replace with HealthKit sleep analysis
        return 7.2
    }
}
