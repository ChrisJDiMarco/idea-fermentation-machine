import Foundation
import Security

public enum APIProviderKey: String, CaseIterable, Sendable {
    case gemini
    case zai
    case kimi
    case openAI
    case anthropic
    case firecrawl
    case openAICompatible
    /// Bearer token paired with the Chrome capture extension. Stored encrypted in
    /// Keychain rather than the plaintext SQLite settings table.
    case captureServerToken
}

public enum KeychainStoreError: Error, LocalizedError, Equatable {
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): "Keychain returned status \(status)."
        }
    }
}

public enum KeychainStore {
    private static let service = "com.chrisdimarco.idea-fermentation-machine"

    public static func load(_ key: APIProviderKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    public static func save(_ value: String, for key: APIProviderKey) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            delete(key)
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    public static func delete(_ key: APIProviderKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
