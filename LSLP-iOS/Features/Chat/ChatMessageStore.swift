//
//  ChatMessageStore.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Foundation

actor ChatMessageStore {
    static let shared = ChatMessageStore()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadMessages(roomID: String) -> [ChatMessage] {
        guard
            let url = messagesFileURL(roomID: roomID),
            let data = try? Data(contentsOf: url),
            let messages = try? decoder.decode([ChatMessage].self, from: data)
        else {
            return []
        }

        return deduplicated(messages)
    }

    @discardableResult
    func mergeMessages(_ incomingMessages: [ChatMessage], roomID: String) throws -> [ChatMessage] {
        let existingMessages = loadMessages(roomID: roomID)
        let mergedMessages = deduplicated(existingMessages + incomingMessages)
        try persist(messages: mergedMessages, roomID: roomID)
        return mergedMessages
    }

    func saveMessage(_ message: ChatMessage, roomID: String) throws -> SaveResult {
        let existingMessages = loadMessages(roomID: roomID)
        guard !existingMessages.contains(where: { $0.chatID == message.chatID }) else {
            return SaveResult(messages: existingMessages, inserted: false)
        }

        let mergedMessages = deduplicated(existingMessages + [message])
        try persist(messages: mergedMessages, roomID: roomID)
        return SaveResult(messages: mergedMessages, inserted: true)
    }

    private func persist(messages: [ChatMessage], roomID: String) throws {
        guard let url = messagesFileURL(roomID: roomID) else { return }
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(messages)
        try data.write(to: url, options: .atomic)
    }

    private func deduplicated(_ messages: [ChatMessage]) -> [ChatMessage] {
        var seenChatIDs = Set<String>()
        let uniqueMessages = messages.filter { message in
            guard !seenChatIDs.contains(message.chatID) else { return false }
            seenChatIDs.insert(message.chatID)
            return true
        }

        return uniqueMessages.sorted { lhs, rhs in
            guard
                let leftDate = lhs.sentAtDate,
                let rightDate = rhs.sentAtDate
            else {
                return lhs.chatID < rhs.chatID
            }
            return leftDate < rightDate
        }
    }

    private func messagesFileURL(roomID: String) -> URL? {
        guard let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("ChatMessages", isDirectory: true)
            .appendingPathComponent("\(roomID).json")
    }
}

struct SaveResult: Sendable {
    let messages: [ChatMessage]
    let inserted: Bool
}
