//
//  CommunityViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Combine
import Foundation

@MainActor
final class CommunityViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var posts: [CommunityPost] = []

    let request = CommunityPostListRequest(
        longitude: 127.049914,
        latitude: 37.654215,
        nextCursor: nil,
        limit: 10
    )

    private let service: any CommunityServicing
    private let storeDetailService: any StoreDetailServicing
    private var hasLoaded = false

    init(
        service: any CommunityServicing = CommunityService(),
        storeDetailService: any StoreDetailServicing = StoreDetailService()
    ) {
        self.service = service
        self.storeDetailService = storeDetailService
    }

    func load(accessToken: String) async throws {
        guard !hasLoaded else { return }

        viewState = .loading

        do {
            let response = try await service.fetchGeolocationPosts(
                request: request,
                accessToken: accessToken
            )
            posts = await enrichPostsWithStoreAddresses(response.data, accessToken: accessToken)
            hasLoaded = true
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
            throw error
        }
    }

    func retry(accessToken: String) async throws {
        hasLoaded = false
        posts = []
        try await load(accessToken: accessToken)
    }

    private func enrichPostsWithStoreAddresses(
        _ posts: [CommunityPost],
        accessToken: String
    ) async -> [CommunityPost] {
        let storeDetailService = self.storeDetailService
        let unresolvedStoreIDs = Set<String>(
            posts.compactMap { post in
                guard !post.store.id.isEmpty, post.store.address.isEmpty else { return nil }
                return post.store.id
            }
        )

        guard !unresolvedStoreIDs.isEmpty else { return posts }

        let resolvedAddresses = await withTaskGroup(of: (String, String?).self) { group in
            for storeID in unresolvedStoreIDs {
                group.addTask {
                    do {
                        let detail = try await storeDetailService.fetchStoreDetail(
                            storeID: storeID,
                            accessToken: accessToken
                        )
                        return (storeID, detail.address)
                    } catch {
                        print("Failed to resolve community store address for \(storeID): \(error.localizedDescription)")
                        return (storeID, nil)
                    }
                }
            }

            var addresses: [String: String] = [:]
            for await (storeID, address) in group {
                if let address, !address.isEmpty {
                    addresses[storeID] = address
                }
            }
            return addresses
        }

        return posts.map { post in
            guard
                !post.store.id.isEmpty,
                post.store.address.isEmpty,
                let address = resolvedAddresses[post.store.id]
            else {
                return post
            }

            return post.updatingStore(address: address)
        }
    }
}
