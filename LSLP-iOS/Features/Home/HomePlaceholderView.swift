//
//  HomeView.swift
//  LSLP-iOS
//
//  Created by Codex on 4/26/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCategory = "디저트"

    private let keywords = ["인기검색어", "스타벅스"]
    private let categories = [
        HomeCategory(title: "커피", icon: "cup.and.saucer.fill"),
        HomeCategory(title: "패스트푸드", icon: "fork.knife.circle.fill"),
        HomeCategory(title: "디저트", icon: "birthday.cake.fill"),
        HomeCategory(title: "베이커리", icon: "leaf.fill"),
        HomeCategory(title: "more", icon: "figure.walk")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                switch viewModel.viewState {
                case .idle, .loading:
                    loadingView

                case .loaded:
                    homeContent

                case let .error(message):
                    errorView(message: message)
                }
            }

            HomeTabBar()
        }
        .task(id: authSession.state) {
            guard authSession.state == .authenticated else { return }
            await loadInitialStores()
        }
    }

    private var filteredStores: [StoreSummary] {
        guard selectedCategory != "more" else { return viewModel.stores }

        let normalizedCategory = selectedCategory == "커피" ? "카페" : selectedCategory
        let filtered = viewModel.stores.filter { $0.category == normalizedCategory }
        return filtered.isEmpty ? viewModel.stores : filtered
    }

    private var popularStores: [StoreSummary] {
        let normalizedCategory = selectedCategory == "커피" ? "카페" : selectedCategory
        let filteredPopularStores = viewModel.popularStores.filter {
            selectedCategory == "more" || $0.category == normalizedCategory
        }

        if !filteredPopularStores.isEmpty {
            return Array(filteredPopularStores.prefix(5))
        }

        return Array(filteredStores.prefix(5))
    }

    private var pickStores: [StoreSummary] {
        filteredStores
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("메인 홈을 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                categorySection
                popularSection
                bannerSection
                pickSection
            }
            .padding(.bottom, 120)
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(red: 0.93, green: 0.95, blue: 0.89))
                .frame(height: 188)
                .overlay(alignment: .top) {
                    VStack(spacing: 18) {
                        HStack(spacing: 10) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color(red: 0.39, green: 0.44, blue: 0.34))

                            Text("문래역, 영등포구")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.16))

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.33))

                            Spacer()

                            Button {
                                Task {
                                    await authSession.logout()
                                }
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.33))
                                    .padding(10)
                                    .background(.white.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }

                        SearchBarView()

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.74, green: 0.82, blue: 0.65))

                            ForEach(Array(keywords.enumerated()), id: \.offset) { index, keyword in
                                Text(keyword)
                                    .font(.system(size: 13, weight: index == 0 ? .regular : .semibold))
                                    .foregroundStyle(index == 0 ? Color(red: 0.73, green: 0.79, blue: 0.67) : Color(red: 0.49, green: 0.59, blue: 0.44))

                                if index < keywords.count - 1 {
                                    Text("|")
                                        .foregroundStyle(Color(red: 0.79, green: 0.83, blue: 0.76))
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
        }
    }

    private var categorySection: some View {
        VStack(spacing: 18) {
            categoryRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .padding(.horizontal, 6)
        .offset(y: -18)
        .padding(.bottom, -10)
    }

    private var categoryRow: some View {
        HStack(spacing: 12) {
            ForEach(categories) { category in
                Button {
                    selectedCategory = category.title
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 54, height: 46)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            selectedCategory == category.title
                                                ? Color(red: 0.60, green: 0.68, blue: 0.52)
                                                : Color(red: 0.90, green: 0.90, blue: 0.90),
                                            lineWidth: selectedCategory == category.title ? 1.5 : 1
                                        )
                                )

                            Image(systemName: category.icon)
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(category.iconColor)
                        }

                        Text(category.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedCategory == category.title ? Color(red: 0.41, green: 0.47, blue: 0.33) : Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView(title: "실시간 인기 맛집")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(popularStores) { store in
                        CompactStoreCardView(store: store)
                            .frame(width: 250)
                            .onAppear {
                                Task {
                                    await loadMoreIfNeeded(currentItem: store)
                                }
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }
        }
        .padding(.top, 8)
    }

    private var bannerSection: some View {
        PromoBannerView()
            .padding(.horizontal, 24)
            .padding(.top, 18)
    }

    private var pickSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("내가 픽업 가게")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color(red: 0.19, green: 0.22, blue: 0.17))

                Spacer()

                Label("거리순", systemImage: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.43, green: 0.49, blue: 0.39))
            }
            .padding(.horizontal, 24)

            HStack(spacing: 8) {
                FeaturePill(title: "픽슐랭", isActive: true)
                FeaturePill(title: "My Pick", isActive: false)
            }
            .padding(.horizontal, 24)

            LazyVStack(spacing: 18) {
                ForEach(pickStores) { store in
                    FeaturedStoreCardView(store: store)
                        .padding(.horizontal, 24)
                        .onAppear {
                            Task {
                                await loadMoreIfNeeded(currentItem: store)
                            }
                        }
                }
            }
        }
        .padding(.top, 22)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text("가게 목록을 불러오지 못했습니다.")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await retryLoad()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadInitialStores() async {
        await performStoreRequest { accessToken in
            try await viewModel.loadInitialStores(accessToken: accessToken)
        }
    }

    @MainActor
    private func retryLoad() async {
        await performStoreRequest { accessToken in
            try await viewModel.retry(accessToken: accessToken)
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentItem: StoreSummary) async {
        await performStoreRequest { accessToken in
            try await viewModel.loadMoreIfNeeded(currentItem: currentItem, accessToken: accessToken)
        }
    }

    @MainActor
    private func performStoreRequest(_ operation: @escaping (String) async throws -> Void) async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await operation(accessToken)
        } catch let error as StoreServiceError {
            switch error {
            case .accessTokenExpired:
                await refreshAndRetry(operation)
            case .unauthorized:
                await authSession.logout()
            default:
                print("Store request failed: \(error.localizedDescription)")
            }
        } catch let error as AuthSessionError {
            print("Auth session failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch let error as AuthServiceError {
            print("Token refresh failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch {
            print("Failed to perform store request: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshAndRetry(_ operation: @escaping (String) async throws -> Void) async {
        do {
            let refreshedAccessToken = try await authSession.refreshAccessToken()
            try await operation(refreshedAccessToken)
        } catch let error as StoreServiceError {
            print("Retried store request failed: \(error.localizedDescription)")
            if case .unauthorized = error {
                await authSession.logout()
            }
        } catch let error as AuthServiceError {
            print("Token refresh failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch let error as AuthSessionError {
            print("Auth session failed: \(error.localizedDescription)")
            await authSession.logout()
        } catch {
            print("Failed to retry store request: \(error.localizedDescription)")
        }
    }
}

private struct SearchBarView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 0.60, green: 0.66, blue: 0.56))

            Text("검색어를 입력해주세요.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.66, green: 0.70, blue: 0.61))

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 0.83, green: 0.85, blue: 0.80), lineWidth: 1)
        )
    }
}

