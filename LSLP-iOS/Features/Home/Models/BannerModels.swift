//
//  BannerModels.swift
//  LSLP-iOS
//
//  Created by Codex on 4/29/26.
//

import Foundation

struct MainBannerResponse: Decodable, Sendable {
    let data: [MainBanner]
}

struct MainBanner: Decodable, Identifiable, Sendable, Equatable {
    let name: String
    let imageURL: String
    let payload: BannerPayload

    var id: String {
        "\(name)-\(imageURL)"
    }

    enum CodingKeys: String, CodingKey {
        case name
        case imageURL = "imageUrl"
        case payload
    }
}

struct BannerPayload: Decodable, Sendable, Equatable {
    let type: String
    let value: String
}

extension MainBanner {
    var resolvedImageURL: URL? {
        APIURLResolver.resolve(path: imageURL)
    }

    var resolvedPayloadURL: URL? {
        APIURLResolver.resolve(path: payload.value)
    }
}
