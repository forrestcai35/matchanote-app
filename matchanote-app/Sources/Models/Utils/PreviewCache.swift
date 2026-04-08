import SwiftUI
import UIKit
import PencilKit

// Extension to convert TextAlignment to NSTextAlignment
extension TextAlignment {
  var nsTextAlignment: NSTextAlignment {
    switch self {
    case .leading: return .left
    case .center: return .center
    case .trailing: return .right
    }
  }
}

/// High-performance preview cache with automatic memory management
/// Caches previews keyed by note ID + modification date to avoid redundant generation
class PreviewCache: ObservableObject {
  static let shared = PreviewCache()

  // MARK: - Cache Storage

  /// Main preview cache using NSCache for automatic memory management
  private let cache = NSCache<NSString, UIImage>()

  /// Track in-flight preview generation tasks to avoid duplicates
  private var inFlightTasks: [String: Task<UIImage, Never>] = [:]
  private let taskLock = NSLock()

  private init() {
    // Configure cache limits
    cache.countLimit = 100 // Maximum 100 previews
    cache.totalCostLimit = 50 * 1024 * 1024 // 50MB for previews

    // Listen for memory warnings
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMemoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleMemoryWarning() {
    cache.removeAllObjects()
    inFlightTasks.removeAll()
  }

  // MARK: - Cache Key Generation

  /// Generate a unique cache key for a note based on ID and modification date
  private func cacheKey(for note: Note, size: PreviewGenerator.PreviewSize) -> String {
    let timestamp = note.dateModified.timeIntervalSince1970
    return "\(note.id.uuidString)_\(timestamp)_\(size)"
  }

  // MARK: - Synchronous Preview Retrieval

  /// Get a cached preview synchronously if available, otherwise return nil
  func getCachedPreview(for note: Note, size: PreviewGenerator.PreviewSize) -> UIImage? {
    let key = cacheKey(for: note, size: size)
    return cache.object(forKey: key as NSString)
  }

  // MARK: - Asynchronous Preview Generation

  /// Get preview asynchronously - returns cached version immediately or generates in background
  /// - Returns: A task that resolves to the preview image
  func getPreview(for note: Note, size: PreviewGenerator.PreviewSize) async -> UIImage {
    let key = cacheKey(for: note, size: size)

    // Check cache first
    if let cached = cache.object(forKey: key as NSString) {
      return cached
    }

    // Check if already generating this preview
    let existingTask: Task<UIImage, Never>? = taskLock.withLock {
      inFlightTasks[key]
    }

    if let task = existingTask {
      return await task.value
    }

    // Create new generation task
    let task = Task<UIImage, Never> {
      // Generate preview on background thread
      let preview = await generatePreviewBackground(for: note, size: size)

      // Cache the result
      let estimatedSize = Int(preview.size.width * preview.size.height * 4) // RGBA estimate
      cache.setObject(preview, forKey: key as NSString, cost: estimatedSize)

      // Remove from in-flight
      _ = taskLock.withLock {
        inFlightTasks.removeValue(forKey: key)
      }

      return preview
    }

    // Store task
    taskLock.withLock {
      inFlightTasks[key] = task
    }

    return await task.value
  }

  // MARK: - Background Preview Generation

  /// Generate preview on background thread - delegates to PreviewGenerator
  private func generatePreviewBackground(for note: Note, size: PreviewGenerator.PreviewSize) async -> UIImage {
    // Delegate to PreviewGenerator for actual rendering
    return await Task.detached(priority: .userInitiated) {
      let pageIndex = 0
      let cornerRadius: CGFloat?
      switch size {
      case .grid:
        cornerRadius = note.noteType == .written ? 10 : 0
      case .list:
        cornerRadius = note.noteType == .written ? 6 : 2
      default:
        cornerRadius = nil
      }

      return PreviewGenerator.generatePreview(
        for: note,
        pageIndex: pageIndex,
        size: size,
        cornerRadius: cornerRadius
      )
    }.value
  }

  // MARK: - Cache Management

  /// Clear all cached previews
  func clearAll() {
    cache.removeAllObjects()
    taskLock.withLock {
      inFlightTasks.removeAll()
    }
  }

  /// Clear preview for specific note
  func clearPreview(for note: Note) {
    for size in [PreviewGenerator.PreviewSize.grid, .list] {
      let key = cacheKey(for: note, size: size)
      cache.removeObject(forKey: key as NSString)
    }
  }

  /// Preload previews for visible notes (call from onAppear)
  func preloadPreviews(for notes: [Note], size: PreviewGenerator.PreviewSize) {
    // Use userInitiated priority for faster loading when user is actively viewing
    Task.detached(priority: .userInitiated) {
      // Preload with concurrency limit to avoid overwhelming the system
      await withTaskGroup(of: Void.self) { group in
        for note in notes {
          group.addTask {
            _ = await self.getPreview(for: note, size: size)
          }
        }
      }
    }
  }
}
