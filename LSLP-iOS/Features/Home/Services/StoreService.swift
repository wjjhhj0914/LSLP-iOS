//
//  StoreService.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import Foundation

protocol StoreServicing: Sendable {
    nonisolated func fetchStores(
        request: StoreListRequest,
        accessToken: String
    ) async throws -> StoreListResponse
    nonisolated func fetchPopularStores(
        category: String?,
        accessToken: String
    ) async throws -> [StoreSummary]
}

struct StoreService: StoreServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchStores(
        request: StoreListRequest,
        accessToken: String
    ) async throws -> StoreListResponse {
        let urlRequest = try await makeStoreRequest(
            path: "v1/stores",
            queryItems: makeStoreQueryItems(request: request),
            accessToken: accessToken
        )

        logRequest(urlRequest)

        let (data, response) = try await session.data(for: urlRequest)
        logResponse(response, data: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw StoreServiceError.unauthorized
        case 419:
            throw StoreServiceError.accessTokenExpired
        default:
            let message = String(data: data, encoding: .utf8)
            throw StoreServiceError.httpStatus(httpResponse.statusCode, message)
        }

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(StoreListResponse.self, from: data)
            }
        } catch {
            throw StoreServiceError.decodingFailed(error)
        }
    }

    nonisolated func fetchPopularStores(
        category: String?,
        accessToken: String
    ) async throws -> [StoreSummary] {
        var queryItems: [URLQueryItem] = []

        if let category, !category.isEmpty {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }

        let urlRequest = try await makeStoreRequest(
            path: "v1/stores/popular-stores",
            queryItems: queryItems,
            accessToken: accessToken
        )

        logRequest(urlRequest)

        let (data, response) = try await session.data(for: urlRequest)
        logResponse(response, data: data)

        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode([StoreSummary].self, from: data)
            }
        } catch {
            throw StoreServiceError.decodingFailed(error)
        }
    }

    private nonisolated func makeStoreQueryItems(
        request: StoreListRequest
    ) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "longitude", value: String(request.longitude)),
            URLQueryItem(name: "latitude", value: String(request.latitude)),
            URLQueryItem(name: "maxDistance", value: String(request.maxDistance)),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "order_by", value: request.orderBy)
        ]

        if let category = request.category, !category.isEmpty {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }

        if let next = request.next, !next.isEmpty {
            queryItems.append(URLQueryItem(name: "next", value: next))
        }

        return queryItems
    }

    private nonisolated func makeStoreRequest(
        path: String,
        queryItems: [URLQueryItem],
        accessToken: String
    ) async throws -> URLRequest {
        let environment = await MainActor.run {
            (
                baseURL: APIKey.BASE_URL,
                sesacKey: APIKey.SESAC_KEY
            )
        }

        guard
            let baseURL = URL(string: environment.baseURL),
            let endpointURL = URL(string: path, relativeTo: baseURL)?.absoluteURL,
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: true)
        else {
            throw StoreServiceError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw StoreServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        urlRequest.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        urlRequest.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return urlRequest
    }

    private nonisolated func logRequest(_ request: URLRequest) {
        let headers = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) { partialResult, item in
            switch item.key {
            case "SeSACKey":
                partialResult[item.key] = item.value.maskedToken
            case "Authorization":
                partialResult[item.key] = item.value.maskedToken
            default:
                partialResult[item.key] = item.value
            }
        }

        print(
            """
            [STORES REQUEST]
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
            [STORES RESPONSE]
            Status: \(statusCode)
            Body: \(responseBody)
            """
        )
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw StoreServiceError.unauthorized
        case 419:
            throw StoreServiceError.accessTokenExpired
        default:
            let message = String(data: data, encoding: .utf8)
            throw StoreServiceError.httpStatus(httpResponse.statusCode, message)
        }
    }
}

enum StoreServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The store request URL is invalid."
        case .invalidResponse:
            return "The store response was not a valid HTTP response."
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired:
            return "액세스 토큰이 만료되었습니다."
        case let .httpStatus(statusCode, message):
            return "Store request failed with status \(statusCode). \(message ?? "")"
        case let .decodingFailed(error):
            return "Failed to decode store response: \(error.localizedDescription)"
        }
    }
}
