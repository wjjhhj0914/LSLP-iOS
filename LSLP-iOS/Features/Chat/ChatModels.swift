//
//  ChatModels.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Foundation

struct ChatRoomCreateRequest: Encodable, Sendable {
    let targetUserID: String

    enum CodingKeys: String, CodingKey {
        case opponentID = "opponent_id"
        case participantID = "participant_id"
        case userID = "user_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetUserID, forKey: .opponentID)
        try container.encode(targetUserID, forKey: .participantID)
        try container.encode(targetUserID, forKey: .userID)
    }
}

struct ChatSendRequest: Encodable, Sendable {
    let content: String
    let files: [String]

    init(content: String, files: [String] = []) {
        self.content = content
        self.files = files
    }
}

struct ChatParticipant: Codable, Identifiable, Sendable, Equatable {
    let userID: String
    let nick: String
    let profileImage: String

    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case profileImage
    }

    init(userID: String, nick: String, profileImage: String) {
        self.userID = userID
        self.nick = nick
        self.profileImage = profileImage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID) ?? ""
        nick = try container.decodeIfPresent(String.self, forKey: .nick) ?? "알 수 없음"
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage) ?? ""
    }
}

struct ChatMessage: Codable, Identifiable, Sendable, Equatable {
    let chatID: String
    let roomID: String
    let content: String
    let createdAt: String?
    let updatedAt: String?
    let sender: ChatParticipant
    let files: [String]

    var id: String { chatID }

    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case roomID = "room_id"
        case content
        case createdAt
        case updatedAt
        case sender
        case files
    }

    init(
        chatID: String,
        roomID: String,
        content: String,
        createdAt: String?,
        updatedAt: String?,
        sender: ChatParticipant,
        files: [String]
    ) {
        self.chatID = chatID
        self.roomID = roomID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sender = sender
        self.files = files
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chatID = try container.decode(String.self, forKey: .chatID)
        roomID = try container.decodeIfPresent(String.self, forKey: .roomID) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        sender = try container.decodeIfPresent(ChatParticipant.self, forKey: .sender)
            ?? ChatParticipant(userID: "", nick: "알 수 없음", profileImage: "")
        files = try container.decodeIfPresent([String].self, forKey: .files) ?? []
    }
}

struct ChatRoom: Decodable, Identifiable, Sendable, Equatable {
    let roomID: String
    let createdAt: String?
    let updatedAt: String?
    let participants: [ChatParticipant]
    let lastChat: ChatMessage?
    let messages: [ChatMessage]

    var id: String { roomID }

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case createdAt
        case updatedAt
        case participants
        case lastChat
        case chats
        case chatList = "chat_list"
        case messages
        case data
    }

    init(
        roomID: String,
        createdAt: String?,
        updatedAt: String?,
        participants: [ChatParticipant],
        lastChat: ChatMessage?,
        messages: [ChatMessage]
    ) {
        self.roomID = roomID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.participants = participants
        self.lastChat = lastChat
        self.messages = messages
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decode(String.self, forKey: .roomID)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        participants = try container.decodeIfPresent([ChatParticipant].self, forKey: .participants) ?? []
        lastChat = try container.decodeIfPresent(ChatMessage.self, forKey: .lastChat)
        messages =
            try container.decodeIfPresent([ChatMessage].self, forKey: .messages)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .chats)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .chatList)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .data)
            ?? []
    }
}

struct ChatRoomListResponse: Decodable, Sendable {
    let data: [ChatRoom]
}

struct ChatHistoryResponse: Decodable, Sendable {
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case data
        case messages
        case chats
        case chatList = "chat_list"
        case lastChat
    }

    init(messages: [ChatMessage]) {
        self.messages = messages
    }

    init(from decoder: any Decoder) throws {
        if let singleMessage = try? ChatMessage(from: decoder) {
            self.messages = [singleMessage]
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        messages =
            try container.decodeIfPresent([ChatMessage].self, forKey: .messages)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .chats)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .chatList)
            ?? container.decodeIfPresent([ChatMessage].self, forKey: .data)
            ?? [container.decodeIfPresent(ChatMessage.self, forKey: .lastChat)].compactMap { $0 }
    }
}

struct ChatSocketNamespace: Sendable, Equatable {
    let roomID: String

    var namespacePath: String {
        "/chats-\(roomID)"
    }

    var connectionURL: URL? {
        URL(string: "http://estate.sesac.kr:41449")
    }
}

extension ChatMessage {
    var sentAtDate: Date? {
        guard let createdAt else { return nil }
        return DateFormatter.chatISO8601.date(from: createdAt) ?? DateFormatter.chatISO8601WithoutFractional.date(from: createdAt)
    }
}

extension ChatRoom {
    var updatedAtDate: Date? {
        guard let updatedAt else { return nil }
        return DateFormatter.chatISO8601.date(from: updatedAt) ?? DateFormatter.chatISO8601WithoutFractional.date(from: updatedAt)
    }

    func displayTitle(currentUserID: String) -> String {
        if let other = participants.first(where: { $0.userID != currentUserID && !$0.nick.isEmpty }) {
            return other.nick
        }
        return participants.first(where: { !$0.nick.isEmpty })?.nick ?? "채팅"
    }

    var lastActivityDate: Date? {
        lastChat?.sentAtDate ?? updatedAtDate
    }
}

struct ChatUserCandidate: Identifiable, Equatable, Sendable {
    let userID: String
    let nick: String
    let profileImage: String
    let subtitle: String

    var id: String { userID }
}

extension DateFormatter {
    static let chatISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let chatISO8601WithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let chatTodayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    static let chatPastDayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d a h:mm"
        return formatter
    }()
}

extension String {
    var decodedJWTUserID: String? {
        let segments = split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = 4 - payload.count % 4
        if paddingLength < 4 {
            payload += String(repeating: "=", count: paddingLength)
        }

        guard
            let data = Data(base64Encoded: payload),
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return jsonObject["user_id"] as? String
            ?? jsonObject["userId"] as? String
            ?? jsonObject["id"] as? String
            ?? jsonObject["sub"] as? String
    }
}
