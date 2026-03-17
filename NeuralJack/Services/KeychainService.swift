//
//  KeychainService.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation
import Security

/// Keychain account identifiers for NeuralJack secrets.
enum KeychainAccount: String {
    case anthropicAPIKey = "com.neuraljack.anthropic-api-key"
}

/// Manages secure storage in macOS Keychain.
/// Thread-safe; Keychain API calls are synchronous and safe from any context.
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private init() {}

    func save(key: String, for account: KeychainAccount) throws {
        try? delete(for: account)
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainService", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save key"])
        }
    }

    func load(for account: KeychainAccount) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            throw NSError(domain: "KeychainService", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to load key"])
        }
        return string
    }

    func delete(for account: KeychainAccount) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "KeychainService", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to delete key"])
        }
    }
}
