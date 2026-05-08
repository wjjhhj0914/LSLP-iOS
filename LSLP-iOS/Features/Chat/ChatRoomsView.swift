//
//  ChatRoomsView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import SwiftUI

struct ChatRoomsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var chatNotificationStore: ChatNotificationStore
    @StateObject private var viewModel = ChatRoomsViewModel()
    @State private var activeRoom: ChatRoom?
    @State private var errorMessage: String?
    @State private var isNotificationPresented = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    switch viewModel.viewState {
                    case .idle, .loading:
                        ProgressView("채팅 목록을 불러오는 중...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        content
                    case let .error(message):
                        errorView(message: message)
                    }
                }
            }
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isNotificationPresented = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18, weight: .bold))

                            if chatNotificationStore.unreadCount > 0 {
                                Text("\(min(chatNotificationStore.unreadCount, 99))")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel("채팅 알림")
                }
            }
            .task(id: authSession.state) {
                guard authSession.state == .authenticated else { return }
                await load()
            }
            .onAppear {
                guard case .loaded = viewModel.viewState else { return }
                Task { await load(forceRefresh: true) }
            }
            .onChange(of: activeRoom) { room in
                guard room == nil, case .loaded = viewModel.viewState else { return }
                Task { await load(forceRefresh: true) }
            }
            .sheet(isPresented: $isNotificationPresented) {
                ChatNotificationsSheet(activeRoom: $activeRoom)
                    .environmentObject(chatNotificationStore)
            }
            .alert("채팅", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .background(chatNavigationLink)
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                searchBar

                if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchSections
                } else {
                    roomSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.61, green: 0.68, blue: 0.56))

            TextField("닉네임으로 채팅 상대 찾기", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 0.79, green: 0.85, blue: 0.75), lineWidth: 1)
        )
    }

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("대화중인 채팅방")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

            if viewModel.rooms.isEmpty {
                emptyCard(text: "아직 참여 중인 채팅방이 없습니다.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.rooms) { room in
                        Button {
                            chatNotificationStore.markRead(roomID: room.roomID)
                            activeRoom = room
                        } label: {
                            ChatRoomRow(
                                title: viewModel.title(for: room),
                                subtitle: viewModel.subtitle(for: room),
                                timestamp: viewModel.timestamp(for: room)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !viewModel.filteredCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("닉네임 검색 결과")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                    ForEach(viewModel.filteredCandidates) { candidate in
                        Button {
                            Task {
                                await createRoom(with: candidate)
                            }
                        } label: {
                            ChatUserCandidateRow(candidate: candidate, isLoading: viewModel.isStartingChat)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("기존 채팅방")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                if viewModel.filteredRooms.isEmpty {
                    emptyCard(text: "검색된 채팅방이 없습니다.")
                } else {
                    ForEach(viewModel.filteredRooms) { room in
                        Button {
                            chatNotificationStore.markRead(roomID: room.roomID)
                            activeRoom = room
                        } label: {
                            ChatRoomRow(
                                title: viewModel.title(for: room),
                                subtitle: viewModel.subtitle(for: room),
                                timestamp: viewModel.timestamp(for: room)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(red: 0.57, green: 0.60, blue: 0.56))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Text("채팅 목록을 불러오지 못했습니다.")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await load(forceRefresh: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let activeRoom {
                    ChatDetailView(room: activeRoom)
                        .environmentObject(authSession)
                        .environmentObject(chatNotificationStore)
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(
                get: { activeRoom != nil },
                set: { if !$0 { activeRoom = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @MainActor
    private func load(forceRefresh: Bool = false) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            if forceRefresh {
                try await viewModel.refresh(accessToken: accessToken)
            } else {
                try await viewModel.load(accessToken: accessToken)
            }
        } catch let error as ChatServiceError {
            switch error {
            case .accessTokenExpired:
                await retryWithRefresh(forceRefresh: forceRefresh)
            case .unauthorized:
                await authSession.logout()
            default:
                errorMessage = error.localizedDescription
            }
        } catch let error as AuthSessionError {
            errorMessage = error.localizedDescription
        } catch let error as AuthServiceError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func retryWithRefresh(forceRefresh: Bool) async {
        do {
            let refreshed = try await authSession.refreshAccessToken()
            if forceRefresh {
                try await viewModel.refresh(accessToken: refreshed)
            } else {
                try await viewModel.load(accessToken: refreshed)
            }
        } catch {
            await authSession.logout()
        }
    }

    @MainActor
    private func createRoom(with candidate: ChatUserCandidate) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            let room = try await viewModel.createOrFetchRoom(for: candidate, accessToken: accessToken)
            activeRoom = room
        } catch let error as ChatServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshed = try await authSession.refreshAccessToken()
                    let room = try await viewModel.createOrFetchRoom(for: candidate, accessToken: refreshed)
                    activeRoom = room
                } catch {
                    await authSession.logout()
                }
            case .unauthorized:
                await authSession.logout()
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ChatRoomRow: View {
    let title: String
    let subtitle: String
    let timestamp: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(red: 0.88, green: 0.92, blue: 0.85))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "message.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.56, green: 0.64, blue: 0.49))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.48, green: 0.50, blue: 0.47))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(timestamp)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.57, green: 0.60, blue: 0.56))
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ChatUserCandidateRow: View {
    let candidate: ChatUserCandidate
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(red: 0.91, green: 0.94, blue: 0.90))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(Color(red: 0.60, green: 0.67, blue: 0.55))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.nick)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                Text(candidate.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.57, green: 0.60, blue: 0.56))
                    .lineLimit(1)
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Text("채팅 시작")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.49, green: 0.58, blue: 0.43))
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ChatNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatNotificationStore: ChatNotificationStore
    @Binding var activeRoom: ChatRoom?

    var body: some View {
        NavigationView {
            List {
                if chatNotificationStore.items.isEmpty {
                    Text("표시할 채팅 알림이 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(chatNotificationStore.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.roomTitle)
                                    .font(.system(size: 16, weight: .heavy))
                                Spacer()
                                Text(DateFormatter.chatPastDayTime.string(from: item.createdAt))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(item.senderNick): \(item.previewText)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("채팅 알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("모두 읽음") {
                        chatNotificationStore.markAllRead()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
