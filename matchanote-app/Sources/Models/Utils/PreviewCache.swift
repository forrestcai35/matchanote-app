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

  /// Image decoding cache to avoid repeated JPEG/PNG decoding
  private let imageCache = NSCache<NSString, UIImage>()

  /// Track in-flight preview generation tasks to avoid duplicates
  private var inFlightTasks: [String: Task<UIImage, Never>] = [:]
  private let taskLock = NSLock()

  private init() {
    // Configure cache limits
    cache.countLimit = 100 // Maximum 100 previews
    cache.totalCostLimit = 50 * 1024 * 1024 // 50MB for previews

    imageCache.countLimit = 200 // Maximum 200 decoded images
    imageCache.totalCostLimit = 100 * 1024 * 1024 // 100MB for images

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
    imageCache.removeAllObjects()
    inFlightTasks.removeAll()
  }

  // MARK: - Cache Key Generation

  /// Generate a unique cache key for a note based on ID and modification date
  private func cacheKey(for note: Note, size: PreviewGenerator.PreviewSize) -> String {
    let timestamp = note.dateModified.timeIntervalSince1970
    return "\(note.id.uuidString)_\(timestamp)_\(size)"
  }

  /// Generate cache key for image data
  private func imageCacheKey(for data: Data) -> String {
    return "\(data.hashValue)"
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

  /// Generate preview on background thread with cached image decoding
  private func generatePreviewBackground(for note: Note, size: PreviewGenerator.PreviewSize) async -> UIImage {
    // This runs on background thread
    let paperSize = PaperUtilities.paperSize(
      for: note.paperSize,
      orientation: note.paperOrientation
    )
    let pageIndex = 0 // First page for preview

    // Extract drawing data
    let drawing: PKDrawing
    if let drawingData = note.drawingDataByPage[String(pageIndex)],
       let decodedDrawing = try? PKDrawing(data: drawingData) {
      drawing = decodedDrawing
    } else {
      drawing = PKDrawing()
    }

    // Extract and decode background images with caching
    var backgroundImages: [UIImage] = []
    if let imageDataArray = note.imageDataByPage[String(pageIndex)] {
      for imageData in imageDataArray {
        if let image = await getDecodedImage(from: imageData) {
          backgroundImages.append(image)
        }
      }
    }

    // Extract and decode overlay images with caching
    var overlayImages: [(image: UIImage, canvasImage: CanvasImage)] = []
    let canvasImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: pageIndex)
    for canvasImage in canvasImages {
      if let image = await getDecodedImage(from: canvasImage.imageData) {
        overlayImages.append((image, canvasImage))
      }
    }

    // Extract textboxes
    let textBoxes = extractTextBoxes(from: note.textBoxDataByPage, for: pageIndex)

    // Generate the preview
    return await Task.detached(priority: .userInitiated) {
      self.renderPreview(
        drawing: drawing,
        paperSize: paperSize,
        paperColor: note.paperColor,
        paperStyle: note.paperStyle,
        size: size,
        backgroundImages: backgroundImages,
        overlayImages: overlayImages,
        textBoxes: textBoxes,
        cornerRadius: note.noteType == .written ? (size == .grid ? 10 : 6) : (size == .grid ? 0 : 2)
      )
    }.value
  }

  // MARK: - TextBox Extraction

  /// Extract textboxes for a specific page
  private func extractTextBoxes(from textBoxDataByPage: [String: [Data]], for pageIndex: Int) -> [TextBox] {
    guard let textBoxDataArray = textBoxDataByPage[String(pageIndex)] else { return [] }

    var textBoxes: [TextBox] = []
    for textBoxData in textBoxDataArray {
      if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
        textBoxes.append(textBox)
      }
    }
    return textBoxes
  }

  // MARK: - Image Decoding Cache

  /// Get decoded image with caching to avoid repeated JPEG/PNG decoding
  private func getDecodedImage(from data: Data) async -> UIImage? {
    let key = imageCacheKey(for: data)

    // Check cache first
    if let cached = imageCache.object(forKey: key as NSString) {
      return cached
    }

    // Decode on background thread
    return await Task.detached(priority: .utility) {
      guard let image = UIImage(data: data) else { return nil }

      // Cache with estimated size
      let estimatedSize = Int(image.size.width * image.size.height * 4)
      self.imageCache.setObject(image, forKey: key as NSString, cost: estimatedSize)

      return image
    }.value
  }

  // MARK: - Optimized Rendering

  /// Render preview with all components
  private func renderPreview(
    drawing: PKDrawing,
    paperSize: CGSize,
    paperColor: PaperColor,
    paperStyle: PaperStyle,
    size: PreviewGenerator.PreviewSize,
    backgroundImages: [UIImage],
    overlayImages: [(image: UIImage, canvasImage: CanvasImage)],
    textBoxes: [TextBox],
    cornerRadius: CGFloat?
  ) -> UIImage {
    let scale = size.scale
    let thumbnailSize = CGSize(
      width: paperSize.width * scale,
      height: paperSize.height * scale
    )

    let screenScale = 2.0 // Use default high-resolution scale
    let effectiveScale = scale * screenScale

    UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, screenScale)
    defer { UIGraphicsEndImageContext() }

    guard let context = UIGraphicsGetCurrentContext() else {
      return UIImage()
    }

    // Enable high quality rendering
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Draw paper background
    let paperBackgroundColor = PaperUtilities.getPaperBackgroundColor(for: paperColor)
    UIColor(paperBackgroundColor).setFill()
    context.fill(CGRect(origin: .zero, size: thumbnailSize))

    // Draw background images (already decoded)
    for backgroundImage in backgroundImages {
      backgroundImage.draw(in: CGRect(origin: .zero, size: thumbnailSize), blendMode: .normal, alpha: 1.0)
    }

    // Draw paper pattern
    PaperUtilities.drawPaperPattern(context: context, paperStyle: paperStyle, size: thumbnailSize)

    // Draw overlay images (already decoded)
    for (overlayUIImage, canvasImage) in overlayImages {
      let scaledPosition = CGPoint(
        x: canvasImage.position.x * scale,
        y: canvasImage.position.y * scale
      )
      let scaledSize = CGSize(
        width: canvasImage.size.width * scale,
        height: canvasImage.size.height * scale
      )

      // Apply rotation if needed
      if canvasImage.rotation != 0 {
        context.saveGState()
        let centerX = scaledPosition.x + scaledSize.width / 2
        let centerY = scaledPosition.y + scaledSize.height / 2
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: canvasImage.rotation)
        context.translateBy(x: -centerX, y: -centerY)
      }

      overlayUIImage.draw(in: CGRect(origin: scaledPosition, size: scaledSize))

      if canvasImage.rotation != 0 {
        context.restoreGState()
      }
    }

    // Draw textboxes
    for textBox in textBoxes {
      let scaledPosition = CGPoint(
        x: textBox.position.x * scale,
        y: textBox.position.y * scale
      )
      let scaledSize = CGSize(
        width: textBox.size.width * scale,
        height: textBox.size.height * scale
      )
      let scaledFontSize = textBox.fontSize * scale

      // Apply rotation if needed
      if textBox.rotation != 0 {
        context.saveGState()
        let centerX = scaledPosition.x + scaledSize.width / 2
        let centerY = scaledPosition.y + scaledSize.height / 2
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: CGFloat(textBox.rotation) * .pi / 180)
        context.translateBy(x: -centerX, y: -centerY)
      }

      let textBoxRect = CGRect(origin: scaledPosition, size: scaledSize)

      // Draw background
      if textBox.backgroundColor != .clear {
        UIColor(textBox.backgroundColor).setFill()
        let backgroundPath = UIBezierPath(roundedRect: textBoxRect, cornerRadius: textBox.cornerRadius * scale)
        backgroundPath.fill()
      }

      // Draw border
      if textBox.borderWidth > 0 {
        UIColor(textBox.borderColor).setStroke()
        let borderPath = UIBezierPath(roundedRect: textBoxRect, cornerRadius: textBox.cornerRadius * scale)
        borderPath.lineWidth = textBox.borderWidth * scale
        borderPath.stroke()
      }

      // Draw text
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = textBox.textAlignment.nsTextAlignment

      let font: UIFont
      if textBox.fontFamily == "System" {
        font = UIFont.systemFont(ofSize: scaledFontSize)
      } else if let customFont = UIFont(name: textBox.fontFamily, size: scaledFontSize) {
        font = customFont
      } else {
        font = UIFont.systemFont(ofSize: scaledFontSize)
      }

      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor(textBox.textColor),
        .paragraphStyle: paragraphStyle
      ]

      let padding = 8 * scale
      let textRect = CGRect(
        x: scaledPosition.x + padding,
        y: scaledPosition.y + padding,
        width: scaledSize.width - padding * 2,
        height: scaledSize.height - padding * 2
      )

      (textBox.text as NSString).draw(in: textRect, withAttributes: attributes)

      if textBox.rotation != 0 {
        context.restoreGState()
      }
    }

    // Draw the drawing on top
    let fullPageBounds = CGRect(origin: .zero, size: paperSize)
    let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)
    var drawingImage: UIImage!
    lightTraitCollection.performAsCurrent {
      drawingImage = drawing.image(from: fullPageBounds, scale: effectiveScale)
    }
    drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))

    guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else {
      return UIImage()
    }

    // Apply corner radius if specified
    if let radius = cornerRadius, radius > 0 {
      return applyCornerRadius(to: finalImage, radius: radius, targetSize: thumbnailSize)
    }

    return finalImage
  }

  private func applyCornerRadius(to image: UIImage, radius: CGFloat, targetSize: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { context in
      let rect = CGRect(origin: .zero, size: targetSize)
      UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
      image.draw(in: rect)
    }
  }

  // MARK: - Cache Management

  /// Clear all cached previews
  func clearAll() {
    cache.removeAllObjects()
    imageCache.removeAllObjects()
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
