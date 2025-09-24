import Foundation

enum DeveloperFlags {
    static var isDeveloperMode: Bool {
        ProcessInfo.processInfo.environment["LIFEHACK_DEVELOPER_MODE"] == "YES"
    }
    static var fakeHealthKit: Bool {
        ProcessInfo.processInfo.environment["LIFEHACK_ENABLE_FAKE_HEALTHKIT"] == "YES"
    }
    static var verboseLogging: Bool {
        ProcessInfo.processInfo.environment["LIFEHACK_VERBOSE_LOGGING"] == "YES"
    }
}