private struct HomeCategory: Identifiable {
    let title: String
    let icon: String

    var id: String { title }

    var iconColor: Color {
        switch title {
        case "커피":
            return Color(red: 0.67, green: 0.64, blue: 0.52)
        case "패스트푸드":
            return Color(red: 0.88, green: 0.65, blue: 0.09)
        case "디저트":
            return Color(red: 0.98, green: 0.71, blue: 0.22)
        case "베이커리":
            return Color(red: 0.83, green: 0.67, blue: 0.39)
        default:
            return Color(red: 0.56, green: 0.61, blue: 0.50)
        }
    }
}

private struct SectionTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 23, weight: .heavy))
            .foregroundStyle(Color(red: 0.19, green: 0.22, blue: 0.17))
            .padding(.horizontal, 24)
    }
}

private struct CompactStoreCardView: View {
    let store: StoreSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteStoreImageView(store: store, cornerRadius: 18)
                    .frame(height: 164)

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.61, green: 0.72, blue: 0.52))
                    )
                    .padding(12)

                if store.isPicchelin {
                    Text("픽슐랭")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.52, green: 0.60, blue: 0.44).opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(store.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.20))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Label("\(store.pickCount)개", systemImage: "heart.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.97, green: 0.71, blue: 0.18))
                }

                HStack(spacing: 16) {
                    MetaItem(icon: "paperplane.fill", value: store.formattedDistance)
                    MetaItem(icon: "clock.fill", value: store.close)
                    MetaItem(icon: "figure.run", value: "\(store.totalOrderCount)회")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

private struct PromoBannerView: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.96, blue: 0.89),
                            Color(red: 0.92, green: 0.93, blue: 0.84)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 108)

            VStack(alignment: .leading, spacing: 10) {
                Text("선택하면 처음 시작된다")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.73, green: 0.78, blue: 0.69))

                Text("피자부터 커피까지\n픽업하면 0원")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color(red: 0.66, green: 0.73, blue: 0.59))
                    .lineSpacing(2)
            }
            .padding(.leading, 22)

            HStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.74, blue: 0.22))
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.orange.opacity(0.18), radius: 8, x: 0, y: 5)

                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)

                    Text("ONLY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.54, green: 0.61, blue: 0.45))
                        .clipShape(Capsule())
                        .rotationEffect(.degrees(-16))
                        .offset(x: -34, y: -10)
                }
                .padding(.trailing, 22)
            }

            Text("1/12")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 12)
        }
    }
}

