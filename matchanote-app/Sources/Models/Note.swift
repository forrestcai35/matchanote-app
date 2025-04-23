//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI
import matchanote_app

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

  public init(
    title: String, subject: String = "", color: Color = .white, dateCreated: Date,
    dateModified: Date, isFavorite: Bool = false,
    content: String = "", noteType: NoteType,
    paperColor: PaperColor = .white,
    paperStyle: PaperStyle = .blank, paperSize: PaperSize = .a4
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
  }

  // Sample notes
  public static let samples = [
    Note(
      title: "Blank", color: .matchalight_light, dateCreated: Date(), dateModified: Date(),
      noteType: .written),
    Note(
      title: "Grid", color: .matchalight_light, dateCreated: Date(), dateModified: Date(),
      noteType: .written,
      paperStyle: .grid),
    Note(
      title: "Dotted", color: .matchalight_light, dateCreated: Date(),
      dateModified: Date(),
      noteType: .written,
      paperStyle: .dotted),
    Note(
      title: "Offwhite dotted", color: .matchalight_light, dateCreated: Date(),
      dateModified: Date(),
      noteType: .written,
      paperColor:.offwhite,
      paperStyle: .dotted),
    Note(
      title: "Offwhite dotted", color: .matchalight_light, dateCreated: Date(),
      dateModified: Date(),
      noteType: .written,
      paperColor:.dark,
      paperStyle: .dotted),
    
  ]
}
