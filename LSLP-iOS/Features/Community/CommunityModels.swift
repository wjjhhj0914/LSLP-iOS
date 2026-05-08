//
//  CommunityModels.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Foundation
import CoreLocation
import UIKit

struct CommunityPostListRequest: Sendable {
    let longitude: Double
    let latitude: Double
    let nextCursor: String?
    let limit: Int
}

struct CommunityUploadFilesResponse: Decodable, Sendable {
    let files: [String]
}

struct CommunityCreatePostGeolocation: Encodable, Sendable {
    let longitude: Double
    let latitude: Double
}

struct CommunityCreatePostRequest: Encodable, Sendable {
    let category: String
    let title: String
    let content: String
    let files: [String]
    let geolocation: CommunityCreatePostGeolocation

    enum CodingKeys: String, CodingKey {
        case category
        case title
        case content
        case files
        case geolocation
        case longitude
        case latitude
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(files, forKey: .files)
        try container.encode(geolocation, forKey: .geolocation)
        try container.encode(geolocation.longitude, forKey: .longitude)
        try container.encode(geolocation.latitude, forKey: .latitude)
    }
}

struct CommunityCreatedPostResponse: Decodable, Sendable {
    let postID: String?

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
    }
}

struct CommunityCommentCreateRequest: Encodable, Sendable {
    let content: String
    let parentCommentID: String?

    enum CodingKeys: String, CodingKey {
        case content
        case parentCommentID = "parent_comment_id"
        case legacyParentCommentID = "parentCommentID"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(parentCommentID, forKey: .parentCommentID)
        try container.encodeIfPresent(parentCommentID, forKey: .legacyParentCommentID)
    }
}

struct CommunityCommentUpdateRequest: Encodable, Sendable {
    let content: String
}

struct CommunityComment: Decodable, Identifiable, Sendable, Equatable {
    let commentID: String
    let content: String
    let createdAt: String?
    let creator: CommunityPostCreator
    let parentCommentID: String?
    let replies: [CommunityComment]

    var id: String { commentID }

    enum CodingKeys: String, CodingKey {
        case commentID = "comment_id"
        case content
        case createdAt
        case creator
        case parentCommentID = "parent_comment_id"
        case legacyParentCommentID = "parentCommentID"
        case replies
        case commentList = "comment_list"
    }

    init(
        commentID: String,
        content: String,
        createdAt: String?,
        creator: CommunityPostCreator,
        parentCommentID: String? = nil,
        replies: [CommunityComment] = []
    ) {
        self.commentID = commentID
        self.content = content
        self.createdAt = createdAt
        self.creator = creator
        self.parentCommentID = parentCommentID
        self.replies = replies
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commentID = try container.decode(String.self, forKey: .commentID)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        creator = try container.decodeIfPresent(CommunityPostCreator.self, forKey: .creator) ?? .empty
        parentCommentID = try container.decodeIfPresent(String.self, forKey: .parentCommentID)
            ?? container.decodeIfPresent(String.self, forKey: .legacyParentCommentID)
        replies = try container.decodeIfPresent([CommunityComment].self, forKey: .replies)
            ?? container.decodeIfPresent([CommunityComment].self, forKey: .commentList)
            ?? []
    }

    func updatingContent(_ content: String) -> CommunityComment {
        CommunityComment(
            commentID: commentID,
            content: content,
            createdAt: createdAt,
            creator: creator,
            parentCommentID: parentCommentID,
            replies: replies
        )
    }

    func withReplies(_ replies: [CommunityComment]) -> CommunityComment {
        CommunityComment(
            commentID: commentID,
            content: content,
            createdAt: createdAt,
            creator: creator,
            parentCommentID: parentCommentID,
            replies: replies
        )
    }

    var relativeCreatedText: String {
        guard let createdAt, let date = ISO8601DateFormatter().date(from: createdAt) else {
            return "방금 전"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CommunityComposerDraft: Sendable {
    let title: String
    let content: String
    let category: String
    let geolocation: StoreGeolocation
}

struct CommunityMediaUploadItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image
        case video
    }

    let id: UUID
    let fileName: String
    let mimeType: String
    let fileExtension: String
    let data: Data
    let previewImage: UIImage?
    let kind: Kind

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        fileExtension: String,
        data: Data,
        previewImage: UIImage?,
        kind: Kind
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.data = data
        self.previewImage = previewImage
        self.kind = kind
    }
}

struct CommunityPostListResponse: Decodable, Sendable {
    let data: [CommunityPost]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

struct CommunityPost: Decodable, Identifiable, Sendable, Equatable {
    let postID: String
    let category: String
    let title: String
    let content: String
    let store: CommunityStore
    let geolocation: StoreGeolocation
    let creator: CommunityPostCreator
    let files: [String]
    let isLike: Bool
    let likeCount: Int
    let createdAt: String?
    let updatedAt: String?