private struct FeaturePill: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isActive ? Color(red: 0.44, green: 0.52, blue: 0.36) : Color(red: 0.78, green: 0.80, blue: 0.76))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? Color(red: 0.91, green: 0.94, blue: 0.87) : Color(red: 0.97, green: 0.97, blue: 0.97))
            )
    }
}

private struct FeaturedStoreCardView: View {
    let store: StoreSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ImageMosaicView(store: store)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.name)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(red: 0.19, green: 0.21, blue: 0.17))
                    .lineLimit(1)

                Label("\(store.pickCount)개", systemImage: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.97, green: 0.71, blue: 0.18))

                Label(String(format: "%.1f", store.totalRating), systemImage: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.16))

                Text("(\(store.totalReviewCount))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 16) {
                MetaItem(icon: "paperplane.fill", value: store.formattedDistance)
                MetaItem(icon: "clock.fill", value: store.close)
                MetaItem(icon: "figure.run", value: "\(store.totalOrderCount)회")
            }

            if !store.hashTags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(store.hashTags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.70, green: 0.78, blue: 0.64))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct ImageMosaicView: View {
    let store: StoreSummary

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                RemoteStoreImageView(store: store, cornerRadius: 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 208)

                Circle()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "heart")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.71, green: 0.77, blue: 0.65))
                    )
                    .padding(12)

                if store.isPicchelin {
                    Text("픽슐랭")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.52, green: 0.60, blue: 0.44).opacity(0.92))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
            }

            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RemoteStoreImageView(store: store, cornerRadius: 14)
                        .frame(width: 84, height: 100)
                }
            }
        }
    }
}

private struct RemoteStoreImageView: View {
    let store: StoreSummary
    let cornerRadius: CGFloat

    var body: some View {
        AsyncImage(url: store.primaryImageURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                    ProgressView()
                }
            @unknown default:
                placeholder
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.94, blue: 0.87),
                            Color(red: 0.97, green: 0.93, blue: 0.87)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.60, green: 0.69, blue: 0.53))

                Text(store.category)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.53, green: 0.59, blue: 0.46))
            }
        }
    }
}

private struct MetaItem: View {
    let icon: String
    let value: String

    var body: some View {
        Label {
            Text(value)
        } icon: {
            Image(systemName: icon)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(red: 0.57, green: 0.62, blue: 0.55))
    }
}

private struct HomeTabBar: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.98))
                .frame(height: 82)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: -4)

            HStack {
                TabItem(icon: "house.fill", isSelected: true)
                TabItem(icon: "doc.text.fill", isSelected: false)

                Spacer()
                    .frame(width: 74)

                TabItem(icon: "person.3.fill", isSelected: false)
                TabItem(icon: "person.fill", isSelected: false)
            }
            .padding(.horizontal, 34)

            Circle()
                .fill(Color(red: 0.64, green: 0.71, blue: 0.57))
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(y: -20)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }
}

private struct TabItem: View {
    let icon: String
    let isSelected: Bool

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(
                isSelected
                    ? Color(red: 0.49, green: 0.58, blue: 0.43)
                    : Color(red: 0.88, green: 0.88, blue: 0.88)
            )
            .frame(maxWidth: .infinity)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthSession())
    }
}
