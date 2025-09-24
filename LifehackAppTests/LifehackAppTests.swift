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
}
