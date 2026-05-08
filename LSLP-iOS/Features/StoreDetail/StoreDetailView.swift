//
//  StoreDetailView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Combine
import SwiftUI

struct StoreDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var appTabRouter: AppTabRouter
    @StateObject private var viewModel: StoreDetailViewModel
    @State private var pendingPaymentRequest: StorePaymentRequest?
    @State private var orderErrorMessage: String?

    init(storeID: String) {
        _viewModel = StateObject(wrappedValue: StoreDetailViewModel(storeID: storeID))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                switch viewModel.viewState {
                case .idle, .loading:
                    ProgressView("가게 정보를 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    detailContent

                case let .error(message):
                    errorView(message: message)
                }
            }

            bottomActionBar
        }
        .navigationBarBackButtonHidden()
        .task(id: authSession.state) {
            guard authSession.state == .authenticated else { return }
            await loadDetail()
        }
        .sheet(item: $pendingPaymentRequest) { request in
            StorePaymentLauncherView(request: request) { result in
                Task {
                    await handlePaymentResult(result)
                }
            }
            .ignoresSafeArea()
        }
        .alert("주문을 진행할 수 없습니다", isPresented: Binding(
            get: { orderErrorMessage != nil },
            set: { if !$0 { orderErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(orderErrorMessage ?? "")
        }
    }

    private var detailContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if let detail = viewModel.detail {
                    StoreHeroImageCarousel(
                        imageURLs: detail.resolvedImageURLs,
                        isPicked: detail.isPick,
                        onBack: { dismiss() },
                        onLike: {
                            Task {
                                await toggleLike()
                            }
                        }
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        StoreSummarySection(detail: detail)
                        StoreInfoCard(detail: detail)
                        MenuTabSection(selectedTab: $viewModel.selectedMenuTab)
                        MenuListSection(
                            menus: viewModel.visibleMenus,
                            selectedQuantities: viewModel.selectedQuantities,
                            onSelect: { menu in
                                viewModel.selectMenu(menu)
                            },
                            onIncrement: { menu in
                                viewModel.incrementQuantity(for: menu)
                            },
                            onDecrement: { menu in
                                viewModel.decrementQuantity(for: menu)
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -28)
                    .padding(.bottom, 110)
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.totalSelectedPrice > 0 ? viewModel.totalSelectedPrice.formattedPriceText : "메뉴를 선택해 주세요")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.22))

                Text(viewModel.totalSelectedCount > 0 ? "총 \(viewModel.totalSelectedCount)개 선택됨" : "상품을 탭하면 선택됩니다")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await createOrder()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.totalSelectedCount > 0 {
                        Text("\(viewModel.totalSelectedCount)")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.44))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.95))
                            .clipShape(Circle())
                    }

                    Text(viewModel.isSubmittingOrder ? "주문 중..." : "결제하기")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(
                    (viewModel.totalSelectedCount > 0 && !viewModel.isSubmittingOrder)
                        ? Color(red: 0.70, green: 0.78, blue: 0.64)
                        : Color(red: 0.82, green: 0.84, blue: 0.80)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(viewModel.totalSelectedCount == 0 || viewModel.isSubmittingOrder)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(.white)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Text("가게 상세 정보를 불러오지 못했습니다.")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await loadDetail()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadDetail() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.load(accessToken: accessToken)
        } catch let error as StoreDetailServiceError {
            switch error {
            case .accessTokenExpired:
                await refreshAndReload()
            case .unauthorized:
                await authSession.logout()
            default:
                break
            }
        } catch let error as AuthSessionError {
            print("Auth session failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch let error as AuthServiceError {
            print("Token refresh failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch {
            print("Failed to load store detail: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func toggleLike() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.toggleLike(accessToken: accessToken)
        } catch let error as StoreDetailServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    try await viewModel.toggleLike(accessToken: refreshedAccessToken)
                } catch {
                    await authSession.logout()
                }
            case .unauthorized:
                await authSession.logout()
            default:
                print("Failed to toggle like: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to toggle like: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshAndReload() async {
        do {
            let refreshedAccessToken = try await authSession.refreshAccessToken()
            try await viewModel.load(accessToken: refreshedAccessToken)
        } catch {
            await authSession.logout()
        }
    }

    @MainActor
    private func createOrder() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            let createdOrder = try await viewModel.createOrder(accessToken: accessToken)
            pendingPaymentRequest = StorePaymentRequest(
                order: createdOrder,
                orderName: viewModel.currentOrderName,
                buyerName: "새싹회원"
            )
        } catch let error as StoreDetailServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    let createdOrder = try await viewModel.createOrder(accessToken: refreshedAccessToken)
                    pendingPaymentRequest = StorePaymentRequest(
                        order: createdOrder,
                        orderName: viewModel.currentOrderName,
                        buyerName: "새싹회원"
                    )
                } catch let refreshError as LocalizedError {
                    orderErrorMessage = refreshError.errorDescription ?? "주문 생성에 실패했습니다."
                } catch {
                    orderErrorMessage = "주문 생성에 실패했습니다."
                }
            case .unauthorized:
                await authSession.logout()
            default:
                orderErrorMessage = error.localizedDescription
            }
        } catch {
            orderErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handlePaymentResult(_ result: StorePaymentResult) async {
        let currentPaymentRequest = pendingPaymentRequest
        pendingPaymentRequest = nil

        switch result {
        case let .success(impUID, merchantUID):
            guard merchantUID == currentPaymentRequest?.order.orderCode else {
                orderErrorMessage = "결제 응답의 주문번호가 생성한 주문번호와 일치하지 않습니다."
                return
            }
            await validatePayment(impUID: impUID, merchantUID: merchantUID)
        case let .failure(message):
            orderErrorMessage = message
        case .cancelled:
            orderErrorMessage = "결제가 취소되었습니다."
        }
    }

    @MainActor
    private func validatePayment(impUID: String, merchantUID: String) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            let validated = try await viewModel.validatePayment(
                impUID: impUID,
                merchantUID: merchantUID,
                accessToken: accessToken
            )
            if let orderItem = validated.orderItem {
                appTabRouter.showOrderDetail(orderItem)
                dismiss()
            } else {
                orderErrorMessage = "결제 검증 응답에 주문 정보가 없습니다."
            }
        } catch let error as StoreDetailServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshedAccessToken = try await authSession.refreshAccessToken()
                    let validated = try await viewModel.validatePayment(
                        impUID: impUID,
                        merchantUID: merchantUID,
                        accessToken: refreshedAccessToken
                    )
                    if let orderItem = validated.orderItem {
                        appTabRouter.showOrderDetail(orderItem)
                        dismiss()
                    } else {
                        orderErrorMessage = "결제 검증 응답에 주문 정보가 없습니다."
                    }
                } catch let refreshError as LocalizedError {
                    orderErrorMessage = refreshError.errorDescription ?? "결제 검증에 실패했습니다."
                } catch {
                    orderErrorMessage = "결제 검증에 실패했습니다."
                }
            case .unauthorized:
                await authSession.logout()
            default:
                orderErrorMessage = error.localizedDescription
            }
        } catch {
            orderErrorMessage = error.localizedDescription
        }
    }
}

