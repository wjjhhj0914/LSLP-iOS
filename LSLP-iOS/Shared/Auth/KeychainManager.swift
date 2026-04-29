//
//  KeychainManager.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import Foundation
import Security

struct KeychainManager: KeychainManaging {
    private let service: String

    nonisolated init(service: String = "com.hyojung.LSLP-iOS.auth") {
        self.service = service
    }

    func save(_ value: String, for key: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidValue
        }

        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    func loadValue(for key: String) async throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let value = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.invalidValue
            }
            return value

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.unhandledError(status)
        }
    }

    func deleteValue(for key: String) async throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

enum KeychainError: LocalizedError {
    case invalidValue
    case unhandledError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidValue:
            return "Keychain value could not be encoded or decoded."
        case let .unhandledError(status):
            return "Keychain operation failed with status: \(status)"
        }
    }
}
