//
//  CommunityCommentsViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import Combine
import Foundation

@MainActor
final class CommunityCommentsViewModel: ObservableObject {
    @Published private(set) var comments: [CommunityComment]
    @Published var draftText = ""
    @Published var replyTarget: CommunityComment?
    @Published var editingComment: CommunityComment?
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    let post: CommunityPost

    private let service: any CommunityServicing

    init(
        post: CommunityPost,
        comments: [CommunityComment] = [],
        service: any CommunityServicing = CommunityService()
    ) {
        self.post = post
        self.comments = comments
        self.service = service
    }

    var composerTitle: String {
        if editingComment != nil {
            return "댓글 수정"
        }
        if let replyTarget {
            return "\(replyTarget.creator.nick)님에게 답글"
        }
        return "댓글 작성"
    }

    func startReply(to comment: CommunityComment) {
        editingComment = nil
        replyTarget = comment
        draftText = ""
    }

    func startEditing(_ comment: CommunityComment) {
        replyTarget = nil
        editingComment = comment
        draftText = comment.content
    }

    func cancelComposerMode() {
        replyTarget = nil
        editingComment = nil
        draftText = ""
    }

    func submit(accessToken: String) async throws {
        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw CommunityServiceError.emptyContent
        }

        isSubmitting = true
        defer { isSubmitting = false }

        if let editingComment {
            let updatedComment = try await service.updateComment(
                postID: post.postID,
                commentID: editingComment.commentID,
                content: trimmedText,
                accessToken: accessToken
            )
            comments = replacingComment(in: comments, with: updatedComment)
        } else {
            let createdComment = try await service.createComment(
                postID: post.postID,
                content: trimmedText,
                parentCommentID: replyTarget?.commentID,
                accessToken: accessToken
            )

            if let replyTarget {
                comments = appendingReply(in: comments, to: replyTarget.commentID, reply: createdComment)
            } else {
                comments.insert(createdComment, at: 0)
            }
        }

        cancelComposerMode()
    }

    func delete(_ comment: CommunityComment, accessToken: String) async throws {
        try await service.deleteComment(
            postID: post.postID,
            commentID: comment.commentID,
            accessToken: accessToken
        )
        comments = removingComment(from: comments, commentID: comment.commentID)
        if replyTarget?.commentID == comment.commentID || editingComment?.commentID == comment.commentID {
            cancelComposerMode()
        }
    }

    private func appendingReply(
        in comments: [CommunityComment],
        to parentCommentID: String,
        reply: CommunityComment
    ) -> [CommunityComment] {
        comments.map { comment in
            if comment.commentID == parentCommentID {
                return comment.withReplies(comment.replies + [reply])
            }

            if comment.replies.isEmpty {
                return comment
            }

            return comment.withReplies(appendingReply(in: comment.replies, to: parentCommentID, reply: reply))
        }
    }

    private func replacingComment(
        in comments: [CommunityComment],
        with updatedComment: CommunityComment
    ) -> [CommunityComment] {
        comments.map { comment in
            if comment.commentID == updatedComment.commentID {
                return updatedComment.withReplies(comment.replies)
            }

            if comment.replies.isEmpty {
                return comment
            }

            return comment.withReplies(replacingComment(in: comment.replies, with: updatedComment))
        }
    }

    private func removingComment(
        from comments: [CommunityComment],
        commentID: String
    ) -> [CommunityComment] {
        comments.compactMap { comment in
            guard comment.commentID != commentID else { return nil }
            if comment.replies.isEmpty {
                return comment
            }
            return comment.withReplies(removingComment(from: comment.replies, commentID: commentID))
        }
    }
}
