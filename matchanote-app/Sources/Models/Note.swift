//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI

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
public enum NoteType: String, CaseIterable {
  case written, text
}

public struct Note: Identifiable {
  public var id = UUID()
  public var title: String
  public var subject: String
  public var color: Color
  public var dateCreated: Date
  public var dateModified: Date
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
  // Track which pages are bookmarked using page indices as Set
  public var bookmarkedPages: Set<Int> = []

  public init(
    title: String, subject: String = "", color: Color = .white, dateCreated: Date,
    dateModified: Date, isFavorite: Bool = false,
    content: String = "", noteType: NoteType,
    paperColor: PaperColor = .white,
    paperStyle: PaperStyle = .blank, paperSize: PaperSize = .a4,
    drawingDataByPage: [String: Data] = [:],
    imageDataByPage: [String: [Data]] = [:],
    bookmarkedPages: Set<Int> = []
  ) {
    self.title = title
    self.subject = subject
    self.color = color
    self.dateCreated = dateCreated
    self.dateModified = dateModified
    self.isFavorite = isFavorite
    self.content = content
    self.noteType = noteType
    self.paperColor = paperColor
    self.paperStyle = paperStyle
    self.paperSize = paperSize
    self.drawingDataByPage = drawingDataByPage
    self.imageDataByPage = imageDataByPage
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
      return Color(red: 0.1961, green: 0.1961, blue: 0.2000)
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
}
