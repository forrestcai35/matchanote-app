import Foundation
import Supabase
import SwiftUI


struct StorageNote: Codable {
  var id: UUID
  var title: String
  var subject: String
  var colorString: String
  var dateCreated: Date
  var dateModified: Date
  var isFavorite: Bool
  var content: String
  var noteType: String
  var paperColor: String
  var paperStyle: String
  var paperSize: String

  init(from note: Note) {
    self.id = note.id
    self.title = note.title
    self.subject = note.subject
    self.colorString = colorToString(note.color)
    self.dateCreated = note.dateCreated
    self.dateModified = note.dateModified
    self.isFavorite = note.isFavorite
    self.content = note.content
    self.noteType = note.noteType.rawValue
    self.paperColor = note.paperColor.rawValue
    self.paperStyle = note.paperStyle.rawValue
    self.paperSize = note.paperSize.rawValue
  }

  func toNote() -> Note {
    return Note(
      title: title,
      subject: subject,
      color: stringToColor(colorString),
      dateCreated: dateCreated,
      dateModified: dateModified,
      isFavorite: isFavorite,
      content: content,
      noteType: NoteType(rawValue: noteType) ?? .written,
      paperColor: PaperColor(rawValue: paperColor) ?? .white,
      paperStyle: PaperStyle(rawValue: paperStyle) ?? .blank,
      paperSize: PaperSize(rawValue: paperSize) ?? .a4
    )
  }
}

struct StorageFolder: Codable {
  var id: UUID
  var name: String
  var colorString: String
  var dateCreated: Date
  var dateModified: Date
  var isFavorite: Bool
  var parentID: UUID?
  var childFolderIDs: [UUID]
  var noteIDs: [UUID]


  init(from folder: Folder) {
    self.id = folder.id
    self.name = folder.name
    self.colorString = colorToString(folder.color)
    self.dateCreated = folder.dateCreated
    self.dateModified = folder.dateModified
    self.isFavorite = folder.isFavorite
    self.parentID = folder.parentID
    self.childFolderIDs = folder.childFolders.map { $0.id }
    self.noteIDs = folder.noteIDs
  }


  func toFolder() -> Folder {
    var folder = Folder(
      name: name,
      color: stringToColor(colorString),
      parentID: parentID,
      dateCreated: dateCreated,
      isFavorite: isFavorite
    )
    folder.id = id
    folder.dateModified = dateModified
    folder.noteIDs = noteIDs
    return folder
  }
}


func colorToString(_ color: Color) -> String {
  if color == .blue { return "blue" }
  if color == .red { return "red" }
  if color == .green { return "green" }
  if color == .yellow { return "yellow" }
  if color == .orange { return "orange" }
  if color == .purple { return "purple" }
  if color == .pink { return "pink" }
  if color == .white { return "white" }
  if color == .black { return "black" }
  if color == .gray { return "gray" }
  if color == .matchalight_light { return "matchalight_light" }
  if color == .matchadark_light { return "matchadark_light" }
  if color == .matchabrown_dark { return "matchabrown_dark" }
  if color == .matchabrown_light { return "matchabrown_light" }
  if color == .matchalight_dark { return "matchalight_dark" }
  if color == .matchadark_dark { return "matchadark_dark" }
  if color == .matchabackground_dark { return "matchabackground_dark" }
  if color == .matchabackground_light { return "matchabackground_light" }
  return "blue" 
}

func stringToColor(_ string: String) -> Color {
  switch string {
  case "blue": return .blue
  case "red": return .red
  case "green": return .green
  case "yellow": return .yellow
  case "orange": return .orange
  case "purple": return .purple
  case "pink": return .pink
  case "white": return .white
  case "black": return .black
  case "gray": return .gray
  case "matchalight_light": return .matchalight_light
  case "matchalight_dark": return .matchalight_dark
  case "matchadark_light": return .matchadark_light
  case "matchadark_dark": return .matchadark_dark
  case "matchabrown_dark": return .matchabrown_dark
  case "matchabrown_light": return .matchabrown_light
  case "matchabackground_dark": return .matchabackground_dark
  case "matchabackground_light": return .matchabackground_light
  default: return .blue
  }
}

class StorageManager: ObservableObject {
  @Published var folders: [Folder] = []
  @Published var notes: [Note] = []
  
  private let localStorageURL: URL

  private let notesFileName = "notes.json"
  private let foldersFileName = "folders.json"

  init() {

    guard
      let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first
    else {
      fatalError("Could not access document directory")
    }
    self.localStorageURL = documentDirectory

    loadData()
  }

  // MARK: - Data Operations

  func saveNote(_ note: Note) {
    // If user is non-premium or user storage is full, save to local storage
    saveNoteLocally(note)

    // In the future: save to Supabase if user is premium
    // saveNoteToSupabase(note)
  }

  func saveFolder(_ folder: Folder) {
    // If user is non-premium or user storage is full, save to local storage
    saveFolderLocally(folder)

    // In the future: save to Supabase if user is premium
    // saveFolderToSupabase(folder)
  }

