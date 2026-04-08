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
    
    // Extract textboxes for this page
    let textBoxes = extractTextBoxes(from: note, pageIndex: pageIndex)

    // If the background is a vector PDF, render it explicitly to preserve crispness
    var preview: UIImage
    if let firstData = note.imageDataByPage[String(pageIndex)]?.first,
       let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
      let thumbnailSize = CGSize(width: paperSize.width * scale, height: paperSize.height * scale)
      let screenScale: CGFloat = 2.0
      UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, screenScale)
      defer { UIGraphicsEndImageContext() }
      guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }

      // Background color
      UIColor(PaperUtilities.getPaperBackgroundColor(for: note.paperColor)).setFill()
      ctx.fill(CGRect(origin: .zero, size: thumbnailSize))

      // PDF background (top aligned for previews)
      let fileURL = AttachmentManager.fileURL(for: pdfBg.relativePath)
      PDFDrawingUtils.draw(
        pdf: fileURL,
        pageIndex: pdfBg.pageIndex,
        in: ctx,
        bounds: CGRect(origin: .zero, size: thumbnailSize),
        backgroundColor: .white,
        verticalAlignment: .top
      )


      // Overlay images
      for canvasImage in overlayImages {
        if let overlayUIImage = UIImage(data: canvasImage.imageData) {
          if canvasImage.rotation != 0 {
            ctx.saveGState()
            let centerX = canvasImage.position.x * scale + (canvasImage.size.width * scale) / 2
            let centerY = canvasImage.position.y * scale + (canvasImage.size.height * scale) / 2
            ctx.translateBy(x: centerX, y: centerY)
            ctx.rotate(by: canvasImage.rotation)
            ctx.translateBy(x: -centerX, y: -centerY)
          }
          let rect = CGRect(x: canvasImage.position.x * scale,
                            y: canvasImage.position.y * scale,
                            width: canvasImage.size.width * scale,
                            height: canvasImage.size.height * scale)
          overlayUIImage.draw(in: rect)
          if canvasImage.rotation != 0 { ctx.restoreGState() }
        }
      }

      // Text boxes
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
          ctx.saveGState()
          let centerX = scaledPosition.x + scaledSize.width / 2
          let centerY = scaledPosition.y + scaledSize.height / 2
          ctx.translateBy(x: centerX, y: centerY)
          ctx.rotate(by: CGFloat(textBox.rotation) * .pi / 180)
          ctx.translateBy(x: -centerX, y: -centerY)
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
          ctx.restoreGState()
        }
      }

      // Drawing
      let fullPageBounds = CGRect(origin: .zero, size: paperSize)
      let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)
      var drawingImage: UIImage!
      lightTraitCollection.performAsCurrent {
        drawingImage = drawing.image(from: fullPageBounds, scale: 3.0)
      }
      drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))

      preview = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    } else {
      // Generate the preview using the component-based method (raster backgrounds)
      preview = generatePreviewFromComponents(
        drawing: drawing,
        paperSize: paperSize,
        paperColor: note.paperColor,
        paperStyle: note.paperStyle,
        scale: scale,
        backgroundImages: backgroundImages,
        overlayImages: overlayImages,
        textBoxes: textBoxes
      )
    }
    
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
  /// Filters out CanvasImage objects to avoid double-rendering
  private static func extractBackgroundImages(from note: Note, pageIndex: Int) -> [Data]? {
    guard let allImageData = note.imageDataByPage[String(pageIndex)] else { return nil }

    // Filter out CanvasImage objects - they should only be rendered as overlays
    let backgroundOnly = allImageData.filter { imageData in
      // Try to decode as CanvasImage - if it succeeds, exclude it from backgrounds
      if let _ = try? JSONDecoder().decode(CanvasImage.self, from: imageData) {
        return false
      }
      return true
    }

    return backgroundOnly.isEmpty ? nil : backgroundOnly
  }

  /// Extract overlay images (CanvasImage) for a specific page
  private static func extractOverlayImages(from note: Note, pageIndex: Int) -> [CanvasImage] {
    return PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: pageIndex)
  }

  /// Extract textboxes for a specific page
  private static func extractTextBoxes(from note: Note, pageIndex: Int) -> [TextBox] {
    guard let textBoxDataArray = note.textBoxDataByPage[String(pageIndex)] else { return [] }

    var textBoxes: [TextBox] = []
    for textBoxData in textBoxDataArray {
      if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
        textBoxes.append(textBox)
      }
    }
    return textBoxes
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

  // MARK: - Low-Level Preview Generation (for contexts without Note object)

  /// Generate preview from raw components (used by NoteContextProvider)
  static func generatePreviewFromComponents(
    drawing: PKDrawing,
    paperSize: CGSize,
    paperColor: PaperColor,
    paperStyle: PaperStyle,
    scale: CGFloat,
    backgroundImages: [Data]? = nil,
    overlayImages: [CanvasImage]? = nil,
    textBoxes: [TextBox]? = nil,
    screenScale: CGFloat = 2.0
  ) -> UIImage {
    let thumbnailSize = CGSize(
      width: paperSize.width * scale,
      height: paperSize.height * scale
    )

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

    // Draw background images first if provided
    let hasBackgroundImages = backgroundImages?.isEmpty == false
    if let backgroundImages = backgroundImages {
      for imageData in backgroundImages {
        if let backgroundImage = UIImage(data: imageData) {
          backgroundImage.draw(in: CGRect(origin: .zero, size: thumbnailSize), blendMode: .normal, alpha: 1.0)
        }
      }
    }

    // Only draw paper pattern if there are no background images (imported PDFs/images)
    if !hasBackgroundImages {
      PaperUtilities.drawPaperPattern(context: context, paperStyle: paperStyle, size: thumbnailSize)
    }

    // Draw overlay images if provided
    if let overlayImages = overlayImages {
      for canvasImage in overlayImages {
        if let overlayUIImage = UIImage(data: canvasImage.imageData) {
          // Calculate the scaled position and size for the overlay image
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

          // Draw the overlay image
          overlayUIImage.draw(in: CGRect(origin: scaledPosition, size: scaledSize))

          // Restore context if rotation was applied
          if canvasImage.rotation != 0 {
            context.restoreGState()
          }
        }
      }
    }

    // Draw textboxes if provided
    if let textBoxes = textBoxes {
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
    }

    // Draw the drawing on top
    // Force light mode for consistent preview appearance
    let fullPageBounds = CGRect(origin: .zero, size: paperSize)
    let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)
    var drawingImage: UIImage!
    lightTraitCollection.performAsCurrent {
      drawingImage = drawing.image(from: fullPageBounds, scale: effectiveScale)
    }
    drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))

    return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
  }
}
