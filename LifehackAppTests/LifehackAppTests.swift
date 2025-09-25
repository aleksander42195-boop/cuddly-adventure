import XCTest
@testable import LifehackApp

final class LifehackAppTests: XCTestCase {

    func testTodaySnapshotBuilder() {
        let base = TodaySnapshot.placeholder
        let updated = base.withUpdated(stress: 0.9)
        XCTAssertEqual(updated.stress, 0.9, accuracy: 0.0001)
        XCTAssertEqual(base.stress, TodaySnapshot.placeholder.stress) // immutability
    }

    func testChatMessageFactories() {
        let u = ChatMessage.user("Hi")
        XCTAssertTrue(u.isUser)
        let a = ChatMessage.assistant("Yo")
        XCTAssertTrue(a.isAssistant)
    }
    
    // MARK: - Additional Tests
    
    func testTodaySnapshotEmpty() {
        let empty = TodaySnapshot.empty
        XCTAssertEqual(empty.stress, 0.0)
        XCTAssertEqual(empty.energy, 0.0)
        XCTAssertEqual(empty.battery, 0.0)
        XCTAssertEqual(empty.hrvSDNNms, 0.0)
        XCTAssertEqual(empty.restingHR, 0.0)
        XCTAssertEqual(empty.steps, 0)
    }
    
    func testTodaySnapshotCategories() {
        let snapshot = TodaySnapshot(
            stress: 0.2,
            energy: 0.5,
            battery: 0.9,
            hrvSDNNms: 45.0,
            restingHR: 70.0,
            steps: 10000
        )
        
        XCTAssertEqual(snapshot.stressCategory, "Low")
        XCTAssertEqual(snapshot.energyCategory, "OK")
        XCTAssertEqual(snapshot.batteryCategory, "Full")
    }
    
    func testHealthMetricFormatting() {
        let metric = HealthMetric(type: .steps, value: 10500.5)
        XCTAssertEqual(metric.formattedValue, "10500 steps")
        
        let hrv = HealthMetric(type: .hrvSDNNms, value: 42.7)
        XCTAssertEqual(hrv.formattedValue, "43 ms")
    }
    
    func testHapticsManagerSingleton() {
        let haptics1 = HapticsManager.shared
        let haptics2 = HapticsManager.shared
        XCTAssertTrue(haptics1 === haptics2, "HapticsManager should be a singleton")
    }
    
    func testAppStateInitialization() {
        let appState = AppState()
        XCTAssertNotNil(appState.haptics)
        XCTAssertNotNil(appState.healthService)
        XCTAssertEqual(appState.today.stress, 0.0) // Should start with empty
    }
    
    func testZodiacCompute() {
        let date = Calendar.current.date(from: DateComponents(year: 1995, month: 3, day: 25))!
        let zodiac = Zodiac.compute(from: date)
        XCTAssertEqual(zodiac, .aries)
    }
}
