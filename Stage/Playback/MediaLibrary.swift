import AVFoundation
import CoreTransferable
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct MediaItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var remoteURL: String?
    var relativePath: String?
    var duration: Double
    var position: Double
    var updated: Date
}

@MainActor
@Observable
final class MediaLibrary {
    private(set) var items: [MediaItem] = []
    var isImporting = false
    var lastError: String?

    private let storeURL: URL
    private let mediaDirectory: URL
    private let videoExtensions = Set(["mp4", "mov", "m4v"])
    private var lastProgressWrite = Date.distantPast

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stage", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        storeURL = support.appendingPathComponent("library.json")

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        mediaDirectory = documents.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        load()
        adoptLooseFiles()
    }

    var continueWatching: [MediaItem] {
        items
            .filter { $0.position > 3 && ($0.duration <= 0 || $0.position < $0.duration - 3) }
            .sorted { $0.updated > $1.updated }
    }

    func url(for item: MediaItem) -> URL? {
        if let remoteURL = item.remoteURL, let url = URL(string: remoteURL) {
            return url
        }
        guard let relativePath = item.relativePath else { return nil }
        let url = mediaDirectory.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func importFile(from source: URL) async {
        isImporting = true
        defer { isImporting = false }
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let item = try await storeCopy(of: source, title: title(from: source))
            items.insert(item, at: 0)
            save()
            lastError = nil
            await probe(item)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func importPhoto(_ photo: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        do {
            guard let imported = try await photo.loadTransferable(type: ImportedVideo.self) else {
                lastError = "That photo library item isn’t a video."
                return
            }
            let item = try await storeCopy(of: imported.url, title: title(from: imported.url))
            try? FileManager.default.removeItem(at: imported.url)
            items.insert(item, at: 0)
            save()
            lastError = nil
            await probe(item)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addLink(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains("://") {
            text = "https://\(text)"
        }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            lastError = "Enter a direct http or https link to a video."
            return
        }
        let item = MediaItem(
            id: UUID(),
            title: title(from: url),
            remoteURL: url.absoluteString,
            relativePath: nil,
            duration: 0,
            position: 0,
            updated: Date()
        )
        items.insert(item, at: 0)
        save()
        lastError = nil
        Task { await probe(item) }
    }

    func updateProgress(id: UUID, position: Double, duration: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].position = position
        if duration > 0 {
            items[index].duration = duration
        }
        let now = Date()
        items[index].updated = now
        guard now.timeIntervalSince(lastProgressWrite) > 2 else { return }
        lastProgressWrite = now
        save()
    }

    func flush() {
        save()
    }

    func remove(_ item: MediaItem) {
        if let relativePath = item.relativePath {
            let url = mediaDirectory.appendingPathComponent(relativePath)
            try? FileManager.default.removeItem(at: url)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    private func storeCopy(of source: URL, title: String) async throws -> MediaItem {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        let destination = mediaDirectory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
        return MediaItem(
            id: UUID(),
            title: title,
            remoteURL: nil,
            relativePath: name,
            duration: 0,
            position: 0,
            updated: Date()
        )
    }

    private func probe(_ item: MediaItem) async {
        guard let url = url(for: item) else { return }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].duration = seconds
        save()
    }

    private func adoptLooseFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: mediaDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        let known = Set(items.compactMap(\.relativePath))
        var changed = false
        for file in files {
            let name = file.lastPathComponent
            guard videoExtensions.contains(file.pathExtension.lowercased()), !known.contains(name) else { continue }
            items.append(MediaItem(
                id: UUID(),
                title: title(from: file),
                remoteURL: nil,
                relativePath: name,
                duration: 0,
                position: 0,
                updated: Date()
            ))
            changed = true
        }
        if changed {
            save()
        }
    }

    private func title(from url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Video" : trimmed
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([MediaItem].self, from: data)
        else { return }
        items = decoded.sorted { $0.updated > $1.updated }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}

struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            try Self.copy(received.file)
        }
        FileRepresentation(contentType: .mpeg4Movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            try Self.copy(received.file)
        }
        FileRepresentation(contentType: .quickTimeMovie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            try Self.copy(received.file)
        }
    }

    private static func copy(_ file: URL) throws -> ImportedVideo {
        let ext = file.pathExtension.isEmpty ? "mov" : file.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: file, to: destination)
        return ImportedVideo(url: destination)
    }
}
