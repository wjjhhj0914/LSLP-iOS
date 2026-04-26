//
//  LoginModels.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable, Sendable, Equatable {
    let userID: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case accessToken
        case refreshToken
    }

    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

extension LoginResponse: CustomStringConvertible {
    var description: String {
        """
        LoginResponse(
          userID: \(userID),
          email: \(email),
          nick: \(nick),
          accessToken: \(accessToken.maskedToken),
          refreshToken: \(refreshToken.maskedToken)
        )
        """
    }
}

struct AuthTokens: Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
}

extension String {
    nonisolated var maskedToken: String {
        guard count > 10 else { return self }

        let prefix = self.prefix(4)
        let suffix = self.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
