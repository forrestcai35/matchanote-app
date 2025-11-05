import Foundation
import UIKit
import CryptoKit

/// Disk-based cache for rendered PDF images to avoid re-rendering on every AI request
class PDFRenderCache {
    static let shared = PDFRenderCache()

    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500_000_000 // 500 MB
    private let fileManager = FileManager.default

    // Track note modification times to invalidate stale caches
    private var noteModificationTimes: [String: Date] = [:]

    private init() {
        // Use system cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("PDFRenders", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Clean up old cache on init
        Task {
            await cleanupIfNeeded()
        }
    }

    // MARK: - Cache Key Generation

    /// Generate a cache key based on PDF path, page index, scale, and note modification time
    private func cacheKey(pdfPath: String, pageIndex: Int, scale: CGFloat, noteId: String) -> String {
        // Include note modification time in hash to invalidate when note changes
        let modTime = noteModificationTimes[noteId]?.timeIntervalSince1970 ?? 0
        let input = "\(pdfPath)_\(pageIndex)_\(scale)_\(modTime)"

        // Generate SHA256 hash
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get file URL for cached image
    private func cacheFileURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).jpg")
    }

    // MARK: - Cache Operations

    /// Check if a rendered PDF image exists in cache
    func exists(pdfPath: String, pageIndex: Int, scale: CGFloat, noteId: String) -> Bool {
        let key = cacheKey(pdfPath: pdfPath, pageIndex: pageIndex, scale: scale, noteId: noteId)
        let fileURL = cacheFileURL(for: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Retrieve cached rendered PDF image
    func get(pdfPath: String, pageIndex: Int, scale: CGFloat, noteId: String) -> UIImage? {
        let key = cacheKey(pdfPath: pdfPath, pageIndex: pageIndex, scale: scale, noteId: noteId)
        let fileURL = cacheFileURL(for: key)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Update access time for LRU
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return image
    }

    /// Store rendered PDF image in cache
    func set(image: UIImage, pdfPath: String, pageIndex: Int, scale: CGFloat, noteId: String) {
        let key = cacheKey(pdfPath: pdfPath, pageIndex: pageIndex, scale: scale, noteId: noteId)
        let fileURL = cacheFileURL(for: key)

        // Convert to JPEG with 0.6 quality for good balance
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }

        // Write to disk
        try? data.write(to: fileURL)

        // Cleanup if cache is too large
        Task {
            await cleanupIfNeeded()
        }
    }

    // MARK: - Note Modification Tracking

    /// Update note modification time to invalidate cache when note changes
    func updateNoteModificationTime(noteId: String, modificationDate: Date) {
        noteModificationTimes[noteId] = modificationDate
    }

    /// Clear cached images for a specific note
    func clearCacheForNote(noteId: String) {
        noteModificationTimes.removeValue(forKey: noteId)
        // Note: Old cache files will be cleaned up by LRU eventually
    }

    // MARK: - Cache Management

    /// Get total cache size in bytes
    private func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int64 else {
                continue
            }
            totalSize += fileSize
        }

        return totalSize
    }

    /// Clean up cache using LRU if it exceeds max size
    func cleanupIfNeeded() async {
        let currentSize = getCacheSize()

        guard currentSize > maxCacheSize else {
            return
        }

        // Get all cached files with modification dates
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else {
            return
        }

        var files: [(url: URL, date: Date, size: Int64)] = []
        let allFiles = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in allFiles {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date,
                  let fileSize = attributes[.size] as? Int64 else {
                continue
            }
            files.append((url: fileURL, date: modDate, size: fileSize))
        }

        // Sort by modification date (oldest first)
        files.sort { $0.date < $1.date }

        // Delete oldest files until we're under the limit
        var deletedSize: Int64 = 0
        let targetDeletion = currentSize - (maxCacheSize * 3 / 4) // Delete down to 75% of max

        for file in files {
            guard deletedSize < targetDeletion else {
                break
            }

            try? fileManager.removeItem(at: file.url)
            deletedSize += file.size
        }

        print("📦 PDFRenderCache: Cleaned up \(deletedSize / 1_000_000) MB")
    }

    /// Clear entire cache
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        noteModificationTimes.removeAll()
        print("📦 PDFRenderCache: Cleared all cached renders")
    }
}
