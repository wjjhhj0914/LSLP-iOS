//
//  LoginContainer.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Combine
import Foundation

@MainActor
final class LoginContainer: ObservableObject {
    @Published private(set) var state = LoginState()

    private let authService: any AuthServicing

    init(authService: (any AuthServicing)? = nil) {
        self.authService = authService ?? AuthService(
            session: .shared,
            tokenStore: InMemoryTokenStore()
        )
    }

    func send(_ intent: LoginIntent) {
        switch intent {
        case let .emailChanged(email):
            state.email = email

        case let .passwordChanged(password):
            state.password = password

        case .loginButtonTapped:
            Task {
                await login()
            }

        case .errorDismissed:
            state.errorMessage = nil
        }
    }

    private func login() async {
        guard state.canSubmit else { return }

        state.isLoading = true
        state.errorMessage = nil

        do {
            let response = try await authService.login(
                email: state.email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: state.password
            )
            state.loggedInUser = response
        } catch {
            state.errorMessage = error.localizedDescription
        }

        state.isLoading = false
    }
}
