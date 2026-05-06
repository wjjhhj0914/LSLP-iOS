//
//  StoreDetailModels.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Foundation

struct StoreDetail: Decodable, Identifiable, Sendable, Equatable {
    let storeID: String
    let category: String
    let name: String
    let description: String
    let hashTags: [String]
    let open: String
    let close: String
    let address: String
    let estimatedPickupTime: Int
    let parkingGuide: String
    let storeImageURLs: [String]
    let isPicchelin: Bool
    var isPick: Bool
    var pickCount: Int
    let totalReviewCount: Int
    let totalOrderCount: Int
    let totalRating: Double
    let creator: StoreCreator
    let geolocation: StoreGeolocation
    let menuList: [StoreMenu]
    let createdAt: String?
    let updatedAt: String?

    var id: String { storeID }

    enum CodingKeys: String, CodingKey {
        case storeID = "store_id"
        case category
        case name
        case description
        case hashTags
        case open
        case close
        case address
        case estimatedPickupTime = "estimated_pickup_time"
        case parkingGuide = "parking_guide"
        case storeImageURLs = "store_image_urls"
        case isPicchelin = "is_picchelin"
        case isPick = "is_pick"
        case pickCount = "pick_count"
        case totalReviewCount = "total_review_count"
        case totalOrderCount = "total_order_count"
        case totalRating = "total_rating"
        case creator
        case geolocation
        case menuList = "menu_list"
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        storeID = try container.decode(String.self, forKey: .storeID)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
        open = try container.decodeIfPresent(String.self, forKey: .open) ?? "-"
        close = try container.decodeIfPresent(String.self, forKey: .close) ?? "-"
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        estimatedPickupTime = try container.decodeIfPresent(Int.self, forKey: .estimatedPickupTime) ?? 0
        parkingGuide = try container.decodeIfPresent(String.self, forKey: .parkingGuide) ?? ""
        storeImageURLs = try container.decodeIfPresent([String].self, forKey: .storeImageURLs) ?? []
        isPicchelin = try container.decodeIfPresent(Bool.self, forKey: .isPicchelin) ?? false
        isPick = try container.decodeIfPresent(Bool.self, forKey: .isPick) ?? false
        pickCount = try container.decodeIfPresent(Int.self, forKey: .pickCount) ?? 0
        totalReviewCount = try container.decodeIfPresent(Int.self, forKey: .totalReviewCount) ?? 0
        totalOrderCount = try container.decodeIfPresent(Int.self, forKey: .totalOrderCount) ?? 0
        totalRating = try container.decodeIfPresent(Double.self, forKey: .totalRating) ?? 0
        creator = try container.decodeIfPresent(StoreCreator.self, forKey: .creator) ?? .empty
        geolocation = try container.decodeIfPresent(StoreGeolocation.self, forKey: .geolocation) ?? .empty
        menuList = try container.decodeIfPresent([StoreMenu].self, forKey: .menuList) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct StoreCreator: Decodable, Sendable, Equatable {
    let userID: String
    let nick: String
    let profileImage: String

    static let empty = StoreCreator(userID: "", nick: "", profileImage: "")

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case profileImage
    }
}

struct StoreMenu: Decodable, Identifiable, Sendable, Equatable {
    let menuID: String
    let storeID: String
    let category: String
    let name: String
    let description: String
    let originInformation: String
    let price: Int
    let isSoldOut: Bool
    let tags: [String]
    let menuImageURL: String
    let createdAt: String?
    let updatedAt: String?

    var id: String { menuID }

    enum CodingKeys: String, CodingKey {
        case menuID = "menu_id"
        case storeID = "store_id"
        case category
        case name
        case description
        case originInformation = "origin_information"
        case price
        case isSoldOut = "is_sold_out"
        case tags
        case menuImageURL = "menu_image_url"
        case createdAt
        case updatedAt
    }
}

struct StoreLikeResponse: Decodable, Sendable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

struct CreateOrderRequest: Encodable, Sendable {
    let storeID: String
    let orderMenuList: [CreateOrderMenuItem]
    let totalPrice: Int

    enum CodingKeys: String, CodingKey {
        case storeID = "store_id"
        case orderMenuList = "order_menu_list"
        case totalPrice = "total_price"
    }
}

struct CreateOrderMenuItem: Encodable, Sendable {
    let menuID: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case menuID = "menu_id"
        case quantity
    }
}

struct CreatedOrder: Decodable, Identifiable, Sendable, Equatable {
    let orderID: String
    let orderCode: String
    let totalPrice: Int
    let createdAt: String?
    let updatedAt: String?

    var id: String { orderID }

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case orderCode = "order_code"
        case totalPrice = "total_price"
        case createdAt
        case updatedAt
    }
}

struct PaymentValidationRequest: Encodable, Sendable {
    let impUID: String

    enum CodingKeys: String, CodingKey {
        case impUID = "imp_uid"
    }
}

