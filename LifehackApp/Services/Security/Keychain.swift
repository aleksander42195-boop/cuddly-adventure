import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Item already exists in Keychain."
        case .itemNotFound: return "Item not found in Keychain."
        case .unexpectedStatus(let status): return "Keychain error: \(status)."
        }
    }
}

// Lightweight string Keychain wrapper
enum Keychain {
    @discardableResult
    static func setString(_ value: String,
                          service: String,
                          account: String,
                          accessible: CFString = kSecAttrAccessibleAfterFirstUnlock) throws {
        let data = Data(value.utf8)
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: accessible
        ]
        let update = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if update == errSecSuccess { return }
        if update == errSecItemNotFound {
            query.merge(attrs) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus == errSecSuccess { return }
            if addStatus == errSecDuplicateItem { throw KeychainError.duplicateItem }
            throw KeychainError.unexpectedStatus(addStatus)
        }
        throw KeychainError.unexpectedStatus(update)
    }

    static func getString(service: String, account: String) throws -> String? {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    static func delete(service: String, account: String) throws {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(q as CFDictionary)
        if status == errSecItemNotFound { return }
        if status != errSecSuccess { throw KeychainError.unexpectedStatus(status) }
    }
}

// App-specific keys
enum Vault {
    static let openAIService = "Lifehack.OpenAI"
    static let openAIAccount = "apiKey"

    static func saveOpenAIKey(_ key: String) {
        try? Keychain.setString(key, service: openAIService, account: openAIAccount)
    }

    static func loadOpenAIKey() -> String? {
        (try? Keychain.getString(service: openAIService, account: openAIAccount)) ?? nil
    }

    static func deleteOpenAIKey() {
        try? Keychain.delete(service: openAIService, account: openAIAccount)
    }
}
