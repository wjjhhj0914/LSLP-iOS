//
//  VideoService.swift
//  LSLP-iOS
//

import Foundation

protocol VideoServicing: Sendable {
    nonisolated func fetchVideos(
        nextCursor: String?,
        limit: Int,
        accessToken: String
    ) async throws -> VideoListResponse

    nonisolated func fetchStreamInfo(
        videoID: String,
        accessToken: String
    ) async throws -> VideoStreamResponse

    nonisolated func toggleLike(
        videoID: String,
        accessToken: String
    ) async throws -> VideoLikeResponse
}

struct VideoService: VideoServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    nonisolated func fetchVideos(
        nextCursor: String?,
        limit: Int,
        accessToken: String
    ) async throws -> VideoListResponse {
        let request = try await makeVideoListRequest(nextCursor: nextCursor, limit: limit, accessToken: accessToken)
        logRequest(request, tag: "VIDEO LIST")

        let (data, response) = try await performDataTask(request: request)
        logResponse(response, data: data, tag: "VIDEO LIST")
        try validate(response: response, data: data)

        return try decode(VideoListResponse.self, from: data)
    }

    nonisolated func fetchStreamInfo(
        videoID: String,
        accessToken: String
    ) async throws -> VideoStreamResponse {
        let request = try await makeSimpleRequest(
            path: "v1/videos/\(videoID)/stream",
            method: "GET",
            accessToken: accessToken
        )
        logRequest(request, tag: "VIDEO STREAM")

        let (data, response) = try await performDataTask(request: request)
        logResponse(response, data: data, tag: "VIDEO STREAM")
        try validate(response: response, data: data)

        return try decode(VideoStreamResponse.self, from: data)
    }

    nonisolated func toggleLike(
        videoID: String,
        accessToken: String
    ) async throws -> VideoLikeResponse {
        let request = try await makeSimpleRequest(
            path: "v1/videos/\(videoID)/like",
            method: "POST",
            accessToken: accessToken
        )
        logRequest(request, tag: "VIDEO LIKE")

        let (data, response) = try await performDataTask(request: request)
        logResponse(response, data: data, tag: "VIDEO LIKE")
        try validate(response: response, data: data)

        return try decode(VideoLikeResponse.self, from: data)
    }

    // MARK: - Request builders

    private nonisolated func makeVideoListRequest(
        nextCursor: String?,
        limit: Int,
        accessToken: String
    ) async throws -> URLRequest {
        let env = await MainActor.run { (baseURL: APIKey.BASE_URL, sesacKey: APIKey.SESAC_KEY) }

        guard
            let baseURL = URL(string: env.baseURL),
            let endpointURL = URL(string: "v1/videos", relativeTo: baseURL)?.absoluteURL,
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: true)
        else {
            throw VideoServiceError.invalidURL
        }

        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor = nextCursor, !cursor.isEmpty, cursor != "0" {
            queryItems.append(URLQueryItem(name: "next", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw VideoServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(env.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return request
    }

    private nonisolated func makeSimpleRequest(
        path: String,
        method: String,
        accessToken: String
    ) async throws -> URLRequest {
        let env = await MainActor.run { (baseURL: APIKey.BASE_URL, sesacKey: APIKey.SESAC_KEY) }

        guard
            let baseURL = URL(string: env.baseURL),
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw VideoServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(env.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Helpers

    private nonisolated func performDataTask(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            let nsError = error as NSError
            print(
                """
                [VIDEO TRANSPORT ERROR]
                URL: \(request.url?.absoluteString ?? "nil")
                Domain: \(nsError.domain) Code: \(nsError.code)
                Description: \(nsError.localizedDescription)
                """
            )
            throw error
        }
    }

    private nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print(
                """
                [VIDEO DECODE ERROR] \(T.self)
                Reason: \(error)
                Raw: \(String(data: data, encoding: .utf8) ?? "unreadable")
                """
            )
            throw VideoServiceError.decodingFailed(error)
        }
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw VideoServiceError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw VideoServiceError.unauthorized
        case 419:
            throw VideoServiceError.accessTokenExpired
        default:
            throw VideoServiceError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    private nonisolated func logRequest(_ request: URLRequest, tag: String) {
        let headers = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) { result, item in
            switch item.key {
            case "SeSACKey", "Authorization": result[item.key] = item.value.maskedToken
            default: result[item.key] = item.value
            }
        }
        print(
            """
            [\(tag) REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            """
        )
    }

    private nonisolated func logResponse(_ response: URLResponse, data: Data, tag: String) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print(
            """
            [\(tag) RESPONSE]
            Status: \(status)
            Body: \(body)
            """
        )
    }
}

// MARK: - Errors

enum VideoServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "비디오 요청 URL이 올바르지 않습니다."
        case .invalidResponse: return "비디오 응답이 유효하지 않습니다."
        case .unauthorized: return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired: return "액세스 토큰이 만료되었습니다."
        case let .httpStatus(code, msg): return "비디오 요청이 실패했습니다. (\(code)) \(msg ?? "")"
        case let .decodingFailed(error): return "비디오 응답 디코딩에 실패했습니다: \(error.localizedDescription)"
        }
    }
}
