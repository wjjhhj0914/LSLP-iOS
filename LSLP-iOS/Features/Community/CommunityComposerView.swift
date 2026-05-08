//
//  CommunityComposerView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import PhotosUI
import SwiftUI

@available(iOS 16.0, *)
struct CommunityComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = CommunityComposerViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var errorMessage: String?
    @State private var isSuccessPresented = false
    let onCompleted: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        mediaSection
                        categorySection
                        titleSection
                        contentSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()

                    ProgressView("이미지를 업로드하고 게시글을 등록하는 중...")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .navigationTitle("게시글 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSubmitting ? "등록 중..." : "등록") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .onChange(of: pickerItems) { newItems in
                Task {
                    await handlePickedItems(newItems)
                }
            }
            .alert("작성할 수 없습니다", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("게시글이 등록되었습니다", isPresented: $isSuccessPresented) {
                Button("확인") {
                    onCompleted()
                    dismiss()
                }
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이미지")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(red: 0.24, green: 0.26, blue: 0.22))

                Spacer()

                Text("\(viewModel.selectedMedia.count)/5")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: max(0, 5 - viewModel.selectedMedia.count),
                matching: .any(of: [.images, .videos])
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18, weight: .bold))
                    Text("사진 또는 영상 선택")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.49, green: 0.58, blue: 0.43))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.79, green: 0.85, blue: 0.75), lineWidth: 1)
                )
            }

            if !viewModel.selectedMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.selectedMedia) { media in
                            ComposerMediaPreviewCard(
                                media: media,
                                onDelete: {
                                    viewModel.removeMedia(id: media.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Text("jpg, png, jpeg, gif, webp, mp4, mov, avi, mkv, wmv / 파일당 5MB 이하 / 최대 5개")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color(red: 0.24, green: 0.26, blue: 0.22))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.categories, id: \.self) { category in
                        Button {
                            viewModel.selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    viewModel.selectedCategory == category
                                        ? .white
                                        : Color(red: 0.47, green: 0.55, blue: 0.41)
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedCategory == category
                                        ? Color(red: 0.49, green: 0.58, blue: 0.43)
                                        : Color.white
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.79, green: 0.85, blue: 0.75), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("제목")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color(red: 0.24, green: 0.26, blue: 0.22))

            TextField("제목을 입력해주세요.", text: $viewModel.title)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.87, green: 0.89, blue: 0.85), lineWidth: 1)
                )
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("본문")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color(red: 0.24, green: 0.26, blue: 0.22))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.content)
                    .font(.system(size: 16, weight: .medium))
                    .frame(minHeight: 220)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(red: 0.87, green: 0.89, blue: 0.85), lineWidth: 1)
                    )

                if viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("게시글 내용을 입력해주세요.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.72))
                        .padding(.top, 24)
                        .padding(.leading, 20)
                }
            }
        }
    }

    @MainActor
    private func handlePickedItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        defer {
            pickerItems = []
        }

        do {
            try await viewModel.addPickerItems(items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submit() async {
        do {
            let accessToken = try await authSession.resolveAccessToken()
            try await viewModel.submit(accessToken: accessToken)
            isSuccessPresented = true
        } catch let error as CommunityServiceError {
            switch error {
            case .accessTokenExpired:
                do {
                    let refreshed = try await authSession.refreshAccessToken()
                    try await viewModel.submit(accessToken: refreshed)
                    isSuccessPresented = true
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .unauthorized:
                await authSession.logout()
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ComposerMediaPreviewCard: View {
    let media: CommunityMediaUploadItem
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.92, green: 0.95, blue: 0.91))

                if let previewImage = media.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: media.kind == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: 28, weight: .bold))
                        Text(media.fileExtension.uppercased())
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.61, green: 0.68, blue: 0.56))
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white, Color.black.opacity(0.45))
            }
            .offset(x: 6, y: -6)
        }
    }
}
