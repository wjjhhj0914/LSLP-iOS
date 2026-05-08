//
//  ChatNotificationStore.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Combine
import Foundation

struct ChatNotificationItem: Identifiable, Equatable {
    let id: String
    let roomID: String
    let roomTitle: String
    let senderNick: String
    let previewText: String
    let createdAt: Date
    var isRead: Bool

    init(
        message: ChatMessage,
        roomTitle: String,
        isRead: Bool = false
    ) {
        id = message.chatID
        roomID = message.roomID
        self.roomTitle = roomTitle
        senderNick = message.sender.nick
        previewText = message.content.isEmpty ? "첨부 파일 \(message.files.count)개" : message.content
        createdAt = message.sentAtDate ?? .now
        self.isRead = isRead
    }
}

@MainActor
final class ChatNotificationStore: ObservableObject {
    static let shared = ChatNotificationStore()

    @Published private(set) var items: [ChatNotificationItem] = []

    var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    func seed(from rooms: [ChatRoom], currentUserID: String) {
        for room in rooms {
            guard let lastChat = room.lastChat, lastChat.sender.userID != currentUserID else { continue }
            upsert(ChatNotificationItem(message: lastChat, roomTitle: room.displayTitle(currentUserID: currentUserID), isRead: false))
        }
    }

    func record(message: ChatMessage, roomTitle: String, isRead: Bool = false) {
        upsert(ChatNotificationItem(message: message, roomTitle: roomTitle, isRead: isRead))
    }

    func markRead(roomID: String) {
        items = items.map { item in
            guard item.roomID == roomID else { return item }
            var copy = item
            copy.isRead = true
            return copy
        }
    }

    func markAllRead() {
        items = items.map { item in
            var copy = item
            copy.isRead = true
            return copy
        }
    }

    private func upsert(_ item: ChatNotificationItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }

        items.sort { $0.createdAt > $1.createdAt }
    }
}
