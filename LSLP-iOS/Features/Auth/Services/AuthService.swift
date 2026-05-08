//
//  AuthService.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Foundation

protocol AuthServicing: Sendable {
    nonisolated func login(email: String, password: String) async throws -> LoginResponse
    nonisolated func refresh(accessToken: String?, refreshToken: String) async throws -> RefreshTokenResponse
}

struct AuthService: AuthServicing {
    private let session: URLSession
    private let tokenStore: any TokenStore

    nonisolated init(
        session: URLSession = .shared,
        tokenStore: any TokenStore
    ) {
        self.session = session
        self.tokenStore = tokenStore
    }

    nonisolated func login(email: String, password: String) async throws -> LoginResponse {
        let fcmToken = UserDefaults.standard.string(forKey: "fcmToken")
        let request = try await makeLoginRequest(
            body: LoginRequest(email: email, password: password, deviceToken: fcmToken)
        )

        logRequest(request, email: email)

        let (data, response) = try await session.data(for: request)
        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            let decodedResponse = try await MainActor.run {
                try JSONDecoder().decode(LoginResponse.self, from: data)
            }
            try await tokenStore.save(decodedResponse.tokens)

            print("Login succeeded")
            print(decodedResponse)

            return decodedResponse
        } catch {
            throw AuthServiceError.decodingFailed(error)
        }
    }

    nonisolated func refresh(accessToken: String?, refreshToken: String) async throws -> RefreshTokenResponse {
        let request = try await makeRefreshRequest(accessToken: accessToken, refreshToken: refreshToken)

        logRefreshRequest(request)

        let (data, response) = try await session.data(for: request)
        logRefreshResponse(response, data: data)
        try validateRefresh(response: response, data: data)

        do {
            let decodedResponse = try await MainActor.run {
                try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            }
            try await tokenStore.save(decodedResponse.tokens)

            print("Refresh succeeded")
            return decodedResponse
        } catch {
            throw AuthServiceError.decodingFailed(error)
        }
    }

    private nonisolated func makeLoginRequest(body: LoginRequest) async throws -> URLRequest {
        let environment = await MainActor.run {
            (
                baseURL: APIKey.BASE_URL,
                sesacKey: APIKey.SESAC_KEY,
                path: AuthEndpoint.login.path
            )
        }

        guard let url = URL(string: environment.baseURL + environment.path) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.httpBody = try await MainActor.run {
            try JSONEncoder().encode(body)
        }
        request.timeoutInterval = 30
        return request
    }

    private nonisolated func makeRefreshRequest(
        accessToken: String?,
        refreshToken: String
    ) async throws -> URLRequest {
        let environment = await MainActor.run {
            (
                baseURL: APIKey.BASE_URL,
                sesacKey: APIKey.SESAC_KEY,
                path: AuthEndpoint.refresh.path
            )
        }

        guard let url = URL(string: environment.baseURL + environment.path) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(refreshToken, forHTTPHeaderField: "RefreshToken")

        if let accessToken, !accessToken.isEmpty {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = 30
        return request
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            throw AuthServiceError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private nonisolated func validateRefresh(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw AuthServiceError.invalidRefreshToken
        case 418:
            throw AuthServiceError.expiredRefreshToken
        default:
            let message = String(data: data, encoding: .utf8)
            throw AuthServiceError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private nonisolated func logRequest(_ request: URLRequest, email: String) {
        let headers = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) { partialResult, item in
            if item.key == "SeSACKey" {
                partialResult[item.key] = item.value.maskedToken
            } else {
                partialResult[item.key] = item.value
            }
        }

        print(
            """
            [LOGIN REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            Body: {\"email\":\"\(email)\",\"password\":\"********\"}
            """
        )
    }

    private nonisolated func logResponse(_ response: URLResponse, data: Data) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"

        print(
            """
            [LOGIN RESPONSE]
            Status: \(statusCode)
            Body: \(responseBody)
            """
        )
    }

    private nonisolated func logRefreshRequest(_ request: URLRequest) {
        let headers = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) { partialResult, item in
            switch item.key {
            case "SeSACKey", "RefreshToken", "Authorization":
                partialResult[item.key] = item.value.maskedToken
            default:
                partialResult[item.key] = item.value
            }
        }

        print(
            """
            [REFRESH REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            """
        )
    }

    private nonisolated func logRefreshResponse(_ response: URLResponse, data: Data) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"

        print(
            """
            [REFRESH RESPONSE]
            Status: \(statusCode)
            Body: \(responseBody)
            """
        )
    }
}

private enum AuthEndpoint {
    case login
    case refresh

    var path: String {
        switch self {
        case .login:
            return "/v1/users/login"
        case .refresh:
            return "/v1/auth/refresh"
        }
    }
}

enum AuthServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String?)
    case decodingFailed(Error)
    case invalidRefreshToken
    case expiredRefreshToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "BASE_URL or endpoint path is invalid."
        case .invalidResponse:
            return "The server response was not a valid HTTP response."
        case let .httpStatus(statusCode, message):
            return "Request failed with status \(statusCode). \(message ?? "")"
        case let .decodingFailed(error):
            return "Failed to decode login response: \(error.localizedDescription)"
        case .invalidRefreshToken:
            return "리프레시 토큰이 유효하지 않습니다."
        case .expiredRefreshToken:
            return "리프레시 토큰이 만료되었습니다. 다시 로그인해주세요."
        }
    }
}
