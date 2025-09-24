import Foundation

final class Secrets {
    static let shared = Secrets()
    private let dict: [String: Any]

    private init() {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let d = obj as? [String: Any] {
            dict = d
        } else {
            dict = [:]
        }
    }

    // Base access
    func string(_ key: String) -> String? { dict[key] as? String }
    func bool(_ key: String) -> Bool { dict[key] as? Bool ?? false }

    // Runtime override (UserDefaults)
    var openAIAPIKey: String? {
        if let key = Vault.loadOpenAIKey(), !key.isEmpty { return key }
        return string("OPENAI_API_KEY")
    }

    func setOpenAIOverride(_ key: String) {
        Vault.saveOpenAIKey(key)
    }

    func clearOpenAIOverride() {
        Vault.deleteOpenAIKey()
    }

    var healthKitEnabledFlag: Bool {
        bool("HEALTHKIT_ENABLED")
    }
}
