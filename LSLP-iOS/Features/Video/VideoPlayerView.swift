//
//  VideoPlayerView.swift
//  LSLP-iOS

import AVKit
import Combine
import SwiftUI

// MARK: - UIViewControllerRepresentable

struct AVPlayerControllerRepresented: UIViewControllerRepresentable {
    let player: AVPlayer
    /// ellipsis 메뉴에서 자막 선택 시 해당 Locale(또는 nil)을 전달
    var onNativeSubtitleSelected: ((Locale?) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        context.coordinator.bind(player: player)
        context.coordinator.handler = onNativeSubtitleSelected
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        context.coordinator.handler = onNativeSubtitleSelected
    }

    // MARK: Coordinator

    final class Coordinator {
        var handler: ((Locale?) -> Void)?
        private var playerObservation: NSKeyValueObservation?
        private var itemObservation: NSKeyValueObservation?

        func bind(player: AVPlayer) {
            playerObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
                self?.observeItem(player.currentItem)
            }
        }

        private func observeItem(_ item: AVPlayerItem?) {
            itemObservation?.invalidate()
            guard let item else { return }
            itemObservation = item.observe(\.currentMediaSelection, options: [.new]) { [weak self, weak item] _, _ in
                guard let self, let item else { return }
                Task { @MainActor [weak self, weak item] in
                    guard let self, let item else { return }
                    guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
                    let locale = item.currentMediaSelection.selectedMediaOption(in: group)?.locale
                    self.handler?(locale)
                }
            }
        }
    }
}

// MARK: - VideoPlayerView

struct VideoPlayerView: View {
    let video: VideoItem

    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var viewModel: VideoViewModel

    @State private var player: AVPlayer?
    @State private var selectedQuality: VideoQuality?
    @State private var selectedSubtitle: VideoSubtitle?
    @State private var subtitleCues: [SubtitleCue] = []
    @State private var currentSubtitleText: String?
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isQualityPickerPresented = false
    @State private var isSubtitlePickerPresented = false

    private let subtitleTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(video: VideoItem) {
        self.video = video
        _isLiked = State(initialValue: video.isLike)
        _likeCount = State(initialValue: video.likeCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                playerSection
                metadataSection
                controlsSection
                descriptionSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("[VideoPlayer] task started — videoID: \(video.videoID)")
            guard let token = authSession.accessToken else {
                print("[VideoPlayer] ⚠️ accessToken is nil, aborting stream fetch")
                return
            }
            print("[VideoPlayer] accessToken present, calling fetchStream")
            await viewModel.fetchStream(
                videoID: video.videoID,
                accessToken: token,
                refresh: { try await authSession.refreshAccessToken() }
            )
        }
        .onChange(of: viewModel.streamInfo) { _, new in
            print("[VideoPlayer] streamInfo changed → \(new != nil ? "received StreamResponse" : "nil")")
            guard let new else { return }
            print("[VideoPlayer] calling initializePlayer with URL: \(new.streamURL)")
            initializePlayer(with: new.streamURL)
        }
        .onReceive(subtitleTimer) { _ in
            syncSubtitleText()
        }
        .onDisappear {
            player?.pause()
            player = nil
            subtitleCues = []
            currentSubtitleText = nil
            viewModel.clearStream()
        }
        .confirmationDialog("화질 선택", isPresented: $isQualityPickerPresented, titleVisibility: .visible) {
            qualityActions
        }
        .confirmationDialog("자막 선택", isPresented: $isSubtitlePickerPresented, titleVisibility: .visible) {
            subtitleActions
        }
    }

    // MARK: - Player section

    @ViewBuilder
    private var playerSection: some View {
        if let player {
            ZStack(alignment: .bottom) {
                AVPlayerControllerRepresented(
                    player: player,
                    onNativeSubtitleSelected: { locale in
                        handleNativeSubtitleSelected(locale: locale)
                    }
                )
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

                if let text = currentSubtitleText, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .allowsHitTesting(false)
                }
            }
        } else {
            Color.black
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if viewModel.isFetchingStream {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
        }
    }

    // MARK: - Metadata section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.20))

