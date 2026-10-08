import Foundation
import CryptoKit

/// Persistent, size-bounded cache for exercise demonstration videos.
/// In-flight requests are coalesced so concurrent views never download the same file twice.
actor ExerciseVideoCache {
    static let shared = ExerciseVideoCache()

    private let directory: URL
    private let maximumBytes: Int64 = 300 * 1024 * 1024
    private let maximumFileBytes: Int64 = 80 * 1024 * 1024
    private var downloads: [URL: Task<URL, Error>] = [:]

    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseVideos", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func localURL(for remoteURL: URL) async throws -> URL {
        guard remoteURL.scheme?.lowercased() == "https" else {
            throw URLError(.unsupportedURL)
        }

        let destination = directory.appendingPathComponent(Self.cacheKey(for: remoteURL) + ".mp4")
        if isCached(destination) {
            touch(destination)
            return destination
        }

        if let download = downloads[remoteURL] {
            return try await download.value
        }

        let limit = maximumFileBytes
        let download = Task<URL, Error> {
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 45
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let size = (try FileManager.default.attributesOfItem(
                atPath: temporaryURL.path
            )[.size] as? NSNumber)?.int64Value ?? 0
            guard size > 0, size <= limit else {
                throw URLError(.dataLengthExceedsMaximum)
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return destination
        }

        downloads[remoteURL] = download
        defer { downloads[remoteURL] = nil }

        let localURL = try await download.value
        trimCache(excluding: localURL)
        return localURL
    }

    private func isCached(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        return size > 0
    }

    private func touch(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }

    private func trimCache(excluding protectedURL: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else { return }

        var files: [(url: URL, size: Int64, date: Date)] = []
        for url in urls {
            guard let properties = try? url.resourceValues(forKeys: keys),
                  properties.isRegularFile == true else { continue }
            files.append((
                url: url,
                size: Int64(properties.fileSize ?? 0),
                date: properties.contentModificationDate ?? .distantPast
            ))
        }

        var bytes = files.reduce(Int64(0)) { $0 + $1.size }
        for item in files.sorted(by: { $0.date < $1.date }) {
            if bytes <= maximumBytes { break }
            if item.url == protectedURL { continue }
            if (try? FileManager.default.removeItem(at: item.url)) != nil {
                bytes -= item.size
            }
        }
    }

    private static func cacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
