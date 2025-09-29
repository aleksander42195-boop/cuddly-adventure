import Foundation

enum DeveloperFlags {
    static var isDeveloperMode: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["LIFEHACK_DEVELOPER_MODE"] == "YES"
        #endif
    }
    static var fakeHealthKit: Bool {
        ProcessInfo.processInfo.environment["LIFEHACK_ENABLE_FAKE_HEALTHKIT"] == "YES"
    }
    static var verboseLogging: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["LIFEHACK_VERBOSE_LOGGING"] == "YES"
        #endif
    }

    // Feature flags
    static var enableManagedProxy: Bool {
        ProcessInfo.processInfo.environment["LIFEHACK_ENABLE_MANAGED_PROXY"] == "YES"
    }
}
