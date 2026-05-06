//
//  StoreDetailService.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Foundation

protocol StoreDetailServicing: Sendable {
    nonisolated func fetchStoreDetail(storeID: String, accessToken: String) async throws -> StoreDetail
    nonisolated func toggleLike(storeID: String, accessToken: String) async throws -> StoreLikeResponse
    nonisolated func createOrder(payload: CreateOrderRequest, accessToken: String) async throws -> CreatedOrder
    nonisolated func validatePayment(
        impUID: String,
        merchantUID: String,
        accessToken: String
    ) async throws -> PaymentValidationResponse
}

struct StoreDetailService: StoreDetailServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchStoreDetail(storeID: String, accessToken: String) async throws -> StoreDetail {
        let request = try await makeRequest(
            path: "v1/stores/\(storeID)",
            method: "GET",
            accessToken: accessToken
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(StoreDetail.self, from: data)
            }
        } catch {
            throw StoreDetailServiceError.decodingFailed(error)
        }
    }

    nonisolated func toggleLike(storeID: String, accessToken: String) async throws -> StoreLikeResponse {
        let request = try await makeRequest(
            path: "v1/stores/\(storeID)/like",
            method: "POST",
            accessToken: accessToken
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(StoreLikeResponse.self, from: data)
            }
        } catch {
            throw StoreDetailServiceError.decodingFailed(error)
        }
    }

    nonisolated func createOrder(payload: CreateOrderRequest, accessToken: String) async throws -> CreatedOrder {
        let request = try await makeRequest(
            path: "v1/orders",
            method: "POST",
            accessToken: accessToken,
            body: payload
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CreatedOrder.self, from: data)
            }
        } catch {
            throw StoreDetailServiceError.decodingFailed(error)
        }
    }

    nonisolated func validatePayment(
        impUID: String,
        merchantUID: String,
        accessToken: String
    ) async throws -> PaymentValidationResponse {
        let request = try await makeRequest(
            path: "v1/payments/validation",
            method: "POST",
            accessToken: accessToken,
            body: PaymentValidationRequest(impUID: impUID)
        )

        print(
            """
            [PAYMENT VALIDATION REQUEST]
            imp_uid: \(impUID)
            merchant_uid: \(merchantUID)
            url: \(request.url?.absoluteString ?? "nil")
            """
        )

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
        print(
            """
            [PAYMENT VALIDATION RESPONSE]
            status: \(statusCode)
            body: \(responseBody)
            """
        )
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(PaymentValidationResponse.self, from: data)
            }
        } catch {
            throw StoreDetailServiceError.decodingFailed(error)
        }
    }

    private nonisolated func makeRequest(
        path: String,
        method: String,
        accessToken: String,
        body: (any Encodable)? = nil
    ) async throws -> URLRequest {
        let environment = await MainActor.run {
            (
                baseURL: APIKey.BASE_URL,
                sesacKey: APIKey.SESAC_KEY
            )
        }

        guard
            let baseURL = URL(string: environment.baseURL),
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw StoreDetailServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return request
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreDetailServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw StoreDetailServiceError.unauthorized
        case 419:
            throw StoreDetailServiceError.accessTokenExpired
        default:
            throw StoreDetailServiceError.httpStatus(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}

enum StoreDetailServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case emptyOrder
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "상세 가게 요청 URL이 올바르지 않습니다."
        case .invalidResponse:
            return "상세 가게 응답이 유효하지 않습니다."
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired:
            return "액세스 토큰이 만료되었습니다."
        case .emptyOrder:
            return "선택된 메뉴가 없습니다."
        case let .httpStatus(statusCode, message):
            return "상세 가게 요청이 실패했습니다. (\(statusCode)) \(message ?? "")"
        case let .decodingFailed(error):
            return "상세 가게 응답 디코딩에 실패했습니다: \(error.localizedDescription)"
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        encodeBlock = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}
