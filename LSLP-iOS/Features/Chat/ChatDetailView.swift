//
//  ChatDetailView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import SwiftUI

struct ChatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var chatNotificationStore: ChatNotificationStore
    @EnvironmentObject private var appTabRouter: AppTabRouter
    @StateObject private var viewModel: ChatViewModel

    init(room: ChatRoom) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch viewModel.viewState {
                    case .idle, .loading:
                        ProgressView("대화 내역을 불러오는 중...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        chatContent
                    case let .error(message):
                        errorView(message: message)
                    }
                }

                composerBar
            }
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .task(id: authSession.state) {
            guard authSession.state == .authenticated else { return }
            chatNotificationStore.markRead(roomID: viewModel.room.roomID)
            await loadHistory()
            await startPolling()
        }
        .onAppear {
            appTabRouter.isRootTabBarHidden = true
        }
        .onDisappear {
            appTabRouter.isRootTabBarHidden = false
            viewModel.socketManager.disconnect()
        }
    }

    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(
                            message: message,
                            isMine: viewModel.isMine(message),
                            timestamp: viewModel.formattedTimestamp(for: message)
                        )
                        .id(message.chatID)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ChatComposerTextView(
                text: $viewModel.draftText,
                calculatedHeight: $viewModel.inputHeight,
                placeholder: "메시지를 입력하세요."
            )
            .frame(height: viewModel.inputHeight)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 52, height: 52)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 0.64, green: 0.71, blue: 0.57))
                        .frame(width: 52, height: 52)
                }
            }
            .disabled(viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Text("대화 내역을 불러오지 못했습니다.")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await loadHistory(forceRetry: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func startPolling() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }
            guard case .loaded = viewModel.viewState else { continue }
            do {
                let accessToken = try await authSession.resolveAccessToken()
                await viewModel.pollForNewMessages(accessToken: accessToken)
            } catch {
                // 토큰 오류는 무시하고 계속 폴링
            }
        }
    }

    @MainActor
    private func loadHistory(forceRetry: Bool = false) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            if forceRetry {
                try await viewModel.retry(accessToken: accessToken)
            } else {
                try await viewModel.loadHistory(accessToken: accessToken)
            }
        } catch let error as ChatServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    if forceRetry {
                        try await viewModel.retry(accessToken: refreshedAccessToken)
                    } else {
                        try await viewModel.loadHistory(accessToken: refreshedAccessToken)
                    }
                } catch {
                    await authSession.logout()
                }
            case .unauthorized:
                await authSession.logout()
            default:
                break
            }
        } catch let error as AuthSessionError {
            print("Auth session failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch let error as AuthServiceError {
            print("Token refresh failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch {
            print("Failed to load chat history: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func sendMessage() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.sendCurrentDraft(accessToken: accessToken)
        } catch let error as ChatServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    try await viewModel.sendCurrentDraft(accessToken: refreshedAccessToken)
                } catch {
                    await authSession.logout()
                }
            case .unauthorized:
                await authSession.logout()
            default:
                print("Failed to send message: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to send message: \(error.localizedDescription)")
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessageID = viewModel.messages.last?.chatID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let timestamp: String

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 56) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                if !isMine {
                    Text(message.sender.nick)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.45))
                }

                VStack(alignment: .leading, spacing: 8) {
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isMine ? .white : Color(red: 0.24, green: 0.26, blue: 0.22))
                    }

                    if !message.files.isEmpty {
                        Text("첨부 파일 \(message.files.count)개")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isMine ? Color.white.opacity(0.82) : Color(red: 0.53, green: 0.59, blue: 0.46))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    isMine
                    ? Color(red: 0.64, green: 0.71, blue: 0.57)
                    : .white
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(timestamp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if !isMine { Spacer(minLength: 56) }
        }
    }
}
