import SwiftUI
import PencilKit
import UIKit

/// Centralized preview generation for notes
/// Consolidates all preview logic to ensure consistency across the app
struct PreviewGenerator {
  
  // MARK: - Preview Types
  
  enum PreviewSize: Equatable {
    case grid       // For grid view thumbnails (160x200)
    case list       // For list view thumbnails (32x40)
    case export     // For full-size exports
    case custom(CGSize)
    
    var dimensions: CGSize {
      switch self {
      case .grid:
        return CGSize(width: 160, height: 200)
      case .list:
        return CGSize(width: 32, height: 40)
      case .export:
        // Will use paper size
        return .zero
      case .custom(let size):
        return size
      }
    }
    
    var scale: CGFloat {
      switch self {
      case .grid:
        return 0.5
      case .list:
        return 0.3
      case .export:
        return 1.0
      case .custom:
        return 0.5
      }
    }
  }
  
  // MARK: - Main Preview Generation
  
  /// Generate a preview image for a note at a specific page
  /// - Parameters:
  ///   - note: The note to generate a preview for
  ///   - pageIndex: The page index (default: 0 for first page)
  ///   - size: The preview size type (grid, list, export, or custom)
  ///   - cornerRadius: Optional corner radius for the preview
  /// - Returns: A UIImage preview
  static func generatePreview(
    for note: Note,
    pageIndex: Int = 0,
    size: PreviewSize = .grid,
    cornerRadius: CGFloat? = nil
  ) -> UIImage {
    
    // Get paper dimensions with orientation
    let paperSize = PaperUtilities.paperSize(
      for: note.paperSize,
      orientation: note.paperOrientation
    )
    let aspectRatio = PaperUtilities.paperAspectRatio(
      for: note.paperSize,
      orientation: note.paperOrientation
    )
    
    func adjustedSize(for baseSize: CGSize) -> CGSize {
      guard aspectRatio > 0 else { return baseSize }
      let area = baseSize.width * baseSize.height
      guard area > 0 else { return baseSize }
      let width = sqrt(area * aspectRatio)
      let height = area / width
      return CGSize(width: width, height: height)
    }
    
    // Extract drawing data for this page
    let drawing = extractDrawing(from: note, pageIndex: pageIndex)
    
    // Extract background images for this page
    let backgroundImages = extractBackgroundImages(from: note, pageIndex: pageIndex)
    
    // Extract overlay images (canvas images) for this page
    let overlayImages = extractOverlayImages(from: note, pageIndex: pageIndex)
    
    // Determine target size and scale
    let targetSize: CGSize
    let scale: CGFloat
    
    switch size {
    case .export:
      targetSize = paperSize
      scale = size.scale
    case .custom(let customSize):
      targetSize = customSize
      scale = size.scale
    case .grid, .list:
      targetSize = adjustedSize(for: size.dimensions)
      scale = size.scale
    }
    
    // Generate the preview using PaperUtilities
    let preview = PaperUtilities.generatePreviewWithBackground(
      drawing: drawing,
      paperSize: paperSize,
      paperColor: note.paperColor,
      paperStyle: note.paperStyle,
      scale: scale,
      backgroundImages: backgroundImages,
      overlayImages: overlayImages
    )
    
    // Apply corner radius if specified
    if let radius = cornerRadius {
      return applyCornerRadius(to: preview, radius: radius, targetSize: targetSize)
    }
    
    return preview
  }
  
  // MARK: - Drawing Extraction
  
  /// Extract PKDrawing for a specific page from a note
  private static func extractDrawing(from note: Note, pageIndex: Int) -> PKDrawing {
    guard let drawingData = note.drawingDataByPage[String(pageIndex)],
          let drawing = try? PKDrawing(data: drawingData) else {
      return PKDrawing() // Empty drawing if none exists
    }
    return drawing
  }
  
  // MARK: - Image Extraction
  
