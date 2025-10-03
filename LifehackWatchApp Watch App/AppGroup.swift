import Foundation

enum AppGroup {
    // Update this to match your App Group identifier in Signing & Capabilities
    static let id = "group.com.yourorg.lifehack"
    static let defaults: UserDefaults = {
        if let ud = UserDefaults(suiteName: id) { return ud }
        return .standard
    }()
}
