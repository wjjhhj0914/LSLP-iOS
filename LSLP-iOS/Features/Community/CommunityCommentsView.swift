//
//  CommunityCommentsView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import SwiftUI

struct CommunityCommentsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: CommunityCommentsViewModel
    @State private var pendingDeleteComment: CommunityComment?
    @State private var activeChatRoom: ChatRoom?
    @State private var chatErrorMessage: String?
    @State private var isCreatingChatRoom = false

    init(post: CommunityPost) {
        _viewModel = StateObject(wrappedValue: CommunityCommentsViewModel(post: post))
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            postSummary
                            commentsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 118)
                    }

                    composerBar
                }
            }
            .navigationTitle("댓글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await createChatRoomAndNavigate()
                        }
                    } label: {
                        if isCreatingChatRoom {
                            ProgressView()
                        } else {
                            Label("채팅", systemImage: "message.fill")
                        }
                    }
                    .disabled(isCreatingChatRoom || viewModel.post.creator.userID.isEmpty)
                }
            }
            .background(chatNavigationLink)
        }
        .navigationViewStyle(.stack)
        .alert("댓글 작업", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("댓글 관리", isPresented: Binding(
            get: { pendingDeleteComment != nil },
            set: { if !$0 { pendingDeleteComment = nil } }
        )) {
            Button("삭제", role: .destructive) {
                guard let pendingDeleteComment else { return }
                Task {
                    await delete(pendingDeleteComment)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 댓글을 삭제할까요?")
        }
        .alert("채팅방 진입", isPresented: Binding(
            get: { chatErrorMessage != nil },
            set: { if !$0 { chatErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(chatErrorMessage ?? "")
        }
    }

    private var postSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.91, green: 0.94, blue: 0.90))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(red: 0.60, green: 0.67, blue: 0.55))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.post.creator.nick)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.26, green: 0.28, blue: 0.24))

                    Text(viewModel.post.relativeCreatedText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.67, green: 0.69, blue: 0.68))
                }
            }

            if !viewModel.post.resolvedImageURLs.isEmpty {
                postMediaStrip
            }

            Text(viewModel.post.title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color(red: 0.21, green: 0.22, blue: 0.19))

            Text(viewModel.post.content)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.45))
                .lineSpacing(4)
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var chatNavigationLink: some View {
        NavigationLink(
            destination: Group {
                if let activeChatRoom {
                    ChatDetailView(room: activeChatRoom)
                        .environmentObject(authSession)
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(
                get: { activeChatRoom != nil },
                set: { if !$0 { activeChatRoom = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var postMediaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.post.resolvedImageURLs.prefix(5).enumerated()), id: \.offset) { _, url in
                    AuthenticatedCroppedImage(url: url)
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("댓글")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.22, blue: 0.19))

                Spacer()

                Text("\(viewModel.comments.count)개")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.57, green: 0.62, blue: 0.52))
            }

            if viewModel.comments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "ellipsis.message")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(red: 0.75, green: 0.79, blue: 0.71))

                    Text("첫 댓글을 남겨보세요.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.53))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.comments) { comment in
                        CommunityCommentRow(
                            comment: comment,
                            onReply: { viewModel.startReply(to: comment) },
                            onEdit: { viewModel.startEditing(comment) },
                            onDelete: { pendingDeleteComment = comment }
                        )
                    }
                }
            }
        }
    }

    private var composerBar: some View {
        VStack(spacing: 10) {
            if viewModel.replyTarget != nil || viewModel.editingComment != nil {
                HStack {
                    Text(viewModel.composerTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.49, green: 0.58, blue: 0.43))

                    Spacer()

                    Button("취소") {
                        viewModel.cancelComposerMode()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $viewModel.draftText)
                    .font(.system(size: 15, weight: .medium))
                    .frame(minHeight: 44, maxHeight: 96)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.96, green: 0.97, blue: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if viewModel.draftText.isEmpty {
                            Text(viewModel.replyTarget == nil ? "댓글을 입력하세요." : "답글을 입력하세요.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.72))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    Task {
                        await submitComment()
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 56, height: 56)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(red: 0.64, green: 0.71, blue: 0.57))
                            .frame(width: 56, height: 56)
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.white)
        }
    }

    @MainActor
    private func submitComment() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.submit(accessToken: accessToken)
        } catch let error as CommunityServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    try await viewModel.submit(accessToken: refreshedAccessToken)
                } catch let refreshError as LocalizedError {
                    viewModel.errorMessage = refreshError.errorDescription ?? "댓글 등록에 실패했습니다."
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            case .unauthorized:
                await authSession.logout()
            default:
                viewModel.errorMessage = error.localizedDescription
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete(_ comment: CommunityComment) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.delete(comment, accessToken: accessToken)
        } catch let error as CommunityServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    try await viewModel.delete(comment, accessToken: refreshedAccessToken)
                } catch let refreshError as LocalizedError {
                    viewModel.errorMessage = refreshError.errorDescription ?? "댓글 삭제에 실패했습니다."
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            case .unauthorized:
                await authSession.logout()
            default:
                viewModel.errorMessage = error.localizedDescription
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createChatRoomAndNavigate() async {
        guard !viewModel.post.creator.userID.isEmpty else {
            chatErrorMessage = "작성자 정보를 확인할 수 없습니다."
            return
        }

        isCreatingChatRoom = true
        defer { isCreatingChatRoom = false }

        let service = ChatService()

        do {
            let accessToken = try await authSession.resolveAccessToken()
            let room = try await service.createOrFetchRoom(
                targetUserID: viewModel.post.creator.userID,
                accessToken: accessToken
            )
            activeChatRoom = room
        } catch let error as ChatServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    let room = try await service.createOrFetchRoom(
                        targetUserID: viewModel.post.creator.userID,
                        accessToken: refreshedAccessToken
                    )
                    activeChatRoom = room
                } catch let refreshError as LocalizedError {
                    chatErrorMessage = refreshError.errorDescription ?? "채팅방 생성에 실패했습니다."
                } catch {
                    chatErrorMessage = error.localizedDescription
                }
            case .unauthorized:
                await authSession.logout()
            default:
                chatErrorMessage = error.localizedDescription
            }
        } catch let error as AuthSessionError {
            chatErrorMessage = error.errorDescription
        } catch let error as AuthServiceError {
            chatErrorMessage = error.errorDescription
        } catch {
            chatErrorMessage = error.localizedDescription
        }
    }
}

