//
//  VideoModels.swift
//  LSLP-iOS
//

import Foundation

// MARK: - List

struct VideoListResponse: Decodable, Sendable {
    let data: [VideoItem]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

struct VideoItem: Decodable, Identifiable, Sendable {
    let videoID: String
    let title: String
    let description: String
    let thumbnailURL: String
    let duration: Double
    let creator: VideoCreator
    let likeCount: Int
    let viewCount: Int
    let isLike: Bool
    let createdAt: String?

    var id: String { videoID }

    enum CodingKeys: String, CodingKey {
        case videoID = "id"
        case title
        case description
        case thumbnailURL = "thumbnail_url"
        case duration
        case creator
        case likeCount = "like_count"
        case viewCount = "view_count"
        case isLike = "is_liked"
        case createdAt
    }

    init(
        videoID: String,
        title: String,
        description: String,
        thumbnailURL: String,
        duration: Double,
        creator: VideoCreator,
        likeCount: Int,
        viewCount: Int,
        isLike: Bool,
        createdAt: String?
    ) {
        self.videoID = videoID
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.creator = creator
        self.likeCount = likeCount
        self.viewCount = viewCount
        self.isLike = isLike
        self.createdAt = createdAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        videoID = try c.decode(String.self, forKey: .videoID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        creator = try c.decodeIfPresent(VideoCreator.self, forKey: .creator) ?? .empty
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        viewCount = try c.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        isLike = try c.decodeIfPresent(Bool.self, forKey: .isLike) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    func updatingLike(isLike: Bool, likeCount: Int) -> VideoItem {
        VideoItem(
            videoID: videoID, title: title, description: description,
            thumbnailURL: thumbnailURL, duration: duration, creator: creator,
            likeCount: likeCount, viewCount: viewCount, isLike: isLike,
            createdAt: createdAt
        )
    }
}

struct VideoCreator: Decodable, Sendable, Equatable {
    let userID: String
    let nick: String
    let profileImage: String

    static let empty = VideoCreator(userID: "", nick: "", profileImage: "")

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
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decodeIfPresent(String.self, forKey: .userID) ?? ""
        nick = try c.decodeIfPresent(String.self, forKey: .nick) ?? ""
        profileImage = try c.decodeIfPresent(String.self, forKey: .profileImage) ?? ""
    }
}

// MARK: - Stream

struct VideoStreamResponse: Decodable, Sendable, Equatable {
    let streamURL: String
    let qualities: [VideoQuality]
    let subtitles: [VideoSubtitle]

    enum CodingKeys: String, CodingKey {
        case streamURL = "stream_url"
        case qualities
        case subtitles
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamURL = try c.decode(String.self, forKey: .streamURL)
        // qualities/subtitles 디코딩 실패 시 stream_url 재생은 유지
        qualities = (try? c.decodeIfPresent([VideoQuality].self, forKey: .qualities)) ?? []
        subtitles = (try? c.decodeIfPresent([VideoSubtitle].self, forKey: .subtitles)) ?? []
    }
}

struct VideoQuality: Decodable, Identifiable, Sendable, Hashable {
    let label: String
    let url: String

    var id: String { label }

    enum CodingKeys: String, CodingKey {
        case label = "quality"
        case url
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        url = try c.decode(String.self, forKey: .url)
    }
}

struct VideoSubtitle: Decodable, Identifiable, Sendable, Hashable {
    let language: String
    let label: String
    let url: String

    var id: String { language }

    var displayName: String {
        Locale.current.localizedString(forLanguageCode: language) ?? label
    }

    enum CodingKeys: String, CodingKey {
        case language, label, url
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        url = try c.decode(String.self, forKey: .url)
    }
}

// MARK: - Like

struct VideoLikeResponse: Decodable, Sendable {
    let likeStatus: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
        case likeCount = "like_count"
    }
}

// MARK: - Extensions

extension VideoItem {
    var resolvedThumbnailURL: URL? {
        APIURLResolver.resolve(path: thumbnailURL)
    }

    var durationLabel: String {
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var relativeCreatedText: String {
        guard let createdAt, let date = ISO8601DateFormatter().date(from: createdAt) else { return "방금 전" }
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return "방금 전" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86_400 { return "\(seconds / 3600)시간 전" }
        if seconds < 604_800 { return "\(seconds / 86_400)일 전" }
        return "\(seconds / 604_800)주 전"
    }
}

extension VideoCreator {
    var resolvedProfileImageURL: URL? {
        APIURLResolver.resolve(path: profileImage)
    }
}