struct PaymentValidationResponse: Decodable, Sendable, Equatable {
    let paymentID: String?
    let orderItem: ValidatedOrderItem?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case paymentID = "payment_id"
        case orderItem = "order_item"
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paymentID = try container.decodeIfPresent(String.self, forKey: .paymentID)
        orderItem = try container.decodeIfPresent(ValidatedOrderItem.self, forKey: .orderItem)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct ValidatedOrderItem: Decodable, Sendable, Equatable, Identifiable {
    let orderID: String
    let orderCode: String
    let totalPrice: Int
    let store: ValidatedOrderStore?
    let orderMenuList: [ValidatedOrderMenuEntry]
    let currentOrderStatus: String?
    let orderStatusTimeline: [ValidatedOrderStatusEntry]
    let paidAt: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { orderID }

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case orderCode = "order_code"
        case totalPrice = "total_price"
        case store
        case orderMenuList = "order_menu_list"
        case currentOrderStatus = "current_order_status"
        case orderStatusTimeline = "order_status_timeline"
        case paidAt
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try container.decode(String.self, forKey: .orderID)
        orderCode = try container.decode(String.self, forKey: .orderCode)
        totalPrice = try container.decodeIfPresent(Int.self, forKey: .totalPrice) ?? 0
        store = try container.decodeIfPresent(ValidatedOrderStore.self, forKey: .store)
        orderMenuList = try container.decodeIfPresent([ValidatedOrderMenuEntry].self, forKey: .orderMenuList) ?? []
        currentOrderStatus = try container.decodeIfPresent(String.self, forKey: .currentOrderStatus)
        orderStatusTimeline = try container.decodeIfPresent([ValidatedOrderStatusEntry].self, forKey: .orderStatusTimeline) ?? []
        paidAt = try container.decodeIfPresent(String.self, forKey: .paidAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct ValidatedOrderStore: Decodable, Sendable, Equatable {
    let id: String
    let category: String?
    let name: String
    let close: String?
    let storeImageURLs: [String]
    let hashTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case name
        case close
        case storeImageURLs = "store_image_urls"
        case hashTags = "hashTags"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        close = try container.decodeIfPresent(String.self, forKey: .close)
        storeImageURLs = try container.decodeIfPresent([String].self, forKey: .storeImageURLs) ?? []
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
    }
}

struct ValidatedOrderMenuEntry: Decodable, Sendable, Equatable, Identifiable {
    let menu: ValidatedOrderMenu
    let quantity: Int

    var id: String { menu.id }
}

struct ValidatedOrderMenu: Decodable, Sendable, Equatable {
    let id: String
    let category: String?
    let name: String
    let description: String?
    let originInformation: String?
    let price: Int
    let tags: [String]
    let menuImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case name
        case description
        case originInformation = "origin_information"
        case price
        case tags
        case menuImageURL = "menu_image_url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        originInformation = try container.decodeIfPresent(String.self, forKey: .originInformation)
        price = try container.decodeIfPresent(Int.self, forKey: .price) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        menuImageURL = try container.decodeIfPresent(String.self, forKey: .menuImageURL)
    }
}

struct ValidatedOrderStatusEntry: Decodable, Sendable, Equatable, Identifiable {
    let status: String
    let completed: Bool
    let changedAt: String?

    var id: String { status }
}

extension StoreDetail {
    var resolvedImageURLs: [URL] {
        storeImageURLs.compactMap { APIURLResolver.resolve(path: $0) }
    }

    var formattedRating: String {
        String(format: "%.1f", totalRating)
    }

    var formattedOperatingHours: String {
        "매일 \(open.formattedHourLabel(amSpacing: false)) ~ \(close.formattedHourLabel(amSpacing: true))"
    }

    var estimatedPickupLabel: String {
        "예상 소요시간 \(estimatedPickupTime)분"
    }

    var popularMenus: [StoreMenu] {
        menuList.filter { menu in
            menu.tags.contains { $0.contains("인기") }
        }
    }
}

extension ValidatedOrderItem {
    var totalCount: Int {
        orderMenuList.reduce(0) { $0 + $1.quantity }
    }
}

extension ValidatedOrderStore {
    var resolvedImageURL: URL? {
        storeImageURLs.first.flatMap { APIURLResolver.resolve(path: $0) }
    }
}

extension ValidatedOrderMenu {
    var resolvedImageURL: URL? {
        menuImageURL.flatMap { APIURLResolver.resolve(path: $0) }
    }
}

private extension String {
    func formattedHourLabel(amSpacing: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"

        guard let date = formatter.date(from: self) else { return self }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = amSpacing ? "h:mm a" : "h:mma"
        return outputFormatter.string(from: date)
    }
}

extension StoreMenu {
    var resolvedImageURL: URL? {
        APIURLResolver.resolve(path: menuImageURL)
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = NSNumber(value: price)
        return "\(formatter.string(from: number) ?? "\(price)")원"
    }
}
