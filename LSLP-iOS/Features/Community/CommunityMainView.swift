//
//  CommunityMainView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import SwiftUI

struct CommunityMainView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = CommunityViewModel()
    @State private var isComposerPresented = false
    @State private var selectedPostForComments: CommunityPost?
    @State private var composerAlertMessage: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                switch viewModel.viewState {
                case .idle, .loading:
                    ProgressView("커뮤니티 글을 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded:
                    content
                case let .error(message):
                    errorView(message: message)
                }
            }
        }
        .task(id: authSession.state) {
            guard authSession.state == .authenticated else { return }
            await loadPosts()
        }
        .sheet(isPresented: $isComposerPresented) {
            if #available(iOS 16.0, *) {
                CommunityComposerView {
                    Task {
                        await retryLoad()
                    }
                }
                .environmentObject(authSession)
            } else {
                Text("이 기기에서는 게시글 작성 기능을 지원하지 않습니다.")
                    .padding(24)
            }
        }
        .sheet(item: $selectedPostForComments) { post in
            CommunityCommentsView(post: post)
                .environmentObject(authSession)
        }
        .alert("게시글 작성", isPresented: Binding(
            get: { composerAlertMessage != nil },
            set: { if !$0 { composerAlertMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(composerAlertMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topControls
                promoSection
                postList
            }
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.61, green: 0.68, blue: 0.56))

                    Text("검색어를 입력해주세요.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.69, green: 0.72, blue: 0.68))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.79, green: 0.85, blue: 0.75), lineWidth: 1)
                )

                Button {
                    if #available(iOS 16.0, *) {
                        isComposerPresented = true
                    } else {
                        composerAlertMessage = "게시글 작성은 iOS 16 이상에서 지원됩니다."
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .bold))

                        Text("작성")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color(red: 0.76, green: 0.83, blue: 0.71))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel("게시글 작성")
            }

            DistanceScaleView()

            HStack {
                Text("타임라인")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.19))

                Spacer()

                Label("최신순", systemImage: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.53, green: 0.59, blue: 0.46))
            }
        }
        .padding(.horizontal, 24)
    }

    private var promoSection: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.94, blue: 0.86),
                            Color(red: 0.89, green: 0.92, blue: 0.84)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 112)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("새싹픽업을 처음 사용한다면")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.72, green: 0.78, blue: 0.68))

                    Text("피자부터 커피까지\n픽업하면 0원")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color(red: 0.53, green: 0.61, blue: 0.45))
                        .lineSpacing(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 74, height: 74)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.28))

                    Text("ONLY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.49, green: 0.58, blue: 0.43))
                        .clipShape(Capsule())
                        .rotationEffect(.degrees(-15))
                        .offset(x: -26, y: 14)
                }
            }
            .padding(.horizontal, 24)

            Text("1/12")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.25))
                .clipShape(Capsule())
                .padding(.trailing, 18)
                .padding(.bottom, 12)
        }
        .padding(.top, 18)
    }

    private var postList: some View {
        LazyVStack(spacing: 24) {
            ForEach(viewModel.posts) { post in
                Button {
                    selectedPostForComments = post
                } label: {
                    CommunityPostCard(post: post, request: viewModel.request)
                }
                .buttonStyle(.plain)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 14)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Text("커뮤니티 글을 불러오지 못했습니다.")
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
    private func loadPosts() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.load(accessToken: accessToken)
        } catch let error as CommunityServiceError {
            switch error {
            case .accessTokenExpired:
                await refreshAndRetry()
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
            print("Failed to load community posts: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func retryLoad() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.retry(accessToken: accessToken)
        } catch let error as CommunityServiceError {
            switch error {
            case .accessTokenExpired:
                await refreshAndRetry()
            case .unauthorized:
                await authSession.logout()
            default:
                break
            }
        } catch {
            print("Failed to retry community posts: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshAndRetry() async {
        do {
            let refreshedAccessToken = try await authSession.refreshAccessToken()
            try await viewModel.retry(accessToken: refreshedAccessToken)
        } catch {
            await authSession.logout()
        }
    }
}

private struct DistanceScaleView: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 0.87, green: 0.89, blue: 0.85), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    Text("Distance")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.78, green: 0.82, blue: 0.74))
                        .frame(width: 76, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(red: 0.78, green: 0.82, blue: 0.74), lineWidth: 1)
                        )

                    ForEach(0..<16, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index <= 10 ? Color(red: 0.72, green: 0.80, blue: 0.68) : Color(red: 0.92, green: 0.93, blue: 0.92))
                            .frame(width: 8, height: index == 10 ? 26 : 22)
                    }
                }
                .padding(.horizontal, 12)

                Text("300M")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.54, green: 0.61, blue: 0.45))
                    .clipShape(Capsule())
                    .offset(x: -74, y: -10)
            }
        }
    }
}