private struct CommunityCommentRow: View {
    let comment: CommunityComment
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            commentBubble(comment: comment, isReply: false)

            if !comment.replies.isEmpty {
                VStack(spacing: 10) {
                    ForEach(comment.replies) { reply in
                        commentBubble(comment: reply, isReply: true)
                    }
                }
                .padding(.leading, 22)
            }
        }
    }

    private func commentBubble(comment: CommunityComment, isReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.91, green: 0.94, blue: 0.90))
                    .frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: isReply ? 12 : 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.60, green: 0.67, blue: 0.55))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.creator.nick)
                        .font(.system(size: isReply ? 14 : 15, weight: .heavy))
                        .foregroundStyle(Color(red: 0.24, green: 0.26, blue: 0.22))

                    Text(comment.relativeCreatedText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.67, green: 0.69, blue: 0.68))
                }

                Spacer()
            }

            Text(comment.content)
                .font(.system(size: isReply ? 14 : 15, weight: .medium))
                .foregroundStyle(Color(red: 0.33, green: 0.35, blue: 0.31))
                .lineSpacing(3)

            HStack(spacing: 16) {
                Button("답글") {
                    onReply()
                }
                Button("수정") {
                    onEdit()
                }
                Button("삭제", role: .destructive) {
                    onDelete()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(red: 0.53, green: 0.59, blue: 0.46))
        }
        .padding(isReply ? 14 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
