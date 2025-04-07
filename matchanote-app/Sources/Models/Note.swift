//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI

// Paper properties enums
public enum PaperColor: String, CaseIterable {
  case white, offwhite, yellow
}

public enum PaperStyle: String, CaseIterable {
  case grid, dotted, blank, lined
}

public enum PaperSize: String, CaseIterable {
  case legal, letter, tabloid, a4
}

public enum ScrollType: String, CaseIterable {
  case pages, infinite
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
  public var scrollType: ScrollType = .pages

  public init(
    title: String, color: Color, dateCreated: Date, dateModified: Date, isFavorite: Bool = false,
    content: String = "", noteType: NoteType = .written,
    paperColor: PaperColor = .white,
    paperStyle: PaperStyle = .grid, paperSize: PaperSize = .a4,
    scrollType: ScrollType = .pages
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
    self.scrollType = scrollType
  }

  // Sample notes
  public static let samples = [
    Note(
      title: "Study", color: .green, dateCreated: Date(), dateModified: Date(), noteType: .written),
    Note(
      title: "Getting started with Matcha", color: .blue, dateCreated: Date(), dateModified: Date(),
      noteType: .markdown, scrollType: .infinite),
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
      noteType: .markdown, scrollType: .infinite),
    Note(
      title: "Shakespeare", color: .black, dateCreated: Date(), dateModified: Date(),
      noteType: .written),
  ]
}
