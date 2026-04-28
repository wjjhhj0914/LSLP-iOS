//
//  StoreModels.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import Foundation

struct StoreListRequest: Sendable {
    let category: String?
    let longitude: Double
    let latitude: Double
    let maxDistance: Double
    let next: String?
    let limit: Int
    let orderBy: String

    init(
        category: String? = nil,
        longitude: Double,
        latitude: Double,
        maxDistance: Double = 3000,
        next: String? = nil,
        limit: Int = 10,
        orderBy: String = "distance"
    ) {
        self.category = category
        self.longitude = longitude
        self.latitude = latitude
        self.maxDistance = maxDistance
        self.next = next
        self.limit = limit
        self.orderBy = orderBy
    }
}

struct StoreListResponse: Decodable, Sendable {
    let data: [StoreSummary]
    let nextCursor: String

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

struct StoreSummary: Decodable, Identifiable, Sendable, Equatable {
    let storeID: String
    let category: String
    let name: String
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
    let distance: Double
    let createdAt: String?
    let updatedAt: String?

    var id: String { storeID }

    enum CodingKeys: String, CodingKey {
        case storeID = "store_id"
        case category
        case name
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
        case distance
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        storeID = try container.decode(String.self, forKey: .storeID)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        close = try container.decodeIfPresent(String.self, forKey: .close) ?? "-"
        storeImageURLs = try container.decodeIfPresent([String].self, forKey: .storeImageURLs) ?? []
        isPicchelin = try container.decodeIfPresent(Bool.self, forKey: .isPicchelin) ?? false
        isPick = try container.decodeIfPresent(Bool.self, forKey: .isPick) ?? false
        pickCount = try container.decodeIfPresent(Int.self, forKey: .pickCount) ?? 0
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
        totalRating = try container.decodeIfPresent(Double.self, forKey: .totalRating) ?? 0
        totalOrderCount = try container.decodeIfPresent(Int.self, forKey: .totalOrderCount) ?? 0
        totalReviewCount = try container.decodeIfPresent(Int.self, forKey: .totalReviewCount) ?? 0
        geolocation = try container.decodeIfPresent(StoreGeolocation.self, forKey: .geolocation) ?? .empty
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct StoreGeolocation: Decodable, Sendable, Equatable {
    let longitude: Double
    let latitude: Double

    static let empty = StoreGeolocation(longitude: 0, latitude: 0)
}

extension StoreSummary {
    var primaryImageURL: URL? {
        guard let firstImagePath = storeImageURLs.first, !firstImagePath.isEmpty else {
            return nil
        }

        if firstImagePath.hasPrefix("http://") || firstImagePath.hasPrefix("https://") {
            return URL(string: firstImagePath)
        }

        guard let baseURL = URL(string: APIKey.BASE_URL), let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = host
        components.port = baseURL.port
        components.path = firstImagePath.hasPrefix("/") ? firstImagePath : "/" + firstImagePath
        return components.url
    }

    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance.rounded()))m"
        }

        return String(format: "%.1fkm", distance / 1000)
    }
}