            HStack(spacing: 6) {
                Text(video.creator.nick)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(video.relativeCreatedText)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(video.viewCount)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Controls section

    private var controlsSection: some View {
        HStack(spacing: 0) {
            likeButton

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 12)

            if let stream = viewModel.streamInfo, !stream.qualities.isEmpty {
                qualityButton(stream: stream)

                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 12)
            }

            if let stream = viewModel.streamInfo, !stream.subtitles.isEmpty {
                subtitleButton(stream: stream)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var likeButton: some View {
        Button {
            Task {
                guard let token = authSession.accessToken else { return }
                let wasLiked = isLiked
                isLiked.toggle()
                likeCount += wasLiked ? -1 : 1
                await viewModel.toggleLike(videoID: video.videoID, accessToken: token)
                if let updated = viewModel.videos.first(where: { $0.id == video.videoID }) {
                    isLiked = updated.isLike
                    likeCount = updated.likeCount
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isLiked
                            ? Color(red: 0.52, green: 0.60, blue: 0.44)
                            : Color.secondary
                    )
                    .animation(.easeInOut(duration: 0.15), value: isLiked)

                Text("\(likeCount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }

    private func qualityButton(stream: VideoStreamResponse) -> some View {
        Button {
            isQualityPickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(selectedQuality?.label ?? "자동")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subtitleButton(stream: VideoStreamResponse) -> some View {
        Button {
            isSubtitlePickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "captions.bubble")
                    .font(.system(size: 16))
                    .foregroundStyle(selectedSubtitle != nil ? Color(red: 0.52, green: 0.60, blue: 0.44) : .secondary)
                Text(selectedSubtitle?.displayName ?? "자막 없음")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Description section

    @ViewBuilder
    private var descriptionSection: some View {
        if !video.description.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("설명")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.20))

                Text(video.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Confirmation dialog actions

    @ViewBuilder
    private var qualityActions: some View {
        Button("자동 (최적 화질)") {
            applyQuality(nil)
        }
        if let stream = viewModel.streamInfo {
            ForEach(stream.qualities) { quality in
                Button(quality.label) {
                    applyQuality(quality)
                }
            }
        }
        Button("취소", role: .cancel) {}
    }

    @ViewBuilder
    private var subtitleActions: some View {
        Button("자막 없음") {
            applySubtitle(nil)
        }
        if let stream = viewModel.streamInfo {
            ForEach(stream.subtitles) { subtitle in
                Button(subtitle.displayName) {
                    applySubtitle(subtitle)
                }
            }
        }
        Button("취소", role: .cancel) {}
    }

    // MARK: - Player control

    private func initializePlayer(with urlString: String) {
        print("[VideoPlayer] resolving URL from raw string: \(urlString)")
        guard let url = resolveStreamURL(urlString) else {
            print("[VideoPlayer] ⚠️ resolveStreamURL returned nil for: \(urlString)")
            return
        }
        print("[VideoPlayer] resolved URL: \(url.absoluteString)")
        let item = AVPlayerItem(asset: makeAsset(url: url))
        if let currentPlayer = player {
            print("[VideoPlayer] replacing item on existing player, currentTime: \(currentPlayer.currentTime().seconds)s")
            let time = currentPlayer.currentTime()
            currentPlayer.replaceCurrentItem(with: item)
            currentPlayer.seek(to: time)
        } else {
            print("[VideoPlayer] creating new AVPlayer")
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.appliesMediaSelectionCriteriaAutomatically = false
            player = newPlayer
        }
        player?.play()
        print("[VideoPlayer] player.play() called, rate: \(player?.rate ?? -1)")
    }

    private func applyQuality(_ quality: VideoQuality?) {
        selectedQuality = quality
        guard let stream = viewModel.streamInfo else { return }
        let urlString = quality?.url ?? stream.streamURL
        guard let url = resolveStreamURL(urlString) else { return }
        let currentTime = player?.currentTime() ?? .zero
        let item = AVPlayerItem(asset: makeAsset(url: url))
        player?.replaceCurrentItem(with: item)
        player?.seek(to: currentTime)
        player?.play()
    }

    // 자막 세그먼트 요청에도 인증 헤더가 포함되도록 AVURLAsset에 헤더를 주입
    private func makeAsset(url: URL) -> AVURLAsset {
        let token = authSession.accessToken ?? ""
        return AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Authorization": token,
                "SeSACKey": APIKey.SESAC_KEY
            ]
        ])
    }

    // 상대/절대경로 + 쿼리스트링(token) 보존 처리
    // /로 시작하는 절대경로는 RFC 3986 규칙상 base path를 무시하므로 /v1을 직접 삽입
    private func resolveStreamURL(_ urlString: String) -> URL? {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        guard let baseURL = URL(string: APIKey.BASE_URL) else { return nil }
        let path = urlString.hasPrefix("/") ? "/v1" + urlString : urlString
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    // MARK: - Subtitle (external file download)

    /// ellipsis 메뉴의 native 자막 선택 변화를 감지하여 SSOT(selectedSubtitle)에 반영
    private func handleNativeSubtitleSelected(locale: Locale?) {
        if let locale {
            let matched = viewModel.streamInfo?.subtitles.first {
                locale.language.languageCode?.identifier == Locale(identifier: $0.language).language.languageCode?.identifier
            }
            guard matched?.id != selectedSubtitle?.id else { return }
            applySubtitle(matched)
        } else {
            guard selectedSubtitle != nil else { return }
            applySubtitle(nil)
        }
    }

    /// SSOT: 커스텀 버튼과 ellipsis 메뉴 모두 이 함수를 통해 자막 상태를 변경
    private func applySubtitle(_ subtitle: VideoSubtitle?) {
        selectedSubtitle = subtitle
        subtitleCues = []
        currentSubtitleText = nil

        // 커스텀 버튼 사용 시 ellipsis 메뉴도 같은 선택을 반영하도록 동기화
        Task { await syncSubtitleToNativePlayer(subtitle) }

        guard let subtitle else { return }
        Task {
            guard let token = authSession.accessToken else { return }
            await downloadSubtitle(subtitle, accessToken: token)
        }
    }

    /// selectedSubtitle → AVPlayerItem.currentMediaSelection 동기화 (ellipsis 체크 표시 갱신)
    private func syncSubtitleToNativePlayer(_ subtitle: VideoSubtitle?) async {
        guard let item = player?.currentItem,
              let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }

        if let subtitle {
            let locale = Locale(identifier: subtitle.language)
            let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
            item.select(options.first, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    private func downloadSubtitle(_ subtitle: VideoSubtitle, accessToken: String) async {
        guard let url = resolveStreamURL(subtitle.url) else {
            print("[VideoPlayer] ⚠️ subtitle URL 해석 실패: \(subtitle.url)")
            return
        }
        print("[VideoPlayer] 자막 다운로드 시작: \(url.absoluteString)")

        guard let content = await fetchSubtitleText(url: url, token: accessToken) else { return }
        let cues = parseSubtitleContent(content)
        print("[VideoPlayer] 자막 파싱 완료 — cue 수: \(cues.count)")
        subtitleCues = cues
    }

    private func fetchSubtitleText(url: URL, token: String) async -> String? {
        func makeRequest(_ t: String) -> URLRequest {
            var r = URLRequest(url: url)
            r.setValue(APIKey.SESAC_KEY, forHTTPHeaderField: "SeSACKey")
            r.setValue(t, forHTTPHeaderField: "Authorization")
            return r
        }

        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest(token)) else {
            print("[VideoPlayer] ⚠️ 자막 네트워크 오류")
            return nil
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        if status == 419 {
            print("[VideoPlayer] 자막 419 — 토큰 갱신 후 재시도")
            guard let newToken = try? await authSession.refreshAccessToken(),
                  let (retryData, retryResponse) = try? await URLSession.shared.data(for: makeRequest(newToken))
            else {
                print("[VideoPlayer] ⚠️ 자막 갱신 후 재시도 실패")
                return nil
            }
            let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
            guard 200..<300 ~= retryStatus else {
                print("[VideoPlayer] ⚠️ 자막 재시도 실패, status: \(retryStatus)")
                return nil
            }
            return String(data: retryData, encoding: .utf8)
        }

        guard 200..<300 ~= status else {
            print("[VideoPlayer] ⚠️ 자막 다운로드 실패, status: \(status)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func syncSubtitleText() {
        guard let player, !subtitleCues.isEmpty else {
            if currentSubtitleText != nil { currentSubtitleText = nil }
            return
        }
        let t = player.currentTime().seconds
        let matched = subtitleCues.first { $0.from <= t && t < $0.to }?.text
        if matched != currentSubtitleText { currentSubtitleText = matched }
    }

    // MARK: - Subtitle parser (VTT / SRT)

    private func parseSubtitleContent(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard let timeLineIdx = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = lines[timeLineIdx]
            let parts = timeLine.components(separatedBy: " --> ")
            guard parts.count == 2,
                  let from = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
                  let to = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces))
            else { continue }
            let text = lines.dropFirst(timeLineIdx + 1).joined(separator: "\n")
            if !text.isEmpty {
                cues.append(SubtitleCue(from: from, to: to, text: text))
            }
        }
        return cues
    }

    // HH:MM:SS.mmm (VTT) or HH:MM:SS,mmm (SRT)
    private func parseTimestamp(_ raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.components(separatedBy: ":")
        switch parts.count {
        case 3:
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        case 2:
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        default:
            return nil
        }
    }
}

// MARK: - SubtitleCue

private struct SubtitleCue {
    let from: Double
    let to: Double
    let text: String
}
