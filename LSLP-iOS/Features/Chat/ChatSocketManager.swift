//
//  ChatSocketManager.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Combine
import Foundation
import RxRelay
import SocketIO

@MainActor
final class ChatSocketManager: ObservableObject {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case disconnected
        case failed(String)
    }

    @Published private(set) var state: ConnectionState = .idle

    let namespace: ChatSocketNamespace
    let incomingMessageRelay = PublishRelay<ChatMessage>()

    private var manager: SocketManager?
    private var socket: SocketIOClient?

    init(roomID: String) {
        self.namespace = ChatSocketNamespace(roomID: roomID)
    }

    func connect(accessToken: String) {
        if case .connected = state {
            return
        }

        disconnect()
        state = .connecting

        guard let baseURL = namespace.connectionURL else {
            state = .failed("소켓 연결 URL이 올바르지 않습니다.")
            return
        }

        let configuration: SocketIOClientConfiguration = [
            .compress,
            .log(false),
            .reconnects(true),
            .reconnectWait(2),
            .reconnectWaitMax(8),
            .path("/socket.io/"),
            .extraHeaders([
                "SeSACKey": APIKey.SESAC_KEY,
                "Authorization": "Bearer \(accessToken)"
            ])
        ]

        let manager = SocketManager(socketURL: baseURL, config: configuration)
        let socket = manager.socket(forNamespace: namespace.namespacePath)

        bind(socket: socket)

        self.manager = manager
        self.socket = socket

        print(
            """
            [CHAT SOCKET PREPARED]
            Namespace: \(namespace.namespacePath)
            URL: \(baseURL.absoluteString)
            Path: /socket.io/
            Token: \(accessToken.maskedToken)
            """
        )

        socket.connect()
    }

    func disconnect() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
        state = .disconnected
    }

    private func bind(socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in
                self.state = .connected
                print("[CHAT SOCKET CONNECTED] Namespace: \(self.namespace.namespacePath)")
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self else { return }
            Task { @MainActor in
                self.state = .disconnected
                if let reason = data.first as? String {
                    print("[CHAT SOCKET DISCONNECTED] \(reason)")
                }
            }
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            guard let self else { return }
            Task { @MainActor in
                let message = self.describe(eventData: data) ?? "소켓 연결 중 오류가 발생했습니다."
                self.state = .failed(message)
                print(
                    """
                    [CHAT SOCKET ERROR]
                    Message: \(message)
                    Raw: \(data)
                    """
                )
            }
        }

        socket.on(clientEvent: .statusChange) { _, items in
            print("[CHAT SOCKET STATUS] \(items)")
        }

        socket.on(clientEvent: .reconnectAttempt) { data, _ in
            print("[CHAT SOCKET RECONNECT ATTEMPT] \(data)")
        }

        socket.on("chat") { [weak self] data, _ in
            guard let self else { return }
            guard let message = self.decodeChatMessage(from: data) else {
                print("[CHAT SOCKET ERROR] chat 이벤트 디코딩 실패: \(data)")
                return
            }

            Task { @MainActor [weak self] in
                self?.incomingMessageRelay.accept(message)
            }
        }
    }

    private func decodeChatMessage(from data: [Any]) -> ChatMessage? {
        guard let payload = data.first else { return nil }

        if let dictionary = payload as? [String: Any] {
            return decode(dictionary: dictionary)
        }

        if
            let array = payload as? [[String: Any]],
            let first = array.first
        {
            return decode(dictionary: first)
        }

        return nil
    }

    private func decode(dictionary: [String: Any]) -> ChatMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return nil
        }

        return try? JSONDecoder().decode(ChatMessage.self, from: data)
    }

    private func describe(eventData: [Any]) -> String? {
        if let string = eventData.first as? String, !string.isEmpty {
            return string
        }

        if
            let dictionary = eventData.first as? [String: Any],
            let message = dictionary["message"] as? String
        {
            return message
        }

        if let first = eventData.first {
            return String(describing: first)
        }

        return nil
    }
}
