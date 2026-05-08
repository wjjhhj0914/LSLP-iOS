//
//  ChatRoomsViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Combine
import Foundation

@MainActor
final class ChatRoomsViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var rooms: [ChatRoom] = []
    @Published private(set) var userCandidates: [ChatUserCandidate] = []
    @Published var searchText = ""
    @Published private(set) var isStartingChat = false

    private let chatService: any ChatServicing
    private let communityService: any CommunityServicing
    private let notificationStore: ChatNotificationStore
    private let currentLocation = CommunityPostListRequest(
        longitude: 127.049914,
        latitude: 37.654215,
        nextCursor: nil,
        limit: 30
    )

    private var hasLoaded = false
    private var currentUserID = ""

    init(
        chatService: any ChatServicing = ChatService(),
        communityService: any CommunityServicing = CommunityService(),
        notificationStore: ChatNotificationStore? = nil
    ) {
        self.chatService = chatService
        self.communityService = communityService
        self.notificationStore = notificationStore ?? .shared
    }

    var filteredRooms: [ChatRoom] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rooms }
        return rooms.filter { room in
            room.participants.contains { $0.userID != currentUserID && $0.nick.localizedCaseInsensitiveContains(query) }
        }
    }

    var filteredCandidates: [ChatUserCandidate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return userCandidates.filter { $0.nick.localizedCaseInsensitiveContains(query) }
    }

    func load(accessToken: String) async throws {
        guard !hasLoaded else { return }
        try await refresh(accessToken: accessToken)
        hasLoaded = true
    }

    func refresh(accessToken: String) async throws {
        viewState = .loading
        currentUserID = accessToken.decodedJWTUserID ?? currentUserID

        do {
            async let roomTask = chatService.fetchChatRooms(accessToken: accessToken)
            async let communityTask = communityService.fetchGeolocationPosts(
                request: currentLocation,
                accessToken: accessToken
            )

            let fetchedRooms = try await roomTask
            let communityResponse = try await communityTask

            rooms = fetchedRooms
            userCandidates = buildCandidates(posts: communityResponse.data, rooms: fetchedRooms)
            notificationStore.seed(from: fetchedRooms, currentUserID: currentUserID)
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
            throw error
        }
    }

    func createOrFetchRoom(for candidate: ChatUserCandidate, accessToken: String) async throws -> ChatRoom {
        isStartingChat = true
        defer { isStartingChat = false }

        let room = try await chatService.createOrFetchRoom(
            targetUserID: candidate.userID,
            accessToken: accessToken
        )

        if !rooms.contains(where: { $0.roomID == room.roomID }) {
            rooms.insert(room, at: 0)
        }

        return room
    }

    func title(for room: ChatRoom) -> String {
        room.displayTitle(currentUserID: currentUserID)
    }

    func subtitle(for room: ChatRoom) -> String {
        if let lastChat = room.lastChat {
            return lastChat.content.isEmpty ? "첨부 파일 \(lastChat.files.count)개" : lastChat.content
        }
        return "아직 대화가 없습니다."
    }

    func timestamp(for room: ChatRoom) -> String {
        guard let date = room.lastActivityDate else { return "" }
        if Calendar.current.isDateInToday(date) {
            return DateFormatter.chatTodayTime.string(from: date)
        }
        return DateFormatter.chatPastDayTime.string(from: date)
    }

    private func buildCandidates(posts: [CommunityPost], rooms: [ChatRoom]) -> [ChatUserCandidate] {
        let existingParticipantIDs = Set(
            rooms.flatMap(\.participants).map(\.userID)
        )

        var unique: [String: ChatUserCandidate] = [:]
        for post in posts {
            let creator = post.creator
            guard !creator.userID.isEmpty, creator.userID != currentUserID else { continue }
            let subtitle = post.store.category.isEmpty ? post.category : "\(post.store.name.isEmpty ? post.category : post.store.name) · \(post.category)"
            unique[creator.userID] = ChatUserCandidate(
                userID: creator.userID,
                nick: creator.nick.isEmpty ? "알 수 없음" : creator.nick,
                profileImage: creator.profileImage,
                subtitle: subtitle
            )
        }

        return unique.values
            .filter { !existingParticipantIDs.contains($0.userID) }
            .sorted { $0.nick.localizedCaseInsensitiveCompare($1.nick) == .orderedAscending }
    }
}
