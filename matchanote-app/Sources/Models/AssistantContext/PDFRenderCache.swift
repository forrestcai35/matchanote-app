import Foundation
import UIKit
import CryptoKit

/// Disk-based cache for rendered PDF images to avoid re-rendering on every AI request
final class PDFRenderCache: @unchecked Sendable {
    static let shared = PDFRenderCache()

    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500_000_000 // 500 MB
    private let fileManager = FileManager.default

    // Track note modification times to invalidate stale caches
    private var noteModificationTimes: [String: Date] = [:]
    private let modificationTimesQueue = DispatchQueue(label: "com.matcha.pdfcache.modtimes", attributes: .concurrent)

    // Track pending render tasks for cancellation
    private var renderTasks: [String: Task<Void, Never>] = [:]
    private let renderTasksQueue = DispatchQueue(label: "com.matcha.pdfcache.tasks", attributes: .concurrent)

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
        let modTime = modificationTimesQueue.sync {
            noteModificationTimes[noteId]?.timeIntervalSince1970 ?? 0
        }
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

        // Convert to JPEG with 0.8 quality for good balance between quality and size
        guard let data = image.jpegData(compressionQuality: 0.8) else {
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
        modificationTimesQueue.async(flags: .barrier) { [weak self] in
            self?.noteModificationTimes[noteId] = modificationDate
        }
    }

    /// Clear cached images for a specific note
    func clearCacheForNote(noteId: String) {
        modificationTimesQueue.async(flags: .barrier) { [weak self] in
            self?.noteModificationTimes.removeValue(forKey: noteId)
        }
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

    // MARK: - Prefetching

    /// Prefetch pages for smooth page transitions
    /// - Parameters:
    ///   - pdfPath: Relative path to PDF file
    ///   - pageIndices: Array of page indices to prefetch (1-based)
    ///   - size: Render size for the images
    ///   - scale: Scale factor for rendering
    ///   - noteId: Note ID for cache invalidation
    func prefetchPages(
        pdfPath: String,
        pageIndices: [Int],
        size: CGSize,
        scale: CGFloat,
        noteId: String
    ) {
        for pageIndex in pageIndices {
            // Skip if already cached
            if exists(pdfPath: pdfPath, pageIndex: pageIndex, scale: scale, noteId: noteId) {
                continue
            }

            // Generate task key
            let taskKey = "\(pdfPath)_\(pageIndex)_\(scale)_\(noteId)"

            // Skip if already rendering
            let isRendering = renderTasksQueue.sync {
                renderTasks[taskKey] != nil
            }
            if isRendering {
                continue
            }

            // Start background render task
            let task = Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }

                // Build full URL
                let url = AttachmentManager.fileURL(for: pdfPath)

                // Render page to image
                if let image = await PDFDrawingUtils.renderPageToImage(
                    url: url,
                    pageIndex: pageIndex,
                    size: size,
                    scale: scale
                ) {
                    // Save to cache
                    self.set(
                        image: image,
                        pdfPath: pdfPath,
                        pageIndex: pageIndex,
                        scale: scale,
                        noteId: noteId
                    )
                }

                // Remove from pending tasks
                self.renderTasksQueue.async(flags: .barrier) {
                    self.renderTasks.removeValue(forKey: taskKey)
                }
            }

            // Track task
            renderTasksQueue.async(flags: .barrier) { [weak self] in
                self?.renderTasks[taskKey] = task
            }
        }
    }

    /// Cancel all pending render tasks
    func cancelAllRenders() {
        renderTasksQueue.sync {
            for task in renderTasks.values {
                task.cancel()
            }
        }

        renderTasksQueue.async(flags: .barrier) { [weak self] in
            self?.renderTasks.removeAll()
        }
    }

    /// Cancel render tasks for a specific note
    func cancelRendersForNote(noteId: String) {
        let tasksToCancel = renderTasksQueue.sync {
            renderTasks.filter { $0.key.hasSuffix("_\(noteId)") }
        }

        for (key, task) in tasksToCancel {
            task.cancel()
            renderTasksQueue.async(flags: .barrier) { [weak self] in
                self?.renderTasks.removeValue(forKey: key)
            }
        }
    }

    /// Clear entire cache
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        modificationTimesQueue.async(flags: .barrier) { [weak self] in
            self?.noteModificationTimes.removeAll()
        }
        cancelAllRenders()
        print("📦 PDFRenderCache: Cleared all cached renders")
    }
}