private struct CommunityPostCard: View {
    let post: CommunityPost
    let request: CommunityPostListRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.91, green: 0.94, blue: 0.90))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(red: 0.60, green: 0.67, blue: 0.55))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.creator.nick)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color(red: 0.26, green: 0.28, blue: 0.24))

                    Text(post.relativeCreatedText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.67, green: 0.69, blue: 0.68))
                }
            }

            CommunityImageMosaic(post: post)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(post.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(red: 0.21, green: 0.22, blue: 0.19))

                Spacer(minLength: 8)

                Label("\(post.likeCount)개", systemImage: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.97, green: 0.71, blue: 0.18))

                Label(post.distanceLabel(from: request), systemImage: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.47, green: 0.55, blue: 0.41))
            }

            Text(post.content)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.54, green: 0.56, blue: 0.54))
                .lineSpacing(4)
                .lineLimit(3)

            if post.store.hasDisplayableStoreInfo {
                CommunityStoreCapsule(store: post.store)
            }

            Divider()
                .padding(.top, 6)
        }
    }
}

private struct CommunityImageMosaic: View {
    let post: CommunityPost

    private let totalHeight: CGFloat = 240
    private let sideColumnWidth: CGFloat = 112
    private let spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            primaryImageCell
                .frame(maxWidth: .infinity, minHeight: totalHeight, maxHeight: totalHeight)

            VStack(spacing: spacing) {
                ForEach(Array(post.secondaryImageURLs.enumerated()), id: \.offset) { _, url in
                    secondaryImageCell(url: url)
                        .frame(width: sideColumnWidth, height: (totalHeight - spacing) / 2)
                }

                if post.secondaryImageURLs.isEmpty {
                    secondaryPlaceholderCell
                        .frame(width: sideColumnWidth, height: totalHeight)
                } else if post.secondaryImageURLs.count == 1 {
                    secondaryPlaceholderCell
                        .frame(width: sideColumnWidth, height: (totalHeight - spacing) / 2)
                }
            }
            .frame(width: sideColumnWidth, height: totalHeight)
        }
        .frame(height: totalHeight)
    }

    private var primaryImageCell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.92, green: 0.95, blue: 0.91))

            if let url = post.primaryImageURL {
                AuthenticatedCroppedImage(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.71, green: 0.75, blue: 0.68))
            }

            if !post.resolvedImageURLs.isEmpty {
                Circle()
                    .fill(.white.opacity(0.78))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.76, green: 0.80, blue: 0.73))
                            .offset(x: 2)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
    }

    private func secondaryImageCell(url: URL) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 0.92, green: 0.95, blue: 0.91))
            .overlay {
                AuthenticatedCroppedImage(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()
    }

    private var secondaryPlaceholderCell: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 0.92, green: 0.95, blue: 0.91))
            .overlay(
                Image(systemName: "photo.stack")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(red: 0.71, green: 0.75, blue: 0.68))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CommunityStoreCapsule: View {
    let store: CommunityStore

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.87, green: 0.92, blue: 0.83))

                if let url = store.resolvedImageURL {
                    AuthenticatedCroppedImage(url: url)
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(Color(red: 0.59, green: 0.67, blue: 0.53))
                }
            }
            .frame(width: 68, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.45, green: 0.54, blue: 0.40))
                    .lineLimit(1)

                Text(storeInfoLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.68, green: 0.71, blue: 0.67))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(height: 56)
        .background(Color(red: 0.94, green: 0.96, blue: 0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.83, blue: 0.74), lineWidth: 1)
        )
    }

    private var storeInfoLine: String {
        switch (store.category.isEmpty, store.address.isEmpty) {
        case (false, false):
            return "\(store.category) • \(store.address)"
        case (false, true):
            return store.category
        case (true, false):
            return store.address
        case (true, true):
            return ""
        }
    }
}