    var id: String { postID }

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case category
        case title
        case content
        case store
        case geolocation
        case creator
        case files
        case isLike = "is_like"
        case likeCount = "like_count"
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postID = try container.decode(String.self, forKey: .postID)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        store = try container.decodeIfPresent(CommunityStore.self, forKey: .store) ?? .empty
        geolocation = try container.decodeIfPresent(StoreGeolocation.self, forKey: .geolocation) ?? .empty
        creator = try container.decodeIfPresent(CommunityPostCreator.self, forKey: .creator) ?? .empty
        files = try container.decodeIfPresent([String].self, forKey: .files) ?? []
        isLike = try container.decodeIfPresent(Bool.self, forKey: .isLike) ?? false
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    init(
        postID: String,
        category: String,
        title: String,
        content: String,
        store: CommunityStore,
        geolocation: StoreGeolocation,
        creator: CommunityPostCreator,
        files: [String],
        isLike: Bool,
        likeCount: Int,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.postID = postID
        self.category = category
        self.title = title
        self.content = content
        self.store = store
        self.geolocation = geolocation
        self.creator = creator
        self.files = files
        self.isLike = isLike
        self.likeCount = likeCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CommunityStore: Decodable, Sendable, Equatable {
    let id: String
    let category: String
    let name: String
    let address: String
    let close: String
    let storeImageURLs: [String]
    let isPicchelin: Bool
    let isPick: Bool
    let pickCount: Int
    let hashTags: [String]
    let totalRating: Double
    let totalOrderCount: Int
    let totalReviewCount: Int
    let geolocation: StoreGeolocation
    let createdAt: String?
    let updatedAt: String?

    static let empty = CommunityStore(
        id: "",
        category: "",
        name: "",
        address: "",
        close: "",
        storeImageURLs: [],
        isPicchelin: false,
        isPick: false,
        pickCount: 0,
        hashTags: [],
        totalRating: 0,
        totalOrderCount: 0,
        totalReviewCount: 0,
        geolocation: .empty,
        createdAt: nil,
        updatedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case name
        case address
        case close
        case storeImageURLs = "store_image_urls"
        case isPicchelin = "is_picchelin"
        case isPick = "is_pick"
        case pickCount = "pick_count"
        case hashTags
        case totalRating = "total_rating"
        case totalOrderCount = "total_order_count"
        case totalReviewCount = "total_review_count"
        case geolocation
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        category: String,
        name: String,
        address: String,
        close: String,
        storeImageURLs: [String],
        isPicchelin: Bool,
        isPick: Bool,
        pickCount: Int,
        hashTags: [String],
        totalRating: Double,
        totalOrderCount: Int,
        totalReviewCount: Int,
        geolocation: StoreGeolocation,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.address = address
        self.close = close
        self.storeImageURLs = storeImageURLs
        self.isPicchelin = isPicchelin
        self.isPick = isPick
        self.pickCount = pickCount
        self.hashTags = hashTags
        self.totalRating = totalRating
        self.totalOrderCount = totalOrderCount
        self.totalReviewCount = totalReviewCount
        self.geolocation = geolocation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        close = try container.decodeIfPresent(String.self, forKey: .close) ?? ""
        storeImageURLs = try container.decodeIfPresent([String].self, forKey: .storeImageURLs) ?? []
        isPicchelin = try container.decodeIfPresent(Bool.self, forKey: .isPicchelin) ?? false
        isPick = try container.decodeIfPresent(Bool.self, forKey: .isPick) ?? false
        pickCount = try container.decodeIfPresent(Int.self, forKey: .pickCount) ?? 0
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
        totalRating = try container.decodeIfPresent(Double.self, forKey: .totalRating) ?? 0
        totalOrderCount = try container.decodeIfPresent(Int.self, forKey: .totalOrderCount) ?? 0
        totalReviewCount = try container.decodeIfPresent(Int.self, forKey: .totalReviewCount) ?? 0
        geolocation = try container.decodeIfPresent(StoreGeolocation.self, forKey: .geolocation) ?? .empty
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct CommunityPostCreator: Decodable, Sendable, Equatable {
    let userID: String
    let nick: String
    let profileImage: String

    static let empty = CommunityPostCreator(userID: "", nick: "", profileImage: "")

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
        nick = try container.decodeIfPresent(String.self, forKey: .nick) ?? ""
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage) ?? ""
    }
}

extension CommunityPost {
    var resolvedImageURLs: [URL] {
        files.compactMap { APIURLResolver.resolve(path: $0) }
    }

    var primaryImageURL: URL? {
        resolvedImageURLs.first
    }

    var secondaryImageURLs: [URL] {
        Array(resolvedImageURLs.dropFirst().prefix(2))
    }

    func distanceLabel(from request: CommunityPostListRequest) -> String {
        let source = CLLocation(latitude: request.latitude, longitude: request.longitude)
        let target = CLLocation(latitude: geolocation.latitude, longitude: geolocation.longitude)
        let distance = max(source.distance(from: target), 0)
        return "\(Int(distance.rounded()))M"
    }

    var relativeCreatedText: String {
        guard let createdAt else { return "방금 전" }
        guard let date = ISO8601DateFormatter().date(from: createdAt) else { return "방금 전" }

        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return "방금 전" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86_400 { return "\(seconds / 3600)시간 전" }
        if seconds < 604_800 { return "\(seconds / 86_400)일 전" }
        return "\(seconds / 604_800)주 전"
    }

    func updatingStore(address: String) -> CommunityPost {
        CommunityPost(
            postID: postID,
            category: category,
            title: title,
            content: content,
            store: store.updatingAddress(address),
            geolocation: geolocation,
            creator: creator,
            files: files,
            isLike: isLike,
            likeCount: likeCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension CommunityStore {
    var resolvedImageURL: URL? {
        storeImageURLs.first.flatMap { APIURLResolver.resolve(path: $0) }
    }

    var hasDisplayableStoreInfo: Bool {
        !name.isEmpty || !category.isEmpty || !address.isEmpty
    }

    func updatingAddress(_ address: String) -> CommunityStore {
        CommunityStore(
            id: id,
            category: category,
            name: name,
            address: address,
            close: close,
            storeImageURLs: storeImageURLs,
            isPicchelin: isPicchelin,
            isPick: isPick,
            pickCount: pickCount,
            hashTags: hashTags,
            totalRating: totalRating,
            totalOrderCount: totalOrderCount,
            totalReviewCount: totalReviewCount,
            geolocation: geolocation,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension CommunityPostCreator {
    var resolvedProfileImageURL: URL? {
        APIURLResolver.resolve(path: profileImage)
    }
}
