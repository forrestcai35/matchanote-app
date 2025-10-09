//
//  Folder.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI

struct Folder: Identifiable, Hashable {
  var id = UUID()
  var name: String
  var color: Color
  var dateCreated: Date
  var dateModified: Date
  var isFavorite: Bool = false

  // Parent-child relationships
  var parentID: UUID?
  var childFolders: [Folder] = []
  var noteIDs: [UUID] = []

  // MARK: - Initialization
  init(
    name: String, color: Color = .blue,
    parentID: UUID? = nil, dateCreated: Date = Date()
  ) {
    self.name = name
    self.color = color
    self.parentID = parentID
    self.dateCreated = dateCreated
    self.dateModified = dateCreated

  }

  // MARK: - Helper computed properties

  /// Check if this folder is empty (has no notes and no subfolders)
  var isEmpty: Bool {
    return noteIDs.isEmpty && childFolders.isEmpty
  }

  /// Get the number of items in this folder (notes + subfolders)
  var itemCount: Int {
    return noteIDs.count + childFolders.count
  }

  // MARK: - Methods
  /// Add a subfolder to this folder
  mutating func addFolder(_ folder: Folder) {
    var newFolder = folder
    newFolder.parentID = self.id
    childFolders.append(newFolder)
    updateModificationDate()
  }

  /// Remove a subfolder by ID
  mutating func removeFolder(id: UUID) {
    childFolders.removeAll(where: { $0.id == id })
    updateModificationDate()
  }

  /// Add a note to this folder (store its ID)
  mutating func addNote(noteID: UUID) {
    noteIDs.append(noteID)
    updateModificationDate()
  }

  /// Remove a note by ID
  mutating func removeNote(id: UUID) {
    noteIDs.removeAll(where: { $0 == id })
    updateModificationDate()
  }

  /// Rename folder
  mutating func rename(to newName: String) {
    name = newName
    updateModificationDate()
  }

  /// Change folder color
  mutating func changeColor(to newColor: Color) {
    color = newColor
    updateModificationDate()
  }

  /// Toggle favorite status
  mutating func toggleFavorite() {
    isFavorite.toggle()
    updateModificationDate()
  }

  /// Update modification date to current time
  private mutating func updateModificationDate() {
    dateModified = Date()
  }

  // MARK: - Hashable Conformance
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Folder, rhs: Folder) -> Bool {
    lhs.id == rhs.id
  }

  static var samples: [Folder] {
    [
      Folder(name: "Documents", color: .blue),
      Folder(name: "Projects", color: .blue),
      Folder(name: "School", color: .blue),
      Folder(name: "Work", color: .blue),
      Folder(name: "Personal", color: .blue),
    ]
  }
}
