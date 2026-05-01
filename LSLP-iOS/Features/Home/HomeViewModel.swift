//
//  HomeViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var stores: [StoreSummary] = []
    @Published private(set) var popularStores: [StoreSummary] = []
    @Published private(set) var banners: [MainBanner] = []
    @Published private(set) var isLoadingMore = false

    private let storeService: any StoreServicing
    private let bannerService: any BannerServicing
    private let defaultRequest = StoreListRequest(
        longitude: 127.049914,
        latitude: 37.654215,
        maxDistance: 3000,
        limit: 10,
        orderBy: "distance"
    )

    private var nextCursor: String?
    private var hasLoadedInitialPage = false
    private var reachedLastPage = false

    init(
        storeService: any StoreServicing = StoreService(),
        bannerService: any BannerServicing = BannerService()
    ) {
        self.storeService = storeService
        self.bannerService = bannerService
    }

    func loadInitialStores(accessToken: String) async throws {
        guard !hasLoadedInitialPage else { return }

        viewState = .loading
        hasLoadedInitialPage = true
        reachedLastPage = false
        nextCursor = nil

        do {
            let response = try await storeService.fetchStores(
                request: defaultRequest,
                accessToken: accessToken
            )

            stores = response.data
            popularStores = []
            banners = []
            nextCursor = response.nextCursor
            reachedLastPage = response.nextCursor == "0"
            viewState = .loaded

            do {
                popularStores = try await storeService.fetchPopularStores(
                    category: nil,
                    accessToken: accessToken
                )
            } catch {
                popularStores = []
                print("Failed to load popular stores: \(error.localizedDescription)")
            }

            do {
                banners = try await bannerService.fetchMainBanners(accessToken: accessToken)
            } catch {
                banners = []
                print("Failed to load main banners: \(error.localizedDescription)")
            }
        } catch {
            hasLoadedInitialPage = false
            viewState = .error(error.localizedDescription)
            throw error
        }
    }

    func retry(accessToken: String) async throws {
        hasLoadedInitialPage = false
        stores = []
        popularStores = []
        banners = []
        try await loadInitialStores(accessToken: accessToken)
    }

    func loadMoreIfNeeded(currentItem: StoreSummary, accessToken: String) async throws {
        guard shouldLoadMore(after: currentItem) else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let response = try await storeService.fetchStores(
            request: StoreListRequest(
                category: defaultRequest.category,
                longitude: defaultRequest.longitude,
                latitude: defaultRequest.latitude,
                maxDistance: defaultRequest.maxDistance,
                next: nextCursor,
                limit: defaultRequest.limit,
                orderBy: defaultRequest.orderBy
            ),
            accessToken: accessToken
        )

        stores.append(contentsOf: response.data)
        nextCursor = response.nextCursor
        reachedLastPage = response.nextCursor == "0"
    }

    private func shouldLoadMore(after currentItem: StoreSummary) -> Bool {
        guard !stores.isEmpty else { return false }
        guard !isLoadingMore else { return false }
        guard !reachedLastPage else { return false }
        guard let nextCursor, !nextCursor.isEmpty else { return false }

        let thresholdIndex = max(stores.count - 3, 0)
        return stores.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex
    }
}
