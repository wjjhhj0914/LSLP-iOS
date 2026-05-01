//
//  BannerService.swift
//  LSLP-iOS
//
//  Created by Codex on 4/29/26.
//

import Foundation

protocol BannerServicing: Sendable {
    nonisolated func fetchMainBanners(accessToken: String) async throws -> [MainBanner]
}

struct BannerService: BannerServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchMainBanners(accessToken: String) async throws -> [MainBanner] {
        let request = try await makeBannerRequest(accessToken: accessToken)

        logRequest(request)

        let (data, response) = try await session.data(for: request)
        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            let decodedResponse = try await MainActor.run {
                try JSONDecoder().decode(MainBannerResponse.self, from: data)
            }
            return decodedResponse.data
        } catch {
            throw BannerServiceError.decodingFailed(error)
        }
    }

    private nonisolated func makeBannerRequest(accessToken: String) async throws -> URLRequest {
        let environment = await MainActor.run {
            (
                baseURL: APIKey.BASE_URL,
                sesacKey: APIKey.SESAC_KEY
            )
        }

        guard
            let baseURL = URL(string: environment.baseURL),
            let endpointURL = URL(string: "v1/banners/main", relativeTo: baseURL)?.absoluteURL
        else {
            throw BannerServiceError.invalidURL
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return request
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BannerServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw BannerServiceError.unauthorized
        case 419:
            throw BannerServiceError.accessTokenExpired
        default:
            let message = String(data: data, encoding: .utf8)
            throw BannerServiceError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private nonisolated func logRequest(_ request: URLRequest) {
        let headers = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) { partialResult, item in
            switch item.key {
            case "SeSACKey", "Authorization":
                partialResult[item.key] = item.value.maskedToken
            default:
                partialResult[item.key] = item.value
            }
        }

        print(
            """
            [BANNERS REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            """
        )
    }

    private nonisolated func logResponse(_ response: URLResponse, data: Data) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"

        print(
            """
            [BANNERS RESPONSE]
            Status: \(statusCode)
            Body: \(responseBody)
            """
        )
    }
}

enum BannerServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The banner request URL is invalid."
        case .invalidResponse:
            return "The banner response was not a valid HTTP response."
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired:
            return "액세스 토큰이 만료되었습니다."
        case let .httpStatus(statusCode, message):
            return "Banner request failed with status \(statusCode). \(message ?? "")"
        case let .decodingFailed(error):
            return "Failed to decode banner response: \(error.localizedDescription)"
        }
    }
}
