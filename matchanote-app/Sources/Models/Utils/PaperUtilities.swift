import SwiftUI
import PencilKit


// MARK: - Paper Utilities
struct PaperUtilities {
  
  // MARK: - Paper Dimensions
  static func getPaperWidth(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 612  // 8.5 x 14 inches at 72 dpi
    case .letter:
      return 612  // 8.5 x 11 inches at 72 dpi
    case .tabloid:
      return 792  // 11 x 17 inches at 72 dpi
    case .a4:
      return 595  // 210 × 297 mm at 72 dpi
    }
  }
  
  static func getPaperHeight(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 1008  // 8.5 x 14 inches at 72 dpi
    case .letter:
      return 792  // 8.5 x 11 inches at 72 dpi
    case .tabloid:
      return 1224  // 11 x 17 inches at 72 dpi
    case .a4:
      return 842  // 210 × 297 mm at 72 dpi
    }
  }
  
  // MARK: - Paper Background Colors
  static func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color.paper_offwhite
    case .dark:
      return Color.paper_dark
    }
  }
  
  // MARK: - Convenience Properties
  static func paperSize(for size: PaperSize) -> CGSize {
    return CGSize(
      width: getPaperWidth(for: size),
      height: getPaperHeight(for: size)
    )
  }
  
  static func paperAspectRatio(for size: PaperSize) -> CGFloat {
    let width = getPaperWidth(for: size)
    let height = getPaperHeight(for: size)
    return width / height
  }
  
  // MARK: - Helper function to extract CanvasImage objects from imageDataByPage
  static func extractCanvasImages(from imageDataByPage: [String: [Data]], for pageIndex: Int) -> [CanvasImage] {
    guard let imageDataArray = imageDataByPage[String(pageIndex)] else { return [] }
    
    var canvasImages: [CanvasImage] = []
    for imageData in imageDataArray {
      if let canvasImage = try? JSONDecoder().decode(CanvasImage.self, from: imageData) {
        canvasImages.append(canvasImage)
      }
    }
    return canvasImages
  }
  
  // MARK: - Preview Generation
  static func generatePreviewWithBackground(
    drawing: PKDrawing,
    paperSize: CGSize,
    paperColor: PaperColor,
    paperStyle: PaperStyle,
    scale: CGFloat,
    backgroundImages: [Data]? = nil,
    overlayImages: [CanvasImage]? = nil
  ) -> UIImage {
    let thumbnailSize = CGSize(
      width: paperSize.width * scale,
      height: paperSize.height * scale
    )
    
    let screenScale = UIScreen.main.scale
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
    let paperBackgroundColor = getPaperBackgroundColor(for: paperColor)
    UIColor(paperBackgroundColor).setFill()
    context.fill(CGRect(origin: .zero, size: thumbnailSize))
    
    // Draw background images first if provided
    if let backgroundImages = backgroundImages {
      for imageData in backgroundImages {
        if let backgroundImage = UIImage(data: imageData) {
          backgroundImage.draw(in: CGRect(origin: .zero, size: thumbnailSize), blendMode: .normal, alpha: 1.0)
        }
      }
    }
    
    // Draw paper pattern on top of background images
    drawPaperPattern(context: context, paperStyle: paperStyle, size: thumbnailSize)
    
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
  
  // MARK: - Paper Pattern Drawing
  public static func drawPaperPattern(context: CGContext, paperStyle: PaperStyle, size: CGSize) {
    switch paperStyle {
    case .blank:
      return
    case .grid:
      drawGridPattern(context: context, size: size)
    case .dotted:
      drawDottedPattern(context: context, size: size)
    case .lined:
      drawLinedPattern(context: context, size: size)
    }
  }
  
  private static func drawGridPattern(context: CGContext, size: CGSize) {
    let gridSpacing: CGFloat = max(8, size.width / 22) // Adaptive spacing for thumbnail
    let lineColor = UIColor.gray.withAlphaComponent(0.25)
    
    context.setStrokeColor(lineColor.cgColor)
    context.setLineWidth(0.6)
    
    // Horizontal lines
    for i in 0..<Int(size.height / gridSpacing + 1) {
      let y = CGFloat(i) * gridSpacing
      context.move(to: CGPoint(x: 0, y: y))
      context.addLine(to: CGPoint(x: size.width, y: y))
    }
    
    // Vertical lines
    for i in 0..<Int(size.width / gridSpacing + 1) {
      let x = CGFloat(i) * gridSpacing
      context.move(to: CGPoint(x: x, y: 0))
      context.addLine(to: CGPoint(x: x, y: size.height))
    }
    
    context.strokePath()
  }
  
  private static func drawDottedPattern(context: CGContext, size: CGSize) {
    let baseSpacing: CGFloat = max(12, size.width / 18) // Adaptive spacing for thumbnail
    let dotRadius: CGFloat = 1.0
    let dotColor = UIColor.gray.withAlphaComponent(0.5)
    
    context.setFillColor(dotColor.cgColor)
    
    let horizontalCount = Int(size.width / baseSpacing)
    let verticalCount = Int(size.height / baseSpacing)
    
    for row in 0...verticalCount {
      for col in 0...horizontalCount {
        let x = CGFloat(col) * baseSpacing
        let y = CGFloat(row) * baseSpacing
        
        let dotRect = CGRect(
          x: x - dotRadius,
          y: y - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        )
        context.fillEllipse(in: dotRect)
      }
    }
  }
  
  private static func drawLinedPattern(context: CGContext, size: CGSize) {
    let lineSpacing: CGFloat = max(10, size.height / 24) // Adaptive spacing for thumbnail
    let lineColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.25) // More subtle gray
    
    context.setStrokeColor(lineColor.cgColor)
    context.setLineWidth(0.6)
    
    for i in 0..<Int(size.height / lineSpacing + 1) {
      let y = CGFloat(i) * lineSpacing
      context.move(to: CGPoint(x: 0, y: y))
      context.addLine(to: CGPoint(x: size.width, y: y))
    }
    
    context.strokePath()
  }
}
