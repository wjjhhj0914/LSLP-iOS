//
//  LoginState.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct LoginState {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var loggedInUser: LoginResponse?

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !isLoading
    }
}
