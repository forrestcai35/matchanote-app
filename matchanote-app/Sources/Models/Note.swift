//
//  Note.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/2/25.
//

import SwiftUI

// Make sure this is visible to the whole app
public struct Note: Identifiable {
  public var id = UUID()
  public var title: String
  public var color: Color
  public var dateCreated: Date
  public var dateModified: Date
  public var isFavorite: Bool = false
  public var content: String = ""
  public var isWritten: Bool = true

  public init(
    title: String, color: Color, dateCreated: Date, dateModified: Date, isFavorite: Bool = false,
    content: String = "", isWritten: Bool = true
  ) {
    self.title = title
    self.color = color
    self.dateCreated = dateCreated
    self.dateModified = dateModified
    self.isFavorite = isFavorite
    self.content = content
    self.isWritten = isWritten
  }

  // Sample notes
  public static let samples = [
    Note(title: "Study", color: .green, dateCreated: Date(), dateModified: Date()),
    Note(
      title: "Getting started with Matcha", color: .blue, dateCreated: Date(), dateModified: Date()),
    Note(
      title: "Interior Design", color: .purple, dateCreated: Date(), dateModified: Date()),
    Note(title: "Workout Planner", color: .pink, dateCreated: Date(), dateModified: Date()),
    Note(title: "Smart City", color: .blue, dateCreated: Date(), dateModified: Date()),
    Note(title: "Shakespeare", color: .black, dateCreated: Date(), dateModified: Date()),
  ]
}
