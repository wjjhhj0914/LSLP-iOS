//
//  CommunityService.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Foundation

protocol CommunityServicing: Sendable {
    nonisolated func fetchGeolocationPosts(
        request: CommunityPostListRequest,
        accessToken: String
    ) async throws -> CommunityPostListResponse

    nonisolated func uploadFiles(
        items: [CommunityMediaUploadItem],
        accessToken: String
    ) async throws -> CommunityUploadFilesResponse

    nonisolated func createPost(
        draft: CommunityCreatePostRequest,
        accessToken: String
    ) async throws -> CommunityCreatedPostResponse

    nonisolated func createComment(
        postID: String,
        content: String,
        parentCommentID: String?,
        accessToken: String
    ) async throws -> CommunityComment

    nonisolated func updateComment(
        postID: String,
        commentID: String,
        content: String,
        accessToken: String
    ) async throws -> CommunityComment

    nonisolated func deleteComment(
        postID: String,
        commentID: String,
        accessToken: String
    ) async throws
}

struct CommunityService: CommunityServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchGeolocationPosts(
        request: CommunityPostListRequest,
        accessToken: String
    ) async throws -> CommunityPostListResponse {
        let urlRequest = try await makeRequest(request: request, accessToken: accessToken)
        logRequest(urlRequest)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logTransportError(error, request: urlRequest)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CommunityPostListResponse.self, from: data)
            }
        } catch {
            throw CommunityServiceError.decodingFailed(error)
        }
    }

    nonisolated func uploadFiles(
        items: [CommunityMediaUploadItem],
        accessToken: String
    ) async throws -> CommunityUploadFilesResponse {
        let request = try await makeMultipartRequest(
            path: "v1/posts/files",
            items: items,
            accessToken: accessToken
        )
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CommunityUploadFilesResponse.self, from: data)
            }
        } catch {
            throw CommunityServiceError.decodingFailed(error)
        }
    }

    nonisolated func createPost(
        draft: CommunityCreatePostRequest,
        accessToken: String
    ) async throws -> CommunityCreatedPostResponse {
        let request = try await makeJSONRequest(
            path: "v1/posts",
            method: "POST",
            accessToken: accessToken,
            body: draft
        )
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CommunityCreatedPostResponse.self, from: data)
            }
        } catch {
            let fallbackBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
            print(
                """
                [COMMUNITY CREATE RESPONSE DECODE FALLBACK]
                Body: \(fallbackBody)
                Error: \(error.localizedDescription)
                """
            )
            return CommunityCreatedPostResponse(postID: nil)
        }
    }

    nonisolated func createComment(
        postID: String,
        content: String,
        parentCommentID: String?,
        accessToken: String
    ) async throws -> CommunityComment {
        let request = try await makeJSONRequest(
            path: "v1/posts/\(postID)/comments",
            method: "POST",
            accessToken: accessToken,
            body: CommunityCommentCreateRequest(content: content, parentCommentID: parentCommentID)
        )
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CommunityComment.self, from: data)
            }
        } catch {
            throw CommunityServiceError.decodingFailed(error)
        }
    }

    nonisolated func updateComment(
        postID: String,
        commentID: String,
        content: String,
        accessToken: String
    ) async throws -> CommunityComment {
        let request = try await makeJSONRequest(
            path: "v1/posts/\(postID)/comments/\(commentID)",
            method: "PUT",
            accessToken: accessToken,
            body: CommunityCommentUpdateRequest(content: content)
        )
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)

        do {
            return try await MainActor.run {
                try JSONDecoder().decode(CommunityComment.self, from: data)
            }
        } catch {
            throw CommunityServiceError.decodingFailed(error)
        }
    }

    nonisolated func deleteComment(
        postID: String,
        commentID: String,
        accessToken: String
    ) async throws {
        let request = try await makeSimpleRequest(
            path: "v1/posts/\(postID)/comments/\(commentID)",
            method: "DELETE",
            accessToken: accessToken
        )
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request)
            throw error
        }

        logResponse(response, data: data)
        try validate(response: response, data: data)
    }

    private nonisolated func makeRequest(
        request: CommunityPostListRequest,
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
            let endpointURL = URL(string: "v1/posts/geolocation", relativeTo: baseURL)?.absoluteURL,
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: true)
        else {
            throw CommunityServiceError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "longitude", value: String(request.longitude)),
            URLQueryItem(name: "latitude", value: String(request.latitude)),
            URLQueryItem(name: "limit", value: String(request.limit))
        ]

        if let nextCursor = request.nextCursor, !nextCursor.isEmpty {
            queryItems.append(URLQueryItem(name: "next", value: nextCursor))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw CommunityServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        urlRequest.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        urlRequest.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return urlRequest
    }

    private nonisolated func makeJSONRequest(
        path: String,
        method: String,
        accessToken: String,
        body: some Encodable
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
            throw CommunityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        let encodedBody = try encoder.encode(body)
        request.httpBody = encodedBody
        return request
    }

    private nonisolated func makeSimpleRequest(
        path: String,
        method: String,
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
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw CommunityServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        return request
    }

    private nonisolated func makeMultipartRequest(
        path: String,
        items: [CommunityMediaUploadItem],
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
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw CommunityServiceError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for item in items {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"files\"; filename=\"\(item.fileName)\"\r\n".utf8))
            body.append(Data("Content-Type: \(item.mimeType)\r\n\r\n".utf8))
            body.append(item.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
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

        let bodyDescription: String
        if
            let httpBody = request.httpBody,
            let contentType = request.value(forHTTPHeaderField: "Content-Type"),
            contentType.contains("application/json")
        {
            bodyDescription = String(data: httpBody, encoding: .utf8) ?? "Unable to decode request body"
        } else {
            bodyDescription = "nil"
        }

        print(
            """
            [COMMUNITY REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            Body: \(bodyDescription)
            """
        )
    }

    private nonisolated func logResponse(_ response: URLResponse, data: Data) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"

        print(
            """
            [COMMUNITY RESPONSE]
            Status: \(statusCode)
            Body: \(responseBody)
            """
        )
    }

    private nonisolated func logTransportError(_ error: Error, request: URLRequest) {
        let nsError = error as NSError

        print(
            """
            [COMMUNITY TRANSPORT ERROR]
            URL: \(request.url?.absoluteString ?? "nil")
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            Description: \(nsError.localizedDescription)
            UserInfo: \(nsError.userInfo)
            """
        )
    }

    private nonisolated func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommunityServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw CommunityServiceError.unauthorized
        case 419:
            throw CommunityServiceError.accessTokenExpired
        default:
            throw CommunityServiceError.httpStatus(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}

enum CommunityServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case invalidFileType
    case fileTooLarge
    case tooManyFiles
    case emptyMedia
    case emptyContent
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "커뮤니티 요청 URL이 올바르지 않습니다."
        case .invalidResponse:
            return "커뮤니티 응답이 유효하지 않습니다."
        case .unauthorized:
            return "인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired:
            return "액세스 토큰이 만료되었습니다."
        case .invalidFileType:
            return "지원하지 않는 파일 형식이 포함되어 있습니다."
        case .fileTooLarge:
            return "각 파일은 5MB 이하만 업로드할 수 있습니다."
        case .tooManyFiles:
            return "파일은 최대 5개까지 업로드할 수 있습니다."
        case .emptyMedia:
            return "최소 1개의 이미지 또는 영상을 선택해주세요."
        case .emptyContent:
            return "제목, 본문, 카테고리를 모두 입력해주세요."
        case let .httpStatus(statusCode, message):
            return "커뮤니티 요청이 실패했습니다. (\(statusCode)) \(message ?? "")"
        case let .decodingFailed(error):
            return "커뮤니티 응답 디코딩에 실패했습니다: \(error.localizedDescription)"
        }
    }
}
