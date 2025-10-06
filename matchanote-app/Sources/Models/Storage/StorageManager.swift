import Foundation
import Supabase
import SwiftUI

// MARK: - Supabase Integration
// Note: We now use the user_storage table with notes and folders JSON columns

struct StorageNote: Codable {
  var id: UUID
  var title: String
  var subject: String
  var colorString: String
  var dateCreated: Date
  var dateModified: Date
  var lastOpenedAt: Date?
  var isFavorite: Bool
  var content: String
  var noteType: String
  var paperColor: String
  var paperStyle: String
  var paperSize: String
  var drawingDataByPage: [String: Data]
  var imageDataByPage: [String: [Data]]
  var bookmarkedPages: Set<Int>

  private enum CodingKeys: String, CodingKey {
    case id, title, subject, colorString, dateCreated, dateModified, lastOpenedAt
    case isFavorite, content, noteType, paperColor, paperStyle, paperSize
    case drawingDataByPage, imageDataByPage, bookmarkedPages
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    subject = try container.decode(String.self, forKey: .subject)
    colorString = try container.decode(String.self, forKey: .colorString)
    dateCreated = try container.decode(Date.self, forKey: .dateCreated)
    dateModified = try container.decode(Date.self, forKey: .dateModified)
    lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    content = try container.decode(String.self, forKey: .content)
    noteType = try container.decode(String.self, forKey: .noteType)
    paperColor = try container.decode(String.self, forKey: .paperColor)
    paperStyle = try container.decode(String.self, forKey: .paperStyle)
    paperSize = try container.decode(String.self, forKey: .paperSize)
    drawingDataByPage = try container.decode([String: Data].self, forKey: .drawingDataByPage)

    // Handle backwards compatibility - default to empty dict if imageDataByPage doesn't exist
    imageDataByPage =
      try container.decodeIfPresent([String: [Data]].self, forKey: .imageDataByPage) ?? [:]

    // Handle backwards compatibility - default to empty set if bookmarkedPages doesn't exist
    bookmarkedPages =
      try container.decodeIfPresent(Set<Int>.self, forKey: .bookmarkedPages) ?? Set<Int>()
  }

  init(from note: Note) {
    self.id = note.id
    self.title = note.title
    self.subject = note.subject
    self.colorString = colorToString(note.color)
    self.dateCreated = note.dateCreated
    self.dateModified = note.dateModified
    self.lastOpenedAt = note.lastOpenedAt
    self.isFavorite = note.isFavorite
    self.content = note.content
    self.noteType = note.noteType.rawValue
    self.paperColor = note.paperColor.rawValue
    self.paperStyle = note.paperStyle.rawValue
    self.paperSize = note.paperSize.rawValue
    self.drawingDataByPage = note.drawingDataByPage
    self.imageDataByPage = note.imageDataByPage
    self.bookmarkedPages = note.bookmarkedPages
  }

  func toNote() -> Note {
    var note = Note(
      title: title,
      subject: subject,
      color: stringToColor(colorString),
      dateCreated: dateCreated,
      dateModified: dateModified,
      lastOpenedAt: lastOpenedAt,
      isFavorite: isFavorite,
      content: content,
      noteType: NoteType(rawValue: noteType) ?? .written,
      paperColor: PaperColor(rawValue: paperColor) ?? .white,
      paperStyle: PaperStyle(rawValue: paperStyle) ?? .blank,
      paperSize: PaperSize(rawValue: paperSize) ?? .a4,
      drawingDataByPage: drawingDataByPage,
      imageDataByPage: imageDataByPage,
      bookmarkedPages: bookmarkedPages
    )
    note.id = id
    return note
  }
}

struct StorageFolder: Codable {
  var id: UUID
  var name: String
  var colorString: String
  var dateCreated: Date
  var dateModified: Date

  var parentID: UUID?
  var childFolderIDs: [UUID]
  var noteIDs: [UUID]

  init(from folder: Folder) {
    self.id = folder.id
    self.name = folder.name
    self.colorString = colorToString(folder.color)
    self.dateCreated = folder.dateCreated
    self.dateModified = folder.dateModified

    self.parentID = folder.parentID
    self.childFolderIDs = folder.childFolders.map { $0.id }
    self.noteIDs = folder.noteIDs
  }

