//
//  KeychainHelper.swift
//  Middlesex
//
//  Secure keychain storage for sensitive data like API keys
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidItemFormat
    case unexpectedStatus(OSStatus)
}

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    // Save a string value to the keychain
    func save(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.nicholasnoon.Middlesex",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        print("🔐 [Keychain] Successfully saved value for key: \(key)")
    }

    // Retrieve a string value from the keychain
    func retrieve(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.nicholasnoon.Middlesex",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            print("🔐 [Keychain] No value found for key: \(key)")
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }

        print("🔐 [Keychain] Successfully retrieved value for key: \(key)")
        return string
    }

    // Delete a value from the keychain
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.nicholasnoon.Middlesex"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }

        print("🔐 [Keychain] Successfully deleted value for key: \(key)")
    }

    // Update an existing value in the keychain
    func update(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.nicholasnoon.Middlesex"
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // If item doesn't exist, create it instead
        if status == errSecItemNotFound {
            try save(value, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        } else {
            print("🔐 [Keychain] Successfully updated value for key: \(key)")
        }
    }

    // Check if a key exists in the keychain
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.nicholasnoon.Middlesex",
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