private struct StoreHeroImageCarousel: View {
    let imageURLs: [URL]
    let isPicked: Bool
    let onBack: () -> Void
    let onLike: () -> Void

    @State private var selectedIndex = 0

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    AuthenticatedImage(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 280)

            HStack {
                CircleIconButton(systemName: "chevron.left", action: onBack)
                Spacer()
                CircleIconButton(systemName: isPicked ? "heart.fill" : "heart", action: onLike)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
    }
}

private struct StoreSummarySection: View {
    let detail: StoreDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(detail.name)
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Color(red: 0.20, green: 0.23, blue: 0.18))

                        if detail.isPicchelin {
                            Text("픽슐랭")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.52, green: 0.60, blue: 0.44))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        DetailStatItem(systemName: "heart.fill", value: "\(detail.pickCount)")
                        DetailStatItem(systemName: "star.fill", value: "\(detail.formattedRating) (\(detail.totalReviewCount))")
                        DetailStatItem(systemName: "figure.walk", value: "누적 주문 \(detail.totalOrderCount)회")
                    }
                }
                Spacer()
            }

            if !detail.description.isEmpty {
                Text(detail.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct StoreInfoCard: View {
    let detail: StoreDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoRow(icon: "location.fill", title: "가게주소", value: detail.address)
            InfoRow(icon: "clock.fill", title: "영업시간", value: detail.formattedOperatingHours)
            InfoRow(icon: "parkingsign.circle.fill", title: "주차안내", value: detail.parkingGuide)

            Text(detail.estimatedPickupLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.56, green: 0.63, blue: 0.49))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.94, green: 0.96, blue: 0.91))
                .clipShape(Capsule())

            Button("길찾기") {}
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(red: 0.70, green: 0.78, blue: 0.64))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MenuTabSection: View {
    @Binding var selectedTab: StoreDetailViewModel.MenuTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(StoreDetailViewModel.MenuTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            selectedTab == tab
                                ? Color(red: 0.46, green: 0.55, blue: 0.40)
                                : Color(red: 0.74, green: 0.76, blue: 0.74)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color(red: 0.93, green: 0.95, blue: 0.90) : .white)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.87), lineWidth: 1)
                        )
                }
            }
        }
    }
}