  func toFolder() -> Folder {
    var folder = Folder(
      name: name,
      color: stringToColor(colorString),
      parentID: parentID,
      dateCreated: dateCreated

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

  func saveNote(_ note: Note) -> Note {
    // Ensure unique title before saving
    var noteToSave = note
    noteToSave.title = generateUniqueTitle(for: noteToSave.title, excludingNoteId: noteToSave.id)

    // Save to local storage first (for offline support)
    saveNoteLocally(noteToSave)

    // Save to Supabase if user is authenticated and Supabase storage is enabled
    if PreferencesManager.shared.supabaseStorageEnabled {
      Task {
        await saveNoteToSupabase(noteToSave)
      }
    }

    return noteToSave
  }

  // Update a note's title while ensuring uniqueness
  func updateNoteTitle(noteId: UUID, newTitle: String) -> Note? {
    guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else {
      return nil
    }

    var noteToUpdate = notes[noteIndex]
    let uniqueTitle = generateUniqueTitle(for: newTitle, excludingNoteId: noteId)
    noteToUpdate.title = uniqueTitle
    noteToUpdate.dateModified = Date()

    // Save the updated note
    let savedNote = saveNote(noteToUpdate)
    return savedNote
  }

  // Generate a unique title by appending numbers if duplicates exist
  func generateUniqueTitle(for proposedTitle: String, excludingNoteId: UUID? = nil) -> String {
    let baseTitle = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)

    // Get all existing note titles, excluding the current note if updating
    let existingTitles =
      notes
      .filter { $0.id != excludingNoteId }
      .map { $0.title }

    // If the title is unique, return it as is
    if !existingTitles.contains(baseTitle) {
      return baseTitle
    }

    // Find the highest number suffix for this base title
    var highestNumber = 1
    let titlePattern =
      "^" + NSRegularExpression.escapedPattern(for: baseTitle) + "( \\((\\d+)\\))?$"

    for existingTitle in existingTitles {
      if let regex = try? NSRegularExpression(pattern: titlePattern, options: []),
        let match = regex.firstMatch(
          in: existingTitle, options: [], range: NSRange(location: 0, length: existingTitle.count))
      {

        // If there's a number in parentheses, extract it
        if match.numberOfRanges > 2,
          let numberRange = Range(match.range(at: 2), in: existingTitle),
          let number = Int(existingTitle[numberRange])
        {
          highestNumber = max(highestNumber, number + 1)
        } else if existingTitle == baseTitle {
          // Exact match without number, so next should be (2)
          highestNumber = max(highestNumber, 2)
        }
      }
    }

    return "\(baseTitle) (\(highestNumber))"
  }

  func saveFolder(_ folder: Folder) -> Folder {
    // Ensure unique name before saving
    var folderToSave = folder
    folderToSave.name = generateUniqueFolderName(for: folderToSave.name, parentID: folderToSave.parentID, excludingFolderId: folderToSave.id)
    
    // Save to local storage first (for offline support)
    saveFolderLocally(folderToSave)

    // Save to Supabase if user is authenticated and Supabase storage is enabled
    if PreferencesManager.shared.supabaseStorageEnabled {
      Task {
        await saveFolderToSupabase(folderToSave)
      }
    }
    
    return folderToSave
  }

  // Update a folder's name while ensuring uniqueness
  func updateFolderName(folderId: UUID, newName: String) -> Folder? {
    guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else {
      return nil
    }

    var folderToUpdate = folders[folderIndex]
    let uniqueName = generateUniqueFolderName(for: newName, parentID: folderToUpdate.parentID, excludingFolderId: folderId)
    folderToUpdate.name = uniqueName
    folderToUpdate.dateModified = Date()

    // Save the updated folder
    let savedFolder = saveFolder(folderToUpdate)
    return savedFolder
  }

  // Generate a unique folder name by appending numbers if duplicates exist within the same parent
  func generateUniqueFolderName(for proposedName: String, parentID: UUID? = nil, excludingFolderId: UUID? = nil) -> String {
    let baseName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)

    // Get all existing folder names within the same parent, excluding the current folder if updating
    let existingNames =
      folders
      .filter { $0.parentID == parentID && $0.id != excludingFolderId }
      .map { $0.name }

    // If the name is unique, return it as is
    if !existingNames.contains(baseName) {
      return baseName
    }

    // Find the highest number suffix for this base name
    var highestNumber = 1
    let namePattern =
      "^" + NSRegularExpression.escapedPattern(for: baseName) + "( \\((\\d+)\\))?$"

    for existingName in existingNames {
      if let regex = try? NSRegularExpression(pattern: namePattern, options: []),
        let match = regex.firstMatch(
          in: existingName, options: [], range: NSRange(location: 0, length: existingName.count))
      {

        // If there's a number in parentheses, extract it
        if match.numberOfRanges > 2,
          let numberRange = Range(match.range(at: 2), in: existingName),
          let number = Int(existingName[numberRange])
        {
          highestNumber = max(highestNumber, number + 1)
        } else if existingName == baseName {
          // Exact match without number, so next should be (2)
          highestNumber = max(highestNumber, 2)
        }
      }
    }

    return "\(baseName) (\(highestNumber))"
  }

