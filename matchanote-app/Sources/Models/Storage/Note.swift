

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
  case written
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


