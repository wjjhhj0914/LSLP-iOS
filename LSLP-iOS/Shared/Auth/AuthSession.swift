//
//  AuthSession.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import Combine
import Foundation

@MainActor
final class AuthSession: ObservableObject {
    enum State: Equatable {
        case loading
        case authenticated
        case unauthenticated
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var tokens: AuthTokens?

    var accessToken: String? {
        tokens?.accessToken
    }

    private let tokenStore: any TokenStore
    private let session: URLSession
    private var hasRestoredSession = false
    private var refreshTask: Task<AuthTokens, Error>?

    init(
        tokenStore: any TokenStore = KeychainTokenStore(keychainManager: KeychainManager()),
        session: URLSession = .shared
    ) {
        self.tokenStore = tokenStore
        self.session = session
    }

    func restoreSessionIfNeeded() async {
        guard !hasRestoredSession else { return }

        hasRestoredSession = true
        await restoreSession()
    }

    func restoreSession() async {
        state = .loading

        do {
            let storedTokens = try await tokenStore.loadTokens()
            tokens = storedTokens
            state = storedTokens == nil ? .unauthenticated : .authenticated
        } catch {
            tokens = nil
            state = .unauthenticated
            print("Failed to restore auth session: \(error.localizedDescription)")
        }
    }

    func makeAuthService() -> AuthService {
        AuthService(session: session, tokenStore: tokenStore)
    }

    func didLogin(with response: LoginResponse) {
        tokens = response.tokens
        state = .authenticated
        print("Auth session authenticated")
    }

    func resolveAccessToken() async throws -> String {
        if let currentAccessToken = tokens?.accessToken, !currentAccessToken.isEmpty {
            return currentAccessToken
        }

        if let storedTokens = try await tokenStore.loadTokens() {
            tokens = storedTokens
            state = .authenticated
            return storedTokens.accessToken
        }

        if let refreshedAccessToken = try await refreshAccessTokenIfPossible() {
            return refreshedAccessToken
        }

        throw AuthSessionError.missingTokens
    }

    func refreshAccessToken() async throws -> String {
        guard let refreshedAccessToken = try await refreshAccessTokenIfPossible() else {
            throw AuthSessionError.missingRefreshToken
        }

        return refreshedAccessToken
    }

    func logout() async {
        do {
            try await tokenStore.clear()
        } catch {
            print("Failed to clear tokens: \(error.localizedDescription)")
        }

        tokens = nil
        state = .unauthenticated
    }

    private func refreshAccessTokenIfPossible() async throws -> String? {
        if let refreshTask {
            let refreshedTokens = try await refreshTask.value
            tokens = refreshedTokens
            state = .authenticated
            return refreshedTokens.accessToken
        }

        guard let refreshToken = try await tokenStore.loadRefreshToken(), !refreshToken.isEmpty else {
            return nil
        }

        let storedAccessToken = try await tokenStore.loadAccessToken()
        let task = Task { [session, tokenStore] in
            let authService = AuthService(session: session, tokenStore: tokenStore)
            return try await authService.refresh(
                accessToken: storedAccessToken,
                refreshToken: refreshToken
            ).tokens
        }

        refreshTask = task

        do {
            let refreshedTokens = try await task.value
            tokens = refreshedTokens
            state = .authenticated
            refreshTask = nil
            return refreshedTokens.accessToken
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

enum AuthSessionError: LocalizedError {
    case missingTokens
    case missingRefreshToken

    var errorDescription: String? {
        switch self {
        case .missingTokens:
            return "저장된 인증 토큰이 없습니다."
        case .missingRefreshToken:
            return "리프레시 토큰이 없습니다."
        }
    }
}