private struct MenuListSection: View {
    let menus: [StoreMenu]
    let selectedQuantities: [String: Int]
    let onSelect: (StoreMenu) -> Void
    let onIncrement: (StoreMenu) -> Void
    let onDecrement: (StoreMenu) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(menus.enumerated()), id: \.element.id) { index, menu in
                MenuRow(
                    menu: menu,
                    quantity: selectedQuantities[menu.menuID] ?? 0,
                    onSelect: { onSelect(menu) },
                    onIncrement: { onIncrement(menu) },
                    onDecrement: { onDecrement(menu) }
                )

                if index < menus.count - 1 {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MenuRow: View {
    let menu: StoreMenu
    let quantity: Int
    let onSelect: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                if let firstTag = menu.tags.first {
                    Text(firstTag)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.56, green: 0.63, blue: 0.49))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.94, green: 0.96, blue: 0.91))
                        .clipShape(Capsule())
                }

                Text(menu.name)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                Text(menu.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text(menu.formattedPrice)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(red: 0.20, green: 0.23, blue: 0.18))
            }

            Spacer(minLength: 10)

            ZStack {
                AuthenticatedImage(url: menu.resolvedImageURL)
                    .frame(width: 98, height: 98)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if menu.isSoldOut {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.36))

                    Text("품절")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(quantity > 0 ? Color(red: 0.97, green: 0.98, blue: 0.95) : .white)
        )
        .overlay(alignment: .bottomTrailing) {
            if menu.isSoldOut {
                EmptyView()
            } else if quantity > 0 {
                QuantityControl(
                    quantity: quantity,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            } else {
                Button("선택", action: onSelect)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.40))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.93, green: 0.95, blue: 0.90))
                    .clipShape(Capsule())
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !menu.isSoldOut {
                onSelect()
            }
        }
    }
}

private struct QuantityControl: View {
    let quantity: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDecrement) {
                Image(systemName: quantity > 1 ? "minus" : "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.40))
            }

            Text("\(quantity)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.22))
                .frame(minWidth: 18)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.55, blue: 0.40))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 0.88, green: 0.90, blue: 0.87), lineWidth: 1)
        )
    }
}

private struct DetailStatItem: View {
    let systemName: String
    let value: String

    var body: some View {
        Label(value, systemImage: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.18))
    }
}

extension Int {
    var formattedPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: self)) ?? "\(self)")원"
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.67, green: 0.74, blue: 0.60))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.25))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.28, green: 0.31, blue: 0.25))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.92))
                .clipShape(Circle())
        }
    }
}

@MainActor
private final class DetailImageLoader: ObservableObject {
    enum Phase {
        case idle
        case loading
        case success(UIImage)
        case failure
    }

    @Published private(set) var phase: Phase = .idle
    private var task: Task<Void, Never>?

    func load(url: URL?, accessToken: String?, refreshAccessToken: @escaping @Sendable () async throws -> String) {
        task?.cancel()

        guard let url else {
            phase = .failure
            return
        }

        phase = .loading

        task = Task {
            await loadAttempt(url: url, accessToken: accessToken, refreshAccessToken: refreshAccessToken)
        }
    }

    deinit {
        task?.cancel()
    }

    private func loadAttempt(
        url: URL,
        accessToken: String?,
        refreshAccessToken: @escaping @Sendable () async throws -> String
    ) async {
        do {
            try await request(url: url, accessToken: accessToken)
        } catch StoreDetailServiceError.accessTokenExpired {
            do {
                let refreshed = try await refreshAccessToken()
                try await request(url: url, accessToken: refreshed)
            } catch {
                phase = .failure
            }
        } catch {
            phase = .failure
        }
    }

    private func request(url: URL, accessToken: String?) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(APIKey.SESAC_KEY, forHTTPHeaderField: "SeSACKey")
        request.setValue("image/*", forHTTPHeaderField: "accept")
        if let accessToken, !accessToken.isEmpty {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreDetailServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 419:
            throw StoreDetailServiceError.accessTokenExpired
        default:
            throw StoreDetailServiceError.httpStatus(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8)
            )
        }

        guard let image = UIImage(data: data) else {
            phase = .failure
            return
        }

        phase = .success(image)
    }
}

struct AuthenticatedImage: View {
    @EnvironmentObject private var authSession: AuthSession
    let url: URL?

    @StateObject private var loader = DetailImageLoader()

    var body: some View {
        ZStack {
            switch loader.phase {
            case .idle, .loading:
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(red: 0.94, green: 0.96, blue: 0.91))

                ProgressView()

            case let .success(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failure:
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(red: 0.94, green: 0.96, blue: 0.91))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 0.65, green: 0.71, blue: 0.59))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
        .task(id: "\(url?.absoluteString ?? "nil")|\(authSession.accessToken ?? "nil")") {
            loader.load(
                url: url,
                accessToken: authSession.accessToken,
                refreshAccessToken: {
                    try await authSession.refreshAccessToken()
                }
            )
        }
    }
}

struct AuthenticatedCroppedImage: View {
    @EnvironmentObject private var authSession: AuthSession
    let url: URL?

    @StateObject private var loader = DetailImageLoader()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch loader.phase {
                case .idle, .loading:
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(red: 0.94, green: 0.96, blue: 0.91))

                    ProgressView()

                case let .success(image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)

                case .failure:
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(red: 0.94, green: 0.96, blue: 0.91))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(red: 0.65, green: 0.71, blue: 0.59))
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .clipped()
        }
        .task(id: "\(url?.absoluteString ?? "nil")|\(authSession.accessToken ?? "nil")") {
            loader.load(
                url: url,
                accessToken: authSession.accessToken,
                refreshAccessToken: {
                    try await authSession.refreshAccessToken()
                }
            )
        }
    }
}