  private func loadData() {
    // Load from local storage first
    loadLocalData()

    // Try to sync with Supabase if user is authenticated
    Task {
      await syncWithSupabase()
    }
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
    // PERFORMANCE FIX: Update UI state immediately, defer heavy JSON ops
    if let existingIndex = notes.firstIndex(where: { $0.id == note.id }) {
      notes[existingIndex] = note
    } else {
      notes.append(note)
    }

    // Move JSON encoding to background thread
    let notesToSave = notes.map { StorageNote(from: $0) }
    let notesURL = localStorageURL.appendingPathComponent(notesFileName)
    
    Task.detached(priority: .utility) {
      do {
        let encoder = JSONEncoder()
        // Remove pretty printing for better performance
        let data = try encoder.encode(notesToSave)
        try data.write(to: notesURL)
      } catch {
        await MainActor.run {
          print("Error saving note: \(error)")
        }
      }
    }
  }

  private func saveFolderLocally(_ folder: Folder) {
    // PERFORMANCE FIX: Update UI state immediately, defer heavy JSON ops
    // First update the folders array with the new/updated folder
    if let existingIndex = folders.firstIndex(where: { $0.id == folder.id }) {
      folders[existingIndex] = folder
    } else {
      folders.append(folder)
    }

    // Resolve folder hierarchy before saving
    resolveFolderHierarchy()

    // Move JSON encoding to background thread
    let foldersToSave = folders.map { StorageFolder(from: $0) }
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)
    
