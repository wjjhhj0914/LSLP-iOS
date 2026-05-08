//
//  CommunityComposerViewModel.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import AVFoundation
import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@available(iOS 16.0, *)
@MainActor
final class CommunityComposerViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var selectedCategory = "맛집"
    @Published private(set) var selectedMedia: [CommunityMediaUploadItem] = []
    @Published private(set) var isSubmitting = false

    let categories = ["맛집", "카페", "패스트푸드", "디저트", "일상", "커피"]

    private let service: any CommunityServicing
    private let allowedExtensions = Set([
        "jpg", "png", "jpeg", "gif", "webp",
        "mp4", "mov", "avi", "mkv", "wmv"
    ])
    private let defaultGeolocation = CommunityCreatePostGeolocation(
        longitude: 127.049914,
        latitude: 37.654215
    )

    init(service: any CommunityServicing = CommunityService()) {
        self.service = service
    }

    func addPickerItems(_ items: [PhotosPickerItem]) async throws {
        if selectedMedia.count + items.count > 5 {
            throw CommunityServiceError.tooManyFiles
        }

        var appended: [CommunityMediaUploadItem] = []

        for item in items {
            guard let media = try await makeUploadItem(from: item) else { continue }
            appended.append(media)
        }

        if selectedMedia.count + appended.count > 5 {
            throw CommunityServiceError.tooManyFiles
        }

        selectedMedia.append(contentsOf: appended)
    }

    func removeMedia(id: UUID) {
        selectedMedia.removeAll { $0.id == id }
    }

    func submit(accessToken: String) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty, !selectedCategory.isEmpty else {
            throw CommunityServiceError.emptyContent
        }
        guard !selectedMedia.isEmpty else {
            throw CommunityServiceError.emptyMedia
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let uploadedFiles = try await service.uploadFiles(
            items: selectedMedia,
            accessToken: accessToken
        )

        let draft = CommunityCreatePostRequest(
            category: selectedCategory,
            title: trimmedTitle,
            content: trimmedContent,
            files: uploadedFiles.files,
            geolocation: defaultGeolocation
        )

        _ = try await service.createPost(draft: draft, accessToken: accessToken)
    }

    private func makeUploadItem(from item: PhotosPickerItem) async throws -> CommunityMediaUploadItem? {
        guard let typeIdentifier = item.supportedContentTypes.first else { return nil }
        let fileExtension = resolvedFileExtension(for: typeIdentifier)

        guard allowedExtensions.contains(fileExtension) else {
            throw CommunityServiceError.invalidFileType
        }

        guard let data = try await item.loadTransferable(type: Data.self) else {
            return nil
        }

        guard data.count <= 5 * 1024 * 1024 else {
            throw CommunityServiceError.fileTooLarge
        }

        let mimeType = resolvedMimeType(for: fileExtension)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let kind: CommunityMediaUploadItem.Kind = typeIdentifier.conforms(to: .movie) ? .video : .image
        let previewImage: UIImage?

        switch kind {
        case .image:
            previewImage = UIImage(data: data)
        case .video:
            previewImage = makeVideoThumbnail(data: data, fileExtension: fileExtension)
        }

        return CommunityMediaUploadItem(
            fileName: fileName,
            mimeType: mimeType,
            fileExtension: fileExtension,
            data: data,
            previewImage: previewImage,
            kind: kind
        )
    }

    private func resolvedFileExtension(for type: UTType) -> String {
        if let preferred = type.preferredFilenameExtension {
            return preferred.lowercased()
        }

        if type.conforms(to: .jpeg) { return "jpg" }
        if type.conforms(to: .png) { return "png" }
        if type.conforms(to: .gif) { return "gif" }
        if type.conforms(to: .mpeg4Movie) { return "mp4" }
        if type.conforms(to: .quickTimeMovie) { return "mov" }
        return "jpg"
    }

    private func resolvedMimeType(for fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        case "mkv":
            return "video/x-matroska"
        case "wmv":
            return "video/x-ms-wmv"
        default:
            return "application/octet-stream"
        }
    }

    private func makeVideoThumbnail(data: Data, fileExtension: String) -> UIImage? {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try data.write(to: temporaryURL)
            let asset = AVURLAsset(url: temporaryURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let imageRef = try generator.copyCGImage(at: .zero, actualTime: nil)
            try? FileManager.default.removeItem(at: temporaryURL)
            return UIImage(cgImage: imageRef)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return nil
        }
    }
}
