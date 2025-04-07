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
  var icon: String
  var color: Color
  var dateCreated: Date
  var dateModified: Date
  var isFavorite: Bool = false

  // Parent-child relationships
  var parentID: UUID?
  var childFolders: [Folder] = []
  var noteIDs: [UUID] = []  // Store IDs instead of actual notes to avoid circular dependencies

  // MARK: - Initialization
  init(
    name: String, icon: String = "folder", color: Color = .blue,
    parentID: UUID? = nil, dateCreated: Date = Date(), isFavorite: Bool = false
  ) {
    self.name = name
    self.icon = icon
    self.color = color
    self.parentID = parentID
    self.dateCreated = dateCreated
    self.dateModified = dateCreated
    self.isFavorite = isFavorite
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

  /// Toggle favorite status
  mutating func toggleFavorite() {
    isFavorite.toggle()
    updateModificationDate()
  }

  /// Rename folder
  mutating func rename(to newName: String) {
    name = newName
    updateModificationDate()
  }

  /// Change folder icon
  mutating func changeIcon(to newIcon: String) {
    icon = newIcon
    updateModificationDate()
  }

  /// Change folder color
  mutating func changeColor(to newColor: Color) {
    color = newColor
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

  // MARK: - Sample Data
  /// Create sample folders for preview and testing
  static var samples: [Folder] {
    [
      Folder(name: "Documents", icon: "folder", color: .blue),
      Folder(name: "Projects", icon: "folder.fill", color: .green),
      Folder(name: "School", icon: "book.closed", color: .orange),
      Folder(name: "Work", icon: "briefcase", color: .purple, isFavorite: true),
      Folder(name: "Personal", icon: "person", color: .pink),
    ]
  }
}
