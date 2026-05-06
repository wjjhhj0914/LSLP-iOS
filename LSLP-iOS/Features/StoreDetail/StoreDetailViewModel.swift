//
//  StoreDetailViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Combine
import Foundation

@MainActor
final class StoreDetailViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var detail: StoreDetail?
    @Published var selectedMenuTab: MenuTab = .all
    @Published private(set) var isSubmittingLike = false
    @Published private(set) var selectedQuantities: [String: Int] = [:]
    @Published private(set) var isSubmittingOrder = false

    enum MenuTab: String, CaseIterable, Identifiable {
        case all = "전체 메뉴"
        case popular = "인기메뉴"

        var id: String { rawValue }
    }

    private let service: any StoreDetailServicing
    private let storeID: String

    init(
        storeID: String,
        service: any StoreDetailServicing = StoreDetailService()
    ) {
        self.storeID = storeID
        self.service = service
    }

    var visibleMenus: [StoreMenu] {
        guard let detail else { return [] }

        switch selectedMenuTab {
        case .all:
            return detail.menuList
        case .popular:
            return detail.popularMenus.isEmpty ? detail.menuList : detail.popularMenus
        }
    }

    var totalSelectedCount: Int {
        selectedQuantities.values.reduce(0, +)
    }

    var totalSelectedPrice: Int {
        guard let detail else { return 0 }

        return detail.menuList.reduce(into: 0) { partialResult, menu in
            partialResult += menu.price * quantity(for: menu)
        }
    }

    var currentOrderName: String {
        guard let detail else { return "주문 상품" }

        let selectedMenus = detail.menuList.filter { quantity(for: $0) > 0 }
        guard let firstMenu = selectedMenus.first else { return "주문 상품" }
        if selectedMenus.count == 1 {
            return firstMenu.name
        }
        return "\(firstMenu.name) 외 \(selectedMenus.count - 1)건"
    }

    func load(accessToken: String) async throws {
        viewState = .loading

        do {
            detail = try await service.fetchStoreDetail(storeID: storeID, accessToken: accessToken)
            selectedQuantities = selectedQuantities.filter { key, value in
                detail?.menuList.contains(where: { $0.menuID == key && !$0.isSoldOut }) == true && value > 0
            }
            viewState = .loaded
        } catch {
            viewState = .error(error.localizedDescription)
            throw error
        }
    }

    func toggleLike(accessToken: String) async throws {
        guard !isSubmittingLike else { return }
        guard var detail else { return }

        isSubmittingLike = true
        defer { isSubmittingLike = false }

        let previousStatus = detail.isPick
        let response = try await service.toggleLike(storeID: storeID, accessToken: accessToken)

        detail.isPick = response.likeStatus
        if response.likeStatus != previousStatus {
            detail.pickCount += response.likeStatus ? 1 : -1
            detail.pickCount = max(detail.pickCount, 0)
        }
        self.detail = detail
    }

    func quantity(for menu: StoreMenu) -> Int {
        selectedQuantities[menu.menuID] ?? 0
    }

    func selectMenu(_ menu: StoreMenu) {
        guard !menu.isSoldOut else { return }
        guard quantity(for: menu) == 0 else { return }
        selectedQuantities[menu.menuID] = 1
    }

    func incrementQuantity(for menu: StoreMenu) {
        guard !menu.isSoldOut else { return }
        selectedQuantities[menu.menuID] = quantity(for: menu) + 1
    }

    func decrementQuantity(for menu: StoreMenu) {
        let nextQuantity = quantity(for: menu) - 1
        if nextQuantity <= 0 {
            selectedQuantities.removeValue(forKey: menu.menuID)
        } else {
            selectedQuantities[menu.menuID] = nextQuantity
        }
    }

    func createOrder(accessToken: String) async throws -> CreatedOrder {
        guard !isSubmittingOrder else {
            throw StoreDetailServiceError.emptyOrder
        }
        guard let detail else {
            throw StoreDetailServiceError.invalidResponse
        }

        let selectedItems = detail.menuList.compactMap { menu -> CreateOrderMenuItem? in
            let quantity = quantity(for: menu)
            guard quantity > 0, !menu.isSoldOut else { return nil }
            return CreateOrderMenuItem(menuID: menu.menuID, quantity: quantity)
        }

        guard !selectedItems.isEmpty else {
            throw StoreDetailServiceError.emptyOrder
        }

        isSubmittingOrder = true
        defer { isSubmittingOrder = false }

        let order = try await service.createOrder(
            payload: CreateOrderRequest(
                storeID: detail.storeID,
                orderMenuList: selectedItems,
                totalPrice: totalSelectedPrice
            ),
            accessToken: accessToken
        )
        return order
    }

    func validatePayment(
        impUID: String,
        merchantUID: String,
        accessToken: String
    ) async throws -> PaymentValidationResponse {
        let response = try await service.validatePayment(
            impUID: impUID,
            merchantUID: merchantUID,
            accessToken: accessToken
        )
        selectedQuantities.removeAll()
        return response
    }
}
