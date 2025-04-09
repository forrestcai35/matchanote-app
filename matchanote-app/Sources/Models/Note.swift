//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI

// Paper properties enums
public enum PaperColor: String, CaseIterable, Codable {
  case white, offwhite, yellow
}

public enum PaperStyle: String, CaseIterable, Codable {
  case grid, dotted, blank, lined
}

public enum PaperSize: String, CaseIterable, Codable {
  case legal, letter, tabloid, a4
}

// Define the type of note
public enum NoteType: String, CaseIterable {
  case written, text, markdown
}

public struct Note: Identifiable {
  public var id = UUID()
  public var title: String
  public var color: Color
  public var dateCreated: Date
  public var dateModified: Date
  public var isFavorite: Bool = false
  public var content: String = ""
  public var noteType: NoteType = .written
  public var paperColor: PaperColor = .white
  public var paperStyle: PaperStyle = .blank
  public var paperSize: PaperSize = .a4

  public init(
    title: String, color: Color, dateCreated: Date, dateModified: Date, isFavorite: Bool = false,
    content: String = "", noteType: NoteType = .written,
    paperColor: PaperColor = .white,
    paperStyle: PaperStyle = .blank, paperSize: PaperSize = .a4
  ) {
    self.title = title
    self.color = color
    self.dateCreated = dateCreated
    self.dateModified = dateModified
    self.isFavorite = isFavorite
    self.content = content
    self.noteType = noteType
    self.paperColor = paperColor
    self.paperStyle = paperStyle
    self.paperSize = paperSize
  }

  // Sample notes
  public static let samples = [
    Note(
      title: "Blank", color: .green, dateCreated: Date(), dateModified: Date(), noteType: .written),
    Note(
      title: "Grid", color: .green, dateCreated: Date(), dateModified: Date(), noteType: .written,
      paperStyle: .grid),
    Note(
      title: "Written grid infinite", color: .green, dateCreated: Date(), dateModified: Date(),
      noteType: .written,
      paperStyle: .grid),

    Note(
      title: "Markdown", color: .blue, dateCreated: Date(), dateModified: Date(),
      noteType: .markdown),

    Note(
      title: "Meeting Notes", color: .orange, dateCreated: Date(), dateModified: Date(),
      noteType: .text),
    Note(
      title: "Interior Design", color: .purple, dateCreated: Date(), dateModified: Date(),
      noteType: .written),
    Note(
      title: "Workout Planner", color: .pink, dateCreated: Date(), dateModified: Date(),
      noteType: .text),
    Note(
      title: "Smart City", color: .blue, dateCreated: Date(), dateModified: Date(),
      noteType: .markdown),
    Note(
      title: "Shakespeare", color: .black, dateCreated: Date(), dateModified: Date(),
      noteType: .written),
  ]
}
