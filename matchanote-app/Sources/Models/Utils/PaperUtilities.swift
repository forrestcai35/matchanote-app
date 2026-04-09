import SwiftUI
import PencilKit


// MARK: - Paper Utilities
struct PaperUtilities {
  
  // MARK: - Paper Dimensions

  // Base dimensions (portrait orientation)
  private static func getBaseWidth(for size: PaperSize) -> CGFloat {
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

  private static func getBaseHeight(for size: PaperSize) -> CGFloat {
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

  // Public functions with orientation support
  static func getPaperWidth(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGFloat {
    let baseWidth = getBaseWidth(for: size)
    let baseHeight = getBaseHeight(for: size)
    return orientation == .portrait ? baseWidth : baseHeight
  }

  static func getPaperHeight(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGFloat {
    let baseWidth = getBaseWidth(for: size)
    let baseHeight = getBaseHeight(for: size)
    return orientation == .portrait ? baseHeight : baseWidth
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
  static func paperSize(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGSize {
    return CGSize(
      width: getPaperWidth(for: size, orientation: orientation),
      height: getPaperHeight(for: size, orientation: orientation)
    )
  }

  static func paperAspectRatio(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGFloat {
    let width = getPaperWidth(for: size, orientation: orientation)
    let height = getPaperHeight(for: size, orientation: orientation)
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
  
  // MARK: - SwiftUI Pattern Views
  /// Returns the appropriate vectorized paper pattern as a SwiftUI View
  @ViewBuilder
  public static func paperPatternView(
    paperStyle: PaperStyle,
    isDarkBackground: Bool
  ) -> some View {
    switch paperStyle {
    case .blank:
      EmptyView()
      
    case .grid:
      let gridSpacing: CGFloat = 20
      let lineColor = isDarkBackground ? Color.white.opacity(0.3) : Color.gray.opacity(0.3)
      GridPatternShape(gridSpacing: gridSpacing)
        .stroke(lineColor, lineWidth: 0.75)
      
    case .dotted:
      let baseSpacing: CGFloat = 18
      let dotRadius: CGFloat = 1
      let margin: CGFloat = baseSpacing
      let dotColor = isDarkBackground ? Color.white.opacity(0.35) : Color.gray.opacity(0.35)
      DottedPatternShape(dotSpacing: baseSpacing, dotRadius: dotRadius, margin: margin)
        .fill(dotColor)
      
    case .lined:
      let lineSpacing: CGFloat = 24
      let marginTop: CGFloat = 30
      let lineColor = isDarkBackground ? Color.white.opacity(0.3) : Color.gray.opacity(0.3)
      LinedPatternShape(lineSpacing: lineSpacing, marginTop: marginTop)
        .stroke(lineColor, lineWidth: 0.75)
    }
  }
  
  // MARK: - Paper Pattern Drawing (Using Vectorized Shapes)
  public static func drawPaperPattern(context: CGContext, paperStyle: PaperStyle, size: CGSize) {
    let rect = CGRect(origin: .zero, size: size)
    
    switch paperStyle {
    case .blank:
      return
    case .grid:
      let gridSpacing: CGFloat = 20  // Match paperPatternView
      let shape = GridPatternShape(gridSpacing: gridSpacing)
      let path = shape.path(in: rect)
      
      context.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
      context.setLineWidth(0.75)
      context.addPath(path.cgPath)
      context.strokePath()
      
    case .dotted:
      let baseSpacing: CGFloat = 18  // Match paperPatternView
      let dotRadius: CGFloat = 1
      let margin: CGFloat = baseSpacing
      let shape = DottedPatternShape(dotSpacing: baseSpacing, dotRadius: dotRadius, margin: margin)
      let path = shape.path(in: rect)
      
      context.setFillColor(UIColor.gray.withAlphaComponent(0.35).cgColor)
      context.addPath(path.cgPath)
      context.fillPath()
      
    case .lined:
      let lineSpacing: CGFloat = 24  // Match paperPatternView
      let marginTop: CGFloat = 30
      let shape = LinedPatternShape(lineSpacing: lineSpacing, marginTop: marginTop)
      let path = shape.path(in: rect)
      
      context.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
      context.setLineWidth(0.75)
      context.addPath(path.cgPath)
      context.strokePath()
    }
  }
}

// MARK: - Vectorized Paper Pattern Shapes
/// Vectorized grid pattern shape for scalable, resolution-independent rendering
struct GridPatternShape: Shape {
  let gridSpacing: CGFloat
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    // Horizontal lines
    var y: CGFloat = 0
    while y <= rect.height {
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: rect.width, y: y))
      y += gridSpacing
    }
    
    // Vertical lines
    var x: CGFloat = 0
    while x <= rect.width {
      path.move(to: CGPoint(x: x, y: 0))
      path.addLine(to: CGPoint(x: x, y: rect.height))
      x += gridSpacing
    }
    
    return path
  }
}

/// Vectorized dotted pattern shape for scalable, resolution-independent rendering
struct DottedPatternShape: Shape {
  let dotSpacing: CGFloat
  let dotRadius: CGFloat
  let margin: CGFloat
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    // Match original dynamic spacing logic with margins
    let availableWidth = rect.width - 2 * margin
    let availableHeight = rect.height - 2 * margin
    
    let horizontalIntervals = max(1, Int(availableWidth / dotSpacing))
    let verticalIntervals = max(1, Int(availableHeight / dotSpacing))
    
    let horizontalSpacing = availableWidth / CGFloat(horizontalIntervals)
    let verticalSpacing = availableHeight / CGFloat(verticalIntervals)
    
    for y in 0...verticalIntervals {
      for x in 0...horizontalIntervals {
        let xPos = margin + CGFloat(x) * horizontalSpacing
        let yPos = margin + CGFloat(y) * verticalSpacing
        
        let dotRect = CGRect(
          x: xPos - dotRadius,
          y: yPos - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        )
        path.addEllipse(in: dotRect)
      }
    }
    
    return path
  }
}

/// Vectorized lined pattern shape for scalable, resolution-independent rendering
struct LinedPatternShape: Shape {
  let lineSpacing: CGFloat
  let marginTop: CGFloat
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    var y: CGFloat = marginTop
    while y <= rect.height {
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: rect.width, y: y))
      y += lineSpacing
    }
    
    return path
  }
}

/// SwiftUI View wrapper for paper background with vectorized patterns
struct PaperBackgroundView: View {
  let paperColor: PaperColor
  let paperStyle: PaperStyle
  let paperSize: CGSize
  
  var body: some View {
    ZStack {
      // Background color
      PaperUtilities.getPaperBackgroundColor(for: paperColor)
      
      // Vectorized pattern overlay
      Group {
        switch paperStyle {
        case .blank:
          EmptyView()
        case .grid:
          GridPatternShape(gridSpacing: max(20, paperSize.width / 22))
            .stroke(Color.gray.opacity(0.25), lineWidth: 0.6)
        case .dotted:
          let dotSpacing = max(24, paperSize.width / 18)
          let dotRadius: CGFloat = 1.5
          let margin = dotSpacing
          DottedPatternShape(
            dotSpacing: dotSpacing,
            dotRadius: dotRadius,
            margin: margin
          )
          .fill(Color.gray.opacity(0.5))
        case .lined:
          let lineSpacing = max(24, paperSize.height / 24)
          LinedPatternShape(lineSpacing: lineSpacing, marginTop: 0)
            .stroke(Color.gray.opacity(0.25), lineWidth: 0.6)
        }
      }
    }
    .frame(width: paperSize.width, height: paperSize.height)
  }
}
