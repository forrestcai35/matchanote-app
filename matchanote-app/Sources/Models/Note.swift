//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI
import PencilKit

// Paper properties enums
public enum PaperColor: String, CaseIterable, Codable {
  case white, offwhite, dark
}

public enum PaperStyle: String, CaseIterable, Codable {
  case grid, dotted, blank, lined
}

public enum PaperSize: String, CaseIterable, Codable {
  case legal, letter, tabloid, a4
}

// Define the type of note
public enum NoteType: String, CaseIterable, Codable {
  case written, text
}

public struct Note: Identifiable, Codable {
  public var id = UUID()
  public var title: String
  public var subject: String
  public var color: Color
  public var dateCreated: Date
  public var dateModified: Date
  public var lastOpenedAt: Date? = nil
  public var isFavorite: Bool = false
  public var content: String = ""
  public var noteType: NoteType = .written
  public var paperColor: PaperColor = .white
  public var paperStyle: PaperStyle = .blank
  public var paperSize: PaperSize = .a4
  // Store drawing data by page using String keys for better JSON compatibility
  public var drawingDataByPage: [String: Data] = [:]
  // Store image data by page
  public var imageDataByPage: [String: [Data]] = [:]
  // Store textbox data by page
  public var textBoxDataByPage: [String: [Data]] = [:]
  // Track which pages are bookmarked using page indices as Set
  public var bookmarkedPages: Set<Int> = []
  
  // MARK: - Codable Implementation
  private enum CodingKeys: String, CodingKey {
    case id, title, subject, colorString, dateCreated, dateModified, lastOpenedAt
    case isFavorite, content, noteType, paperColor, paperStyle, paperSize
    case drawingDataByPage, imageDataByPage, textBoxDataByPage, bookmarkedPages
  }
  
  // Custom encoding to handle Color serialization
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(subject, forKey: .subject)
    try container.encode(colorToHexString(color), forKey: .colorString)
    try container.encode(dateCreated, forKey: .dateCreated)
    try container.encode(dateModified, forKey: .dateModified)
    try container.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
    try container.encode(isFavorite, forKey: .isFavorite)
    try container.encode(content, forKey: .content)
    try container.encode(noteType, forKey: .noteType)
    try container.encode(paperColor, forKey: .paperColor)
    try container.encode(paperStyle, forKey: .paperStyle)
    try container.encode(paperSize, forKey: .paperSize)
    try container.encode(drawingDataByPage, forKey: .drawingDataByPage)
    try container.encode(imageDataByPage, forKey: .imageDataByPage)
    try container.encode(textBoxDataByPage, forKey: .textBoxDataByPage)
    try container.encode(bookmarkedPages, forKey: .bookmarkedPages)
  }
  
  // Custom decoding to handle Color deserialization
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    subject = try container.decode(String.self, forKey: .subject)
    let colorString = try container.decode(String.self, forKey: .colorString)
    color = hexStringToColor(colorString)
    dateCreated = try container.decode(Date.self, forKey: .dateCreated)
    dateModified = try container.decode(Date.self, forKey: .dateModified)
    lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    content = try container.decode(String.self, forKey: .content)
    noteType = try container.decode(NoteType.self, forKey: .noteType)
    paperColor = try container.decode(PaperColor.self, forKey: .paperColor)
    paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
    paperSize = try container.decode(PaperSize.self, forKey: .paperSize)
    drawingDataByPage = try container.decode([String: Data].self, forKey: .drawingDataByPage)
    imageDataByPage = try container.decode([String: [Data]].self, forKey: .imageDataByPage)
    textBoxDataByPage = try container.decode([String: [Data]].self, forKey: .textBoxDataByPage)
    bookmarkedPages = try container.decode(Set<Int>.self, forKey: .bookmarkedPages)
  }

  public init(
    title: String, subject: String = "", color: Color = .white, dateCreated: Date,
    dateModified: Date, lastOpenedAt: Date? = nil, isFavorite: Bool = false,
    content: String = "", noteType: NoteType,
    paperColor: PaperColor = .white,
    paperStyle: PaperStyle = .blank, paperSize: PaperSize = .a4,
    drawingDataByPage: [String: Data] = [:],
    imageDataByPage: [String: [Data]] = [:],
    textBoxDataByPage: [String: [Data]] = [:],
    bookmarkedPages: Set<Int> = []
  ) {
    self.title = title
    self.subject = subject
    self.color = color
    self.dateCreated = dateCreated
    self.dateModified = dateModified
    self.lastOpenedAt = lastOpenedAt
    self.isFavorite = isFavorite
    self.content = content
    self.noteType = noteType
    self.paperColor = paperColor
    self.paperStyle = paperStyle
    self.paperSize = paperSize
    self.drawingDataByPage = drawingDataByPage
    self.imageDataByPage = imageDataByPage
    self.textBoxDataByPage = textBoxDataByPage
    self.bookmarkedPages = bookmarkedPages
  }

}

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
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .dark:
      return Color(red: 0.15, green: 0.15, blue: 0.15)
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
  
  // MARK: - Preview Generation
  static func generatePreviewWithBackground(
    drawing: PKDrawing,
    paperSize: CGSize,
    paperColor: PaperColor,
    paperStyle: PaperStyle,
    scale: CGFloat,
    backgroundImages: [Data]? = nil
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
    
    // Draw the drawing on top
    let fullPageBounds = CGRect(origin: .zero, size: paperSize)
    let drawingImage = drawing.image(from: fullPageBounds, scale: effectiveScale)
    drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
    
    return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
  }
  
  // MARK: - Paper Pattern Drawing
  private static func drawPaperPattern(context: CGContext, paperStyle: PaperStyle, size: CGSize) {
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
    let gridSpacing: CGFloat = max(8, size.width / 30) // Adaptive spacing for thumbnail
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
    let baseSpacing: CGFloat = max(12, size.width / 20) // Adaptive spacing for thumbnail
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
    let lineSpacing: CGFloat = max(10, size.height / 20) // Adaptive spacing for thumbnail
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

// MARK: - Color Conversion Helpers
private func colorToHexString(_ color: Color) -> String {
  // Convert SwiftUI Color to UIColor and then to hex string
  let uiColor = UIColor(color)
  var red: CGFloat = 0
  var green: CGFloat = 0
  var blue: CGFloat = 0
  var alpha: CGFloat = 0
  
  uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
  
  let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
  return String(format: "#%06x", rgb)
}

private func hexStringToColor(_ hexString: String) -> Color {
  let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var int: UInt64 = 0
  Scanner(string: hex).scanHexInt64(&int)
  let a, r, g, b: UInt64
  switch hex.count {
  case 3: // RGB (12-bit)
    (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
  case 6: // RGB (24-bit)
    (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
  case 8: // ARGB (32-bit)
    (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
  default:
    return Color.white // Default fallback
  }
  
  return Color(
    red: Double(r) / 255,
    green: Double(g) / 255,
    blue: Double(b) / 255,
    opacity: Double(a) / 255
  )
}