  private func loadData() {
    // Load from local storage
    loadLocalData()

    // In the future: sync with Supabase
    // syncWithSupabase()
  }

  private func loadLocalData() {
    loadNotesFromLocal()
    loadFoldersFromLocal()

    // After loading notes and folders, resolve folder hierarchy
    resolveFolderHierarchy()
  }

  private func loadNotesFromLocal() {
    let notesURL = localStorageURL.appendingPathComponent(notesFileName)

    guard FileManager.default.fileExists(atPath: notesURL.path) else {
      return
    }

    do {
      let data = try Data(contentsOf: notesURL)
      let decoder = JSONDecoder()
      let storageNotes = try decoder.decode([StorageNote].self, from: data)
      self.notes = storageNotes.map { $0.toNote() }
    } catch {
      print("Error loading notes: \(error)")
    }
  }

  private func loadFoldersFromLocal() {
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)

    guard FileManager.default.fileExists(atPath: foldersURL.path) else {
      return
    }

    do {
      let data = try Data(contentsOf: foldersURL)
      let decoder = JSONDecoder()
      let storageFolders = try decoder.decode([StorageFolder].self, from: data)

      // First pass: create folders without child folders
      var tempFolders: [UUID: Folder] = [:]
      for storageFolder in storageFolders {
        tempFolders[storageFolder.id] = storageFolder.toFolder()
      }

      // Second pass: populate childFolders arrays
      for storageFolder in storageFolders {
        for childID in storageFolder.childFolderIDs {
          if let childFolder = tempFolders[childID] {
            tempFolders[storageFolder.id]?.childFolders.append(childFolder)
          }
        }
      }

      // Convert dictionary to array for publishing
      self.folders = Array(tempFolders.values)
    } catch {
      print("Error loading folders: \(error)")
    }
  }

  private func resolveFolderHierarchy() {

    var folderMap: [UUID: Int] = [:]
    for (index, folder) in folders.enumerated() {
      folderMap[folder.id] = index
    }

    for i in 0..<folders.count {
      folders[i].childFolders = []
    }

    for folder in folders {
      if let parentID = folder.parentID, let parentIndex = folderMap[parentID] {
        if let childIndex = folderMap[folder.id] {
          folders[parentIndex].childFolders.append(folders[childIndex])
        }
      }
    }
  }

  private func saveNoteLocally(_ note: Note) {
    if let existingIndex = notes.firstIndex(where: { $0.id == note.id }) {
      notes[existingIndex] = note
    } else {
      notes.append(note)
    }

    let storageNotes = notes.map { StorageNote(from: $0) }

    // Save to JSON file
    let notesURL = localStorageURL.appendingPathComponent(notesFileName)

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(storageNotes)
      try data.write(to: notesURL)
    } catch {
      print("Error saving note: \(error)")
    }
  }

  private func saveFolderLocally(_ folder: Folder) {
    // First update the folders array with the new/updated folder
    if let existingIndex = folders.firstIndex(where: { $0.id == folder.id }) {
      folders[existingIndex] = folder
    } else {
      folders.append(folder)
    }

    // Resolve folder hierarchy before saving
    resolveFolderHierarchy()

    // Convert to storage models
    let storageFolders = folders.map { StorageFolder(from: $0) }

    // Save to JSON file
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(storageFolders)
      try data.write(to: foldersURL)
    } catch {
      print("Error saving folder: \(error)")
    }
  }

  // MARK: - Supabase Methods
  private func syncWithSupabase() {
    // Fetch data from Supabase and merge with local data
    // Handle conflicts based on modification dates
    // This will be implemented later
  }

  private func saveNoteToSupabase(_ note: Note) {
    // Save note to Supabase tables
    // This will be implemented later
  }

  private func saveFolderToSupabase(_ folder: Folder) {
    // Save folder to Supabase tables
    // This will be implemented later
  }

  // MARK: - Public Methods

  func deleteNote(withID id: UUID) {
    // Remove from local array
    notes.removeAll(where: { $0.id == id })

    // Convert to storage models
    let storageNotes = notes.map { StorageNote(from: $0) }

    // Update the JSON file
    let notesURL = localStorageURL.appendingPathComponent(notesFileName)

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(storageNotes)
      try data.write(to: notesURL)
    } catch {
      print("Error deleting note: \(error)")
    }

    // If synced with Supabase, delete it there too (future implementation)
    // deleteNoteFromSupabase(id)
  }

  func deleteFolder(withID id: UUID) {
    // Remove from local array
    folders.removeAll(where: { $0.id == id })

    // Resolve folder hierarchy after deletion
    resolveFolderHierarchy()

    // Convert to storage models
    let storageFolders = folders.map { StorageFolder(from: $0) }

    // Update the JSON file
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(storageFolders)
      try data.write(to: foldersURL)
    } catch {
      print("Error deleting folder: \(error)")
    }

    // If synced with Supabase, delete it there too (future implementation)
    // deleteFolderFromSupabase(id)
  }
}
