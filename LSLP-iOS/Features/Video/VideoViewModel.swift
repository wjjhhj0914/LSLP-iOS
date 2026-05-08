//
//  VideoViewModel.swift
//  LSLP-iOS
//

import Combine
import Foundation

@MainActor
final class VideoViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var videos: [VideoItem] = []
    @Published private(set) var isLoadingMore = false
    @Published private(set) var streamInfo: VideoStreamResponse?
    @Published private(set) var isFetchingStream = false

    private let service: any VideoServicing
    private var nextCursor: String?
    private var hasLoadedInitialPage = false
    private var reachedLastPage = false
    private let pageSize = 10

    init(service: any VideoServicing = VideoService()) {
        self.service = service
    }

    // MARK: - List

    func loadInitial(accessToken: String) async {
        guard !hasLoadedInitialPage else { return }

        viewState = .loading
        hasLoadedInitialPage = true
        reachedLastPage = false
        nextCursor = nil

        do {
            let response = try await service.fetchVideos(nextCursor: nil, limit: pageSize, accessToken: accessToken)
            videos = response.data
            nextCursor = response.nextCursor
            reachedLastPage = response.nextCursor == nil || response.nextCursor == "0"
            viewState = .loaded
        } catch {
            hasLoadedInitialPage = false
            viewState = .error(error.localizedDescription)
        }
    }

    func retry(accessToken: String) async {
        hasLoadedInitialPage = false
        videos = []
        streamInfo = nil
        await loadInitial(accessToken: accessToken)
    }

    func loadMoreIfNeeded(currentItem: VideoItem, accessToken: String) async {
        guard shouldLoadMore(after: currentItem) else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await service.fetchVideos(nextCursor: nextCursor, limit: pageSize, accessToken: accessToken)
            videos.append(contentsOf: response.data)
            nextCursor = response.nextCursor
            reachedLastPage = response.nextCursor == nil || response.nextCursor == "0"
        } catch {
            print("Failed to load more videos: \(error.localizedDescription)")
        }
    }

    // MARK: - Player

    func fetchStream(
        videoID: String,
        accessToken: String,
        refresh: (() async throws -> String)? = nil
    ) async {
        print("[VideoVM] fetchStream called — videoID: \(videoID)")
        streamInfo = nil
        isFetchingStream = true
        defer { isFetchingStream = false }

        do {
            let result = try await service.fetchStreamInfo(videoID: videoID, accessToken: accessToken)
            print("[VideoVM] fetchStreamInfo succeeded — streamURL: \(result.streamURL), qualities: \(result.qualities.count), subtitles: \(result.subtitles.count)")
            streamInfo = result
        } catch VideoServiceError.accessTokenExpired {
            print("[VideoVM] 419 토큰 만료 — 갱신 후 재시도")
            guard let refresh else {
                print("[VideoVM] ⚠️ refresher 없음, 재시도 불가")
                return
            }
            do {
                let newToken = try await refresh()
                let result = try await service.fetchStreamInfo(videoID: videoID, accessToken: newToken)
                print("[VideoVM] 갱신 후 재시도 성공 — streamURL: \(result.streamURL)")
                streamInfo = result
            } catch {
                print("[VideoVM] ⚠️ 갱신 후 재시도 실패: \(error.localizedDescription)")
            }
        } catch {
            print("[VideoVM] ⚠️ fetchStreamInfo failed for \(videoID): \(error.localizedDescription)")
        }
    }

    func clearStream() {
        streamInfo = nil
    }

    // MARK: - Like

    func toggleLike(videoID: String, accessToken: String) async {
        do {
            let response = try await service.toggleLike(videoID: videoID, accessToken: accessToken)
            if let index = videos.firstIndex(where: { $0.id == videoID }) {
                videos[index] = videos[index].updatingLike(isLike: response.likeStatus, likeCount: response.likeCount)
            }
        } catch {
            print("Failed to toggle like for \(videoID): \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func shouldLoadMore(after item: VideoItem) -> Bool {
        guard !videos.isEmpty, !isLoadingMore, !reachedLastPage else { return false }
        guard let cursor = nextCursor, !cursor.isEmpty else { return false }
        let threshold = max(videos.count - 3, 0)
        return videos.firstIndex(where: { $0.id == item.id }) == threshold
    }
}
