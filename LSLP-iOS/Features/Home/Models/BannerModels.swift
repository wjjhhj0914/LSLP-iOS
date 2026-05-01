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
        if imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://") {
            return URL(string: imageURL)
        }

        guard let baseURL = URL(string: APIKey.BASE_URL), let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = host
        components.port = baseURL.port
        components.path = imageURL.hasPrefix("/") ? imageURL : "/" + imageURL
        return components.url
    }

    var resolvedPayloadURL: URL? {
        if payload.value.hasPrefix("http://") || payload.value.hasPrefix("https://") {
            return URL(string: payload.value)
        }

        guard let baseURL = URL(string: APIKey.BASE_URL), let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = host
        components.port = baseURL.port
        components.path = payload.value.hasPrefix("/") ? payload.value : "/" + payload.value
        return components.url
    }
}
