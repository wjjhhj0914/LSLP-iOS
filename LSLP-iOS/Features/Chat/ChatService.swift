//
//  ChatService.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Foundation

protocol ChatServicing: Sendable {
    nonisolated func fetchChatRooms(
        accessToken: String
    ) async throws -> [ChatRoom]

    nonisolated func createOrFetchRoom(
        targetUserID: String,
        accessToken: String
    ) async throws -> ChatRoom

    nonisolated func fetchChatHistory(
        roomID: String,
        cursor: String?,
        accessToken: String
    ) async throws -> [ChatMessage]

    nonisolated func sendMessage(
        roomID: String,
        content: String,
        files: [String],
        accessToken: String
    ) async throws -> ChatMessage
}

struct ChatService: ChatServicing {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchChatRooms(
        accessToken: String
    ) async throws -> [ChatRoom] {
        let request = try await makeSimpleRequest(
            path: "v1/chats",
            method: "GET",
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
                let rooms = try JSONDecoder().decode(ChatRoomListResponse.self, from: data).data
                return rooms.sorted {
                    ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast)
                }
            }
        } catch {
            throw ChatServiceError.decodingFailed(error)
        }
    }

    nonisolated func createOrFetchRoom(
        targetUserID: String,
        accessToken: String
    ) async throws -> ChatRoom {
        let request = try await makeJSONRequest(
            path: "v1/chats",
            method: "POST",
            accessToken: accessToken,
            body: ChatRoomCreateRequest(targetUserID: targetUserID)
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
                try JSONDecoder().decode(ChatRoom.self, from: data)
            }
        } catch {
            throw ChatServiceError.decodingFailed(error)
        }
    }

    nonisolated func fetchChatHistory(
        roomID: String,
        cursor: String? = nil,
        accessToken: String
    ) async throws -> [ChatMessage] {
        var path = "v1/chats/\(roomID)"
        if let cursor,
           let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?cursor_date=\(encoded)"
        }
        let request = try await makeSimpleRequest(
            path: path,
            method: "GET",
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
                try JSONDecoder().decode(ChatHistoryResponse.self, from: data).messages
            }
        } catch {
            throw ChatServiceError.decodingFailed(error)
        }
    }

    nonisolated func sendMessage(
        roomID: String,
        content: String,
        files: [String] = [],
        accessToken: String
    ) async throws -> ChatMessage {
        let request = try await makeJSONRequest(
            path: "v1/chats/\(roomID)",
            method: "POST",
            accessToken: accessToken,
            body: ChatSendRequest(content: content, files: files)
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
                if let direct = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                    return direct
                }

                let wrapped = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if
                    let nested = wrapped?["data"] as? [String: Any],
                    let nestedData = try? JSONSerialization.data(withJSONObject: nested)
                {
                    return try JSONDecoder().decode(ChatMessage.self, from: nestedData)
                }

                throw ChatServiceError.decodingFailed(
                    NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "메시지 응답 구조를 해석할 수 없습니다."])
                )
            }
        } catch let error as ChatServiceError {
            throw error
        } catch {
            throw ChatServiceError.decodingFailed(error)
        }
    }

    private nonisolated func makeJSONRequest(
        path: String,
        method: String,
        accessToken: String,
        body: some Encodable
    ) async throws -> URLRequest {
        let environment = await MainActor.run {
            (baseURL: APIKey.BASE_URL, sesacKey: APIKey.SESAC_KEY)
        }

        guard
            let baseURL = URL(string: environment.baseURL),
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private nonisolated func makeSimpleRequest(
        path: String,
        method: String,
        accessToken: String
    ) async throws -> URLRequest {
        let environment = await MainActor.run {
            (baseURL: APIKey.BASE_URL, sesacKey: APIKey.SESAC_KEY)
        }

        guard
            let baseURL = URL(string: environment.baseURL),
            let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(environment.sesacKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
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
            [CHAT REQUEST]
            URL: \(request.url?.absoluteString ?? "nil")
            Method: \(request.httpMethod ?? "nil")
            Headers: \(headers)
            Body: \(bodyDescription)
            """
        )
    }

    private nonisolated func logResponse(_ response: URLResponse, data: Data) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
        print(
            """
            [CHAT RESPONSE]
            Status: \(statusCode)
            Body: \(body)
            """
        )
    }

    private nonisolated func logTransportError(_ error: Error, request: URLRequest) {
        let nsError = error as NSError
        print(
            """
            [CHAT TRANSPORT ERROR]
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
            throw ChatServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw ChatServiceError.unauthorized
        case 419:
            throw ChatServiceError.accessTokenExpired
        default:
            throw ChatServiceError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
    }
}

enum ChatServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case accessTokenExpired
    case httpStatus(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "채팅 요청 URL이 올바르지 않습니다."
        case .invalidResponse:
            return "채팅 응답이 유효하지 않습니다."
        case .unauthorized:
            return "채팅 인증이 만료되었습니다. 다시 로그인해주세요."
        case .accessTokenExpired:
            return "채팅 액세스 토큰이 만료되었습니다."
        case let .httpStatus(code, message):
            return "채팅 요청이 실패했습니다. (\(code)) \(message ?? "")"
        case let .decodingFailed(error):
            return "채팅 응답 디코딩에 실패했습니다: \(error.localizedDescription)"
        }
    }
}
