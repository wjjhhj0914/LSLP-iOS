//
//  ChatViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Combine
import CoreGraphics
import Foundation
import RxRelay
import RxSwift

@MainActor
final class ChatViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var room: ChatRoom
    @Published private(set) var messages: [ChatMessage]
    @Published var draftText = ""
    @Published var inputHeight: CGFloat = 44
    @Published private(set) var isSending = false

    let socketManager: ChatSocketManager

    private let service: any ChatServicing
    private let messageStore: ChatMessageStore
    private let notificationStore: ChatNotificationStore
    private let disposeBag = DisposeBag()
    private var hasLoaded = false
    private var currentUserID = ""

    init(
        room: ChatRoom,
        service: any ChatServicing = ChatService(),
        socketManager: ChatSocketManager? = nil,
        messageStore: ChatMessageStore = .shared,
        notificationStore: ChatNotificationStore = .shared
    ) {
        self.room = room
        self.messages = room.messages.isEmpty ? [room.lastChat].compactMap { $0 } : room.messages
        self.service = service
        self.socketManager = socketManager ?? ChatSocketManager(roomID: room.roomID)
        self.messageStore = messageStore
        self.notificationStore = notificationStore
        bindSocket()
    }

    func loadHistory(accessToken: String) async throws {
        guard !hasLoaded else { return }

        viewState = .loading
        currentUserID = accessToken.decodedJWTUserID ?? currentUserID
        socketManager.connect(accessToken: accessToken)

        let cachedMessages = await messageStore.loadMessages(roomID: room.roomID)
        if !cachedMessages.isEmpty {
            applyMessages(cachedMessages)
        }

        do {
            let fetchedMessages = try await service.fetchChatHistory(
                roomID: room.roomID,
                cursor: nil,
                accessToken: accessToken
            )
            let mergedMessages = try await messageStore.mergeMessages(fetchedMessages, roomID: room.roomID)
            applyMessages(mergedMessages)
            hasLoaded = true
            viewState = .loaded
        } catch {
            if !cachedMessages.isEmpty {
                viewState = .loaded
            } else {
                viewState = .error(error.localizedDescription)
            }
            throw error
        }
    }

    func retry(accessToken: String) async throws {
        hasLoaded = false
        try await loadHistory(accessToken: accessToken)
    }

    func sendCurrentDraft(accessToken: String) async throws {
        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        currentUserID = accessToken.decodedJWTUserID ?? currentUserID
        isSending = true
        defer { isSending = false }

        let sentMessage = try await service.sendMessage(
            roomID: room.roomID,
            content: trimmedText,
            files: [],
            accessToken: accessToken
        )

        let result = try await messageStore.saveMessage(sentMessage, roomID: room.roomID)
        if result.inserted {
            applyMessages(result.messages)
        }

        draftText = ""
        inputHeight = 44
    }

    func pollForNewMessages(accessToken: String) async {
        let cursor = messages.last?.createdAt
        do {
            let fetchedMessages = try await service.fetchChatHistory(
                roomID: room.roomID,
                cursor: cursor,
                accessToken: accessToken
            )
            guard !fetchedMessages.isEmpty else { return }
            let mergedMessages = try await messageStore.mergeMessages(fetchedMessages, roomID: room.roomID)
            if mergedMessages.last?.chatID != messages.last?.chatID {
                applyMessages(mergedMessages)
            }
        } catch {
            // 폴링 오류는 조용히 무시 (소켓이 살아있으면 메시지는 도달함)
        }
    }

    func isMine(_ message: ChatMessage) -> Bool {
        guard !currentUserID.isEmpty else { return false }
        return message.sender.userID == currentUserID
    }

    var navigationTitle: String {
        if let other = room.participants.first(where: { $0.userID != currentUserID && !$0.nick.isEmpty }) {
            return other.nick
        }
        return room.participants.first(where: { !$0.nick.isEmpty })?.nick ?? "채팅"
    }

    func formattedTimestamp(for message: ChatMessage) -> String {
        guard let sentAtDate = message.sentAtDate else {
            return message.createdAt ?? ""
        }

        if Calendar.current.isDateInToday(sentAtDate) {
            return DateFormatter.chatTodayTime.string(from: sentAtDate)
        }

        return DateFormatter.chatPastDayTime.string(from: sentAtDate)
    }

    private func bindSocket() {
        socketManager.incomingMessageRelay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    await self?.ingestSocketMessage(message)
                }
            })
            .disposed(by: disposeBag)
    }

    private func applyMessages(_ incomingMessages: [ChatMessage]) {
        let lastChat = incomingMessages.last ?? room.lastChat
        room = ChatRoom(
            roomID: room.roomID,
            createdAt: room.createdAt,
            updatedAt: room.updatedAt,
            participants: room.participants,
            lastChat: lastChat,
            messages: incomingMessages
        )
        messages = incomingMessages
    }

    private func ingestSocketMessage(_ message: ChatMessage) async {
        do {
            let result = try await messageStore.saveMessage(message, roomID: room.roomID)
            guard result.inserted else { return }
            applyMessages(result.messages)
            if !isMine(message) {
                notificationStore.record(
                    message: message,
                    roomTitle: room.displayTitle(currentUserID: currentUserID),
                    isRead: true
                )
            }
        } catch {
            print("Failed to persist socket message: \(error.localizedDescription)")
        }
    }
}
