//
//  APIURLResolver.swift
//  LSLP-iOS
//
//  Created by Codex on 5/4/26.
//

import Foundation

enum APIURLResolver {
    static func resolve(path: String, baseURLString: String = APIKey.BASE_URL) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }

        guard let baseURL = URL(string: baseURLString), let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = host
        components.port = baseURL.port
        components.path = normalizedFilePath(path)
        return components.url
    }

    private static func normalizedFilePath(_ path: String) -> String {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path

        if normalizedPath.hasPrefix("/v1/") {
            return normalizedPath
        }

        if normalizedPath.hasPrefix("/data/") {
            return "/v1" + normalizedPath
        }

        return normalizedPath
    }
}