    Task.detached(priority: .utility) {
      do {
        let encoder = JSONEncoder()
        // Remove pretty printing for better performance
        let data = try encoder.encode(foldersToSave)
        try data.write(to: foldersURL)
      } catch {
        await MainActor.run {
          print("Error saving folder: \(error)")
        }
      }
    }
  }

  // MARK: - Supabase Methods
  private func syncWithSupabase() async {
    // Check if Supabase storage is enabled in preferences
    guard PreferencesManager.shared.supabaseStorageEnabled else {
      print("Supabase storage is disabled in preferences")
      return
    }
    
    do {
      // Check if user is authenticated
      let session = try await supabase.auth.session
      let userId = session.user.id

      // Fetch user storage data
      await fetchUserStorageFromSupabase(userId: userId)

    } catch {
      // Continue with local storage only
    }
  }

  private func fetchUserStorageFromSupabase(userId: UUID) async {
    do {
      // Only fetch notes and folders data, not subscription data
      // Subscription data should be handled by SubscriptionManager
      let response: UserProfile
      do {
        // Try single() first with string UUID
        response = try await supabase
          .from("user_storage")
          .select("notes, folders, updated_at")
          .eq("user_id", value: userId.uuidString)
          .single()
          .execute()
          .value
      } catch {
        // If single() fails, try decoding as array and take first element
        let responses: [UserProfile] = try await supabase
          .from("user_storage")
          .select("notes, folders, updated_at")
          .eq("user_id", value: userId.uuidString)
          .execute()
          .value
        
        guard let firstResponse = responses.first else {
          throw NSError(domain: "StorageManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user storage data found"])
        }
        response = firstResponse
      }

      await MainActor.run {
        // Process the fetched data and merge with local storage
        processSupabaseProfileData(response)
      }

    } catch {
      print("Error fetching from user_storage table: \(error)")
    }
  }

  private func processSupabaseProfileData(_ profile: UserProfile) {
    // Process notes from user profile
    if let notesData = profile.notes {
      do {
        // JSONB data is now already in Data format
        let storageNotes = try JSONDecoder().decode([StorageNote].self, from: notesData)

        // Merge notes with local data based on modification dates
        for storageNote in storageNotes {
          let note = storageNote.toNote()

          if let localNoteIndex = notes.firstIndex(where: { $0.id == note.id }) {
            if note.dateModified > notes[localNoteIndex].dateModified {
              notes[localNoteIndex] = note
            }
          } else {
            notes.append(note)
          }
        }
      } catch {
        print("Error processing notes from user profile: \(error)")
      }
    }

    // Process folders from user profile
    if let foldersData = profile.folders {
      do {
        // JSONB data is now already in Data format
        let storageFolders = try JSONDecoder().decode([StorageFolder].self, from: foldersData)

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

        // Merge folders with local data based on modification dates
        for (_, folder) in tempFolders {
          if let localFolderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
            if folder.dateModified > folders[localFolderIndex].dateModified {
              folders[localFolderIndex] = folder
            }
          } else {
            folders.append(folder)
          }
        }
      } catch {
        print("Error processing folders from user profile: \(error)")
      }
    }

    // Resolve folder hierarchy after merging
    resolveFolderHierarchy()
  }

  private func saveNoteToSupabase(_ note: Note) async {
    do {
      let session = try await supabase.auth.session
      let userId = session.user.id

      // Convert all notes to storage format
      let storageNotes = notes.map { StorageNote(from: $0) }
      let encoder = JSONEncoder()
      let notesData = try encoder.encode(storageNotes)

      // Convert to JSON string for Supabase
      let notesJsonString = String(data: notesData, encoding: .utf8) ?? "[]"

      // Update the user storage with the new notes data
      try await supabase
        .from("user_storage")
        .update(["notes": notesJsonString])
        .eq("user_id", value: userId)
        .execute()

    } catch {
      print("Error saving note to Supabase: \(error)")
    }
  }

  private func saveFolderToSupabase(_ folder: Folder) async {
    do {
      let session = try await supabase.auth.session
      let userId = session.user.id

      // Convert all folders to storage format
      let storageFolders = folders.map { StorageFolder(from: $0) }
      let encoder = JSONEncoder()
      let foldersData = try encoder.encode(storageFolders)

      // Convert to JSON string for Supabase
      let foldersJsonString = String(data: foldersData, encoding: .utf8) ?? "[]"

      // Update the user storage with the new folders data
      try await supabase
        .from("user_storage")
        .update(["folders": foldersJsonString])
        .eq("user_id", value: userId)
        .execute()

    } catch {
      print("Error saving folder to Supabase: \(error)")
    }
  }

  // MARK: - Public Methods

  /// Get all note IDs in a folder and its subfolders recursively
  func getAllNotesInFolder(folderID: UUID) -> [UUID] {
    var allNoteIDs: [UUID] = []
    
    // Find the folder
    guard let folder = folders.first(where: { $0.id == folderID }) else {
      return allNoteIDs
    }
    
    // Add notes directly in this folder
    allNoteIDs.append(contentsOf: folder.noteIDs)
    
    // Recursively add notes from subfolders
    for childFolder in folder.childFolders {
      allNoteIDs.append(contentsOf: getAllNotesInFolder(folderID: childFolder.id))
    }
    
    return allNoteIDs
  }

  func deleteNote(withID id: UUID) {
    guard let note = notes.first(where: { $0.id == id }) else {
      print("Note not found for deletion")
      return
    }

    // Move to trash instead of permanent deletion
    TrashManager.shared.moveNoteToTrash(note)

    // Remove from local array
    notes.removeAll(where: { $0.id == id })

    // Remove from all folders
    for i in 0..<folders.count {
      folders[i].noteIDs.removeAll { $0 == id }
      if folders[i].noteIDs != folders[i].noteIDs {
        folders[i].dateModified = Date()
      }
    }

    // Close any open tabs for this note
    TabManager.shared.closeTabsForDeletedNote(noteId: id)

    // Update storage files
    updateStorageFiles()
  }
  
  // MARK: - Optimized Bulk Operations
  
  /// Delete multiple notes efficiently in a single batch operation
  func deleteNotesBulk(noteIDs: [UUID]) {
    guard !noteIDs.isEmpty else { return }
    
    // Find all notes to delete
    let notesToDelete = notes.filter { noteIDs.contains($0.id) }
    
    // Move all notes to trash in batch using optimized method
    TrashManager.shared.moveNotesToTrashBulk(notesToDelete)
    
    // Remove from local arrays in batch
    notes.removeAll { noteIDs.contains($0.id) }
    
    // Update folders in batch
    for i in 0..<folders.count {
      let originalCount = folders[i].noteIDs.count
      folders[i].noteIDs.removeAll { noteIDs.contains($0) }
      if folders[i].noteIDs.count != originalCount {
        folders[i].dateModified = Date()
      }
    }
    
    // Close tabs for all deleted notes
    for noteID in noteIDs {
      TabManager.shared.closeTabsForDeletedNote(noteId: noteID)
    }
    
    // Single storage update for all deletions
    updateStorageFilesBulk()
  }
  
  /// Delete multiple folders efficiently in a single batch operation
  func deleteFoldersBulk(folderIDs: [UUID]) {
    guard !folderIDs.isEmpty else { return }
    
    // Find all folders to delete
    let foldersToDelete = folders.filter { folderIDs.contains($0.id) }
    
    // Get all notes in these folders and their subfolders
    var allNotesToDelete: [UUID] = []
    for folder in foldersToDelete {
      allNotesToDelete.append(contentsOf: getAllNotesInFolder(folderID: folder.id))
    }
    
    // Delete all notes in batch first
    if !allNotesToDelete.isEmpty {
      deleteNotesBulk(noteIDs: allNotesToDelete)
    }
    
    // Move folders to trash in batch using optimized method
    TrashManager.shared.moveFoldersToTrashBulk(foldersToDelete)
    
    // Remove from local array
    folders.removeAll { folderIDs.contains($0.id) }
    
    // Remove references from parent folders
    for i in 0..<folders.count {
      folders[i].childFolders.removeAll { folderIDs.contains($0.id) }
    }
    
    // Resolve folder hierarchy once
    resolveFolderHierarchy()
    
    // Single storage update
    updateStorageFilesBulk()
  }

  func deleteFolder(withID id: UUID) {
    guard let folder = folders.first(where: { $0.id == id }) else {
      print("Folder not found for deletion")
      return
    }

    // Get all notes in this folder and its subfolders before deletion
    let notesToDelete = getAllNotesInFolder(folderID: id)
    
    // Delete all notes in this folder and its subfolders
    for noteID in notesToDelete {
      deleteNote(withID: noteID)
    }

    // Move to trash instead of permanent deletion
    TrashManager.shared.moveFolderToTrash(folder)

    // Remove from local array
    folders.removeAll(where: { $0.id == id })

    // Remove references to this folder from parent folders
    for i in 0..<folders.count {
      folders[i].childFolders.removeAll { $0.id == id }
    }

    // Resolve folder hierarchy after deletion
    resolveFolderHierarchy()

    // Update storage files
    updateStorageFiles()
  }

  func restoreNoteFromTrash(_ note: Note) {
    // Add back to notes array
    if !notes.contains(where: { $0.id == note.id }) {
      notes.append(note)
      updateStorageFiles()
    }
  }

  func restoreFolderFromTrash(_ folder: Folder) {
    // Add back to folders array
    if !folders.contains(where: { $0.id == folder.id }) {
      folders.append(folder)
      resolveFolderHierarchy()
      updateStorageFiles()
    }
  }

  private func updateStorageFiles() {
    // Update both notes and folders files
    let notesStorageModels = notes.map { StorageNote(from: $0) }
    let foldersStorageModels = folders.map { StorageFolder(from: $0) }

    let notesURL = localStorageURL.appendingPathComponent(notesFileName)
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)

    Task.detached(priority: .utility) {
      do {
        let encoder = JSONEncoder()

        // Update notes file
        let notesData = try encoder.encode(notesStorageModels)
        try notesData.write(to: notesURL)

        // Update folders file
        let foldersData = try encoder.encode(foldersStorageModels)
        try foldersData.write(to: foldersURL)
      } catch {
        await MainActor.run {
          print("Error updating storage files: \(error)")
        }
      }
    }

    // Also sync with Supabase if authenticated and Supabase storage is enabled
    if PreferencesManager.shared.supabaseStorageEnabled {
      Task {
        await syncDeletedItemWithSupabase()
      }
    }
  }
  
  /// Optimized bulk storage update that processes all changes in a single operation
  private func updateStorageFilesBulk() {
    // Process all changes in background to avoid blocking UI
    Task.detached(priority: .utility) { [weak self] in
      guard let self = self else { return }
      
      do {
        // Create storage models
        let notesStorageModels = self.notes.map { StorageNote(from: $0) }
        let foldersStorageModels = self.folders.map { StorageFolder(from: $0) }
        
        let notesURL = self.localStorageURL.appendingPathComponent(self.notesFileName)
        let foldersURL = self.localStorageURL.appendingPathComponent(self.foldersFileName)
        
        let encoder = JSONEncoder()
        
        // Encode and write both files
        let notesData = try encoder.encode(notesStorageModels)
        let foldersData = try encoder.encode(foldersStorageModels)
        
        try notesData.write(to: notesURL)
        try foldersData.write(to: foldersURL)
        
        // Single Supabase sync for all changes
        if PreferencesManager.shared.supabaseStorageEnabled {
          await self.syncDeletedItemWithSupabase()
        }
        
      } catch {
        await MainActor.run {
          print("Error updating storage files in bulk: \(error)")
        }
      }
    }
  }

  // Save all folders without individual processing - useful for bulk updates
  func saveFoldersState() {
    // Resolve hierarchy before saving
    resolveFolderHierarchy()

    // Save to local storage
    let foldersToSave = folders.map { StorageFolder(from: $0) }
    let foldersURL = localStorageURL.appendingPathComponent(foldersFileName)

    Task.detached(priority: .utility) {
      do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(foldersToSave)
        try data.write(to: foldersURL)
      } catch {
        await MainActor.run {
          print("Error saving folders state: \(error)")
        }
      }
    }

    // Sync with Supabase if authenticated and Supabase storage is enabled
    if PreferencesManager.shared.supabaseStorageEnabled {
      Task {
        await syncDeletedItemWithSupabase()
      }
    }
  }

  private func syncDeletedItemWithSupabase() async {
    // Update Supabase with current notes and folders
    do {
      let session = try await supabase.auth.session
      let userId = session.user.id

      // Convert all notes and folders to storage format
      let storageNotes = notes.map { StorageNote(from: $0) }
      let storageFolders = folders.map { StorageFolder(from: $0) }

      let encoder = JSONEncoder()
      let notesData = try encoder.encode(storageNotes)
      let foldersData = try encoder.encode(storageFolders)

      // Convert to JSON string for Supabase
      let notesJsonString = String(data: notesData, encoding: .utf8) ?? "[]"
      let foldersJsonString = String(data: foldersData, encoding: .utf8) ?? "[]"

      // Update the user storage with the new data
      try await supabase
        .from("user_storage")
        .update([
          "notes": notesJsonString,
          "folders": foldersJsonString
        ])
        .eq("user_id", value: userId)
        .execute()

    } catch {
      print("Error syncing with Supabase after deletion: \(error)")
    }
  }
}
