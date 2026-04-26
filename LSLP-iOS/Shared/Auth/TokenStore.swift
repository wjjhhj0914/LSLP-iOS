//
//  TokenStore.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Foundation

protocol TokenStore: Sendable {
    func save(_ tokens: AuthTokens) async throws
    func loadTokens() async throws -> AuthTokens?
    func clear() async throws
}

protocol KeychainManaging: Sendable {
    func save(_ value: String, for key: String) async throws
    func loadValue(for key: String) async throws -> String?
    func deleteValue(for key: String) async throws
}

enum TokenStorageKey: String {
    case accessToken
    case refreshToken
}

actor InMemoryTokenStore: TokenStore {
    private var cachedTokens: AuthTokens?

    func save(_ tokens: AuthTokens) async throws {
        cachedTokens = tokens
        print(
            "TokenStore saved accessToken: \(tokens.accessToken.maskedToken), refreshToken: \(tokens.refreshToken.maskedToken)"
        )
    }

    func loadTokens() async throws -> AuthTokens? {
        cachedTokens
    }

    func clear() async throws {
        cachedTokens = nil
    }
}

struct KeychainTokenStore: TokenStore {
    private let keychainManager: any KeychainManaging

    init(keychainManager: any KeychainManaging) {
        self.keychainManager = keychainManager
    }

    func save(_ tokens: AuthTokens) async throws {
        try await keychainManager.save(tokens.accessToken, for: TokenStorageKey.accessToken.rawValue)
        try await keychainManager.save(tokens.refreshToken, for: TokenStorageKey.refreshToken.rawValue)
    }

    func loadTokens() async throws -> AuthTokens? {
        guard
            let accessToken = try await keychainManager.loadValue(for: TokenStorageKey.accessToken.rawValue),
            let refreshToken = try await keychainManager.loadValue(for: TokenStorageKey.refreshToken.rawValue)
        else {
            return nil
        }

        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    func clear() async throws {
        try await keychainManager.deleteValue(for: TokenStorageKey.accessToken.rawValue)
        try await keychainManager.deleteValue(for: TokenStorageKey.refreshToken.rawValue)
    }
}
