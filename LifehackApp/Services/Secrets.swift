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

    // Convenience to check if a user-provided key is set
    var hasUserAPIKey: Bool { Vault.loadOpenAIKey() != nil }

    var healthKitEnabledFlag: Bool {
        // Default to true if the key is missing so HealthKit works out of the box
        if let v = dict["HEALTHKIT_ENABLED"] as? Bool { return v }
        return true
    }

    // Managed Proxy configuration
    var proxyBaseURL: URL? {
        if let s = string("PROXY_BASE_URL"), let u = URL(string: s) { return u }
        if let s = AppGroup.defaults.string(forKey: "proxy_base_url"), let u = URL(string: s) { return u }
        return nil
    }

    func setProxyBaseURL(_ urlString: String) {
        AppGroup.defaults.set(urlString, forKey: "proxy_base_url")
    }

    var proxyAccessToken: String? {
        Vault.loadProxyAccessToken()
    }
    func setProxyAccessToken(_ token: String) {
        Vault.saveProxyAccessToken(token)
    }
    func clearProxyAccessToken() {
        Vault.deleteProxyAccessToken()
    }
}
