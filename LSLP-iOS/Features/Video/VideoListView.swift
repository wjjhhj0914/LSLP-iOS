//
//  VideoListView.swift
//  LSLP-iOS
//

import SwiftUI
import UIKit

struct VideoListView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = VideoViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                switch viewModel.viewState {
                case .idle, .loading:
                    ProgressView("영상을 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    videoList

                case let .error(message):
                    errorView(message: message)
                }
            }
            .navigationTitle("비디오")
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: authSession.state) {
            guard authSession.state == .authenticated,
                  let token = authSession.accessToken else { return }
            await viewModel.loadInitial(accessToken: token)
        }
    }

    // MARK: - Subviews

    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    NavigationLink {
                        VideoPlayerView(video: video)
                            .environmentObject(viewModel)
                    } label: {
                        VideoCardView(video: video)
                    }
                    .buttonStyle(.plain)
                    .task {
                        guard let token = authSession.accessToken else { return }
                        await viewModel.loadMoreIfNeeded(currentItem: video, accessToken: token)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 20)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("불러오기 실패")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("다시 시도") {
                Task {
                    guard let token = authSession.accessToken else { return }
                    await viewModel.retry(accessToken: token)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.52, green: 0.60, blue: 0.44))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card

private struct VideoCardView: View {
    let video: VideoItem
    @EnvironmentObject private var authSession: AuthSession
    @State private var loadedThumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailSection
            infoSection
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .task(id: video.id) {
            await loadThumbnail()
        }
    }

    private var thumbnailSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = loadedThumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                        .overlay(ProgressView())
                }
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            .clipped()

            if video.duration > 0 {
                Text(video.durationLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.20))
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(video.creator.nick)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.44))
                    Text("\(video.likeCount)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(video.viewCount)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text(video.relativeCreatedText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func loadThumbnail() async {
        guard let url = video.resolvedThumbnailURL,
              let token = authSession.accessToken else { return }
        var request = URLRequest(url: url)
        request.setValue(APIKey.SESAC_KEY, forHTTPHeaderField: "SeSACKey")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return }
        loadedThumbnail = image
    }
}