  /// Extract background images for a specific page
  private static func extractBackgroundImages(from note: Note, pageIndex: Int) -> [Data]? {
    return note.imageDataByPage[String(pageIndex)]
  }
  
  /// Extract overlay images (CanvasImage) for a specific page
  private static func extractOverlayImages(from note: Note, pageIndex: Int) -> [CanvasImage] {
    return PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: pageIndex)
  }
  
  // MARK: - Content Checks
  
  /// Check if a note has any visual content on a specific page
  static func hasContent(note: Note, pageIndex: Int = 0) -> Bool {
    // Check for drawing data
    if let drawingData = note.drawingDataByPage[String(pageIndex)],
       let drawing = try? PKDrawing(data: drawingData),
       !drawing.strokes.isEmpty {
      return true
    }
    
    // Check for images
    if let images = note.imageDataByPage[String(pageIndex)],
       !images.isEmpty {
      return true
    }
    
    // Check for text boxes
    if let textBoxes = note.textBoxDataByPage[String(pageIndex)],
       !textBoxes.isEmpty {
      return true
    }
    
    return false
  }
  
  /// Check if a note has uploaded content (images/PDFs)
  static func hasUploadedContent(note: Note, pageIndex: Int = 0) -> Bool {
    if let images = note.imageDataByPage[String(pageIndex)],
       !images.isEmpty {
      return true
    }
    return false
  }
  
  // MARK: - SwiftUI Image Helper
  
  /// Generate a SwiftUI Image preview
  static func generateSwiftUIPreview(
    for note: Note,
    pageIndex: Int = 0,
    size: PreviewSize = .grid
  ) -> Image {
    let uiImage = generatePreview(for: note, pageIndex: pageIndex, size: size)
    return Image(uiImage: uiImage)
  }
  
  // MARK: - Corner Radius Application
  
  private static func applyCornerRadius(
    to image: UIImage,
    radius: CGFloat,
    targetSize: CGSize
  ) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { context in
      let rect = CGRect(origin: .zero, size: targetSize)
      UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
      image.draw(in: rect)
    }
  }
  
  // MARK: - Multi-Page Preview Generation
  
  /// Generate previews for all pages in a note
  /// Useful for export or thumbnail strips
  static func generateAllPagePreviews(
    for note: Note,
    size: PreviewSize = .grid
  ) -> [UIImage] {
    let pageCount = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let totalPages = max(1, pageCount + 1)
    
    var previews: [UIImage] = []
    for pageIndex in 0..<totalPages {
      let preview = generatePreview(for: note, pageIndex: pageIndex, size: size)
      previews.append(preview)
    }
    
    return previews
  }
  
  // MARK: - Convenience Methods for Specific Views
  
  /// Generate preview specifically for grid view items
  static func generateGridPreview(for note: Note) -> UIImage {
    let cornerRadius: CGFloat = note.noteType == .written ? 10 : 0
    return generatePreview(for: note, pageIndex: 0, size: .grid, cornerRadius: cornerRadius)
  }
  
  /// Generate preview specifically for list view items
  static func generateListPreview(for note: Note) -> UIImage {
    let cornerRadius: CGFloat = note.noteType == .written ? 6 : 2
    return generatePreview(for: note, pageIndex: 0, size: .list, cornerRadius: cornerRadius)
  }
  
  /// Generate full-size preview for export
  static func generateExportPreview(for note: Note, pageIndex: Int) -> UIImage {
    return generatePreview(for: note, pageIndex: pageIndex, size: .export)
  }
  
  // MARK: - Background Color Helper
  
  /// Get the background color for a note based on whether it has content
  static func previewBackgroundColor(for note: Note) -> Color {
    if hasUploadedContent(note: note) {
      // If there's uploaded content, use the paper color
      return PaperUtilities.getPaperBackgroundColor(for: note.paperColor)
    } else {
      // Otherwise use the note's color
      return note.color
    }
  }
}

