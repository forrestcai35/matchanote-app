import Foundation
import SwiftUI
import Combine

/// Manages mention detection, suggestions, and context extraction
class MentionManager: ObservableObject {
    @Published var suggestions: [MentionSuggestion] = []
    @Published var isShowingSuggestions = false
    @Published var currentMentionQuery = ""

    private var storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    // MARK: - Mention Detection

    /// Detects if the text contains an active mention query (typing after @)
    /// Returns the query string if found, nil otherwise
    func detectMentionQuery(in text: String, cursorPosition: String.Index? = nil) -> String? {
        let position = cursorPosition ?? text.endIndex

        guard position > text.startIndex else {
            return nil
        }

        // Find the start of the current word (search backwards for whitespace/newline or start of text)
        var wordStart = text.startIndex
        var searchIndex = text.index(before: position)

        while searchIndex > text.startIndex {
            let char = text[searchIndex]
            if char.isWhitespace || char.isNewline {
                wordStart = text.index(after: searchIndex)
                break
            }
            searchIndex = text.index(before: searchIndex)
        }

        // Check if current word starts with @
        guard wordStart < position && text[wordStart] == "@" else {
            return nil
        }

        // Get the text after @ within the current word
        let queryStartIndex = text.index(after: wordStart)
        guard queryStartIndex <= position else {
            return nil
        }

        let query = String(text[queryStartIndex..<position])

        // Return the query (can be empty string for just "@")
        return query
    }

    /// Updates suggestions based on the current query
    func updateSuggestions(query: String) {
        // Force synchronous update on main thread
        objectWillChange.send()

        currentMentionQuery = query

        if query.isEmpty {
            // Show all items when query is empty
            suggestions = getAllSuggestions()
        } else {
            // Filter based on query
            suggestions = searchMentions(query: query)
        }

        isShowingSuggestions = !suggestions.isEmpty
    }

    // MARK: - Search

    /// Search for notes, folders, and subjects matching the query
    private func searchMentions(query: String) -> [MentionSuggestion] {
        let lowercaseQuery = query.lowercased()
        var results: [MentionSuggestion] = []

        // Search notes
        let matchingNotes = storageManager.notes.filter { note in
            note.title.lowercased().contains(lowercaseQuery) ||
            note.subject.lowercased().contains(lowercaseQuery)
        }

        for note in matchingNotes.prefix(10) {
            let mention = Mention(id: note.id.uuidString, type: .note, displayName: note.title)
            let subtitle = note.subject.isEmpty ? "Note" : note.subject
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        // Search folders
        let matchingFolders = storageManager.folders.filter { folder in
            folder.name.lowercased().contains(lowercaseQuery) ||
            folder.subject.lowercased().contains(lowercaseQuery)
        }

        for folder in matchingFolders.prefix(8) {
            let mention = Mention(id: folder.id.uuidString, type: .folder, displayName: folder.name)
            let subtitle = getFolderPath(folder: folder)
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        // Search subjects
        let allSubjects = getAllSubjects()
        let matchingSubjects = allSubjects.filter { $0.lowercased().contains(lowercaseQuery) }

        for subject in matchingSubjects.prefix(5) {
            let mention = Mention(id: subject, type: .subject, displayName: subject)
            let subtitle = "Subject"
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        return results
    }

    /// Get all available suggestions (used when query is empty)
    private func getAllSuggestions() -> [MentionSuggestion] {
        var results: [MentionSuggestion] = []

        // Add recent notes (limited to 8)
        let recentNotes = storageManager.notes
            .sorted { ($0.lastOpenedAt ?? $0.dateModified) > ($1.lastOpenedAt ?? $1.dateModified) }
            .prefix(8)

        for note in recentNotes {
            let mention = Mention(id: note.id.uuidString, type: .note, displayName: note.title)
            let subtitle = note.subject.isEmpty ? "Note" : note.subject
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        // Add subjects
        let subjects = getAllSubjects().prefix(5)
        for subject in subjects {
            let mention = Mention(id: subject, type: .subject, displayName: subject)
            let subtitle = "Subject"
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        // Add root folders
        let rootFolders = storageManager.folders.filter { $0.parentID == nil }.prefix(5)
        for folder in rootFolders {
            let mention = Mention(id: folder.id.uuidString, type: .folder, displayName: folder.name)
            let subtitle = "Folder"
            results.append(MentionSuggestion(mention: mention, subtitle: subtitle))
        }

        return results
    }

    // MARK: - Helper Methods

    /// Get all unique subjects from notes and folders
    private func getAllSubjects() -> [String] {
        var subjects = Set<String>()

        // Get subjects from notes
        for note in storageManager.notes {
            if !note.subject.isEmpty {
                subjects.insert(note.subject)
            }
        }

        // Get subjects from folders
        for folder in storageManager.folders {
            if !folder.subject.isEmpty {
                subjects.insert(folder.subject)
            }
        }

        return Array(subjects).sorted()
    }

    /// Get the folder path for display (e.g., "Parent / Child")
    private func getFolderPath(folder: Folder) -> String {
        var path: [String] = [folder.name]
        var currentFolder = folder

        // Traverse up to find parent folders
        while let parentID = currentFolder.parentID,
              let parent = storageManager.folders.first(where: { $0.id == parentID }) {
            path.insert(parent.name, at: 0)
            currentFolder = parent
        }

        return path.count > 1 ? path.joined(separator: " / ") : "Folder"
    }

    // MARK: - Mention Insertion

    /// Inserts a mention into the text at the cursor position
    func insertMention(_ mention: Mention, into text: String, at cursorPosition: String.Index? = nil) -> String {
        let position = cursorPosition ?? text.endIndex

        // Find the last @ before cursor
        guard let lastAtIndex = text[..<position].lastIndex(of: "@") else {
            return text
        }

        // Replace from @ to cursor with the mention text
        var newText = text
        newText.replaceSubrange(lastAtIndex..<position, with: mention.mentionText + " ")

        return newText
    }

    // MARK: - Mention Extraction

    /// Extract all mentions from the text
    func extractMentions(from text: String) -> [Mention] {
        var mentions: [Mention] = []
        var searchStartIndex = text.startIndex

        while searchStartIndex < text.endIndex {
            // Find next @
            guard let atIndex = text[searchStartIndex...].firstIndex(of: "@") else {
                break
            }

            // Get the start of the mention name
            let nameStartIndex = text.index(after: atIndex)
            guard nameStartIndex < text.endIndex else {
                break
            }

            // Get remaining text from @ onwards
            let remainingText = String(text[nameStartIndex...])

            // Try to find the longest matching mention name
            if let mention = findLongestMention(in: remainingText) {
                mentions.append(mention)
                // Move past this mention
                if let mentionEndIndex = text.range(of: mention.displayName, range: nameStartIndex..<text.endIndex)?.upperBound {
                    searchStartIndex = mentionEndIndex
                } else {
                    searchStartIndex = text.index(after: atIndex)
                }
            } else {
                // No match found, move to next character
                searchStartIndex = text.index(after: atIndex)
            }
        }

        return mentions
    }

    /// Find the longest matching mention from the start of the text
    private func findLongestMention(in text: String) -> Mention? {
        // Collect all possible names to match against
        var candidateNames: [(name: String, mention: Mention)] = []

        // Add all note names
        for note in storageManager.notes {
            let mention = Mention(id: note.id.uuidString, type: .note, displayName: note.title)
            candidateNames.append((name: note.title, mention: mention))
        }

        // Add all folder names
        for folder in storageManager.folders {
            let mention = Mention(id: folder.id.uuidString, type: .folder, displayName: folder.name)
            candidateNames.append((name: folder.name, mention: mention))
        }

        // Add all subjects
        for subject in getAllSubjects() {
            let mention = Mention(id: subject, type: .subject, displayName: subject)
            candidateNames.append((name: subject, mention: mention))
        }

        // Find longest match at the start of the text
        var longestMatch: (name: String, mention: Mention)? = nil

        for candidate in candidateNames {
            if text.hasPrefix(candidate.name) {
                if longestMatch == nil || candidate.name.count > longestMatch!.name.count {
                    longestMatch = candidate
                }
            }
        }

        return longestMatch?.mention
    }

    /// Find a mention by its display name
    private func findMention(byName name: String) -> Mention? {
        // Search in notes
        if let note = storageManager.notes.first(where: { $0.title == name }) {
            return Mention(id: note.id.uuidString, type: .note, displayName: note.title)
        }

        // Search in folders
        if let folder = storageManager.folders.first(where: { $0.name == name }) {
            return Mention(id: folder.id.uuidString, type: .folder, displayName: folder.name)
        }

        // Check if it's a subject
        let subjects = getAllSubjects()
        if subjects.contains(name) {
            return Mention(id: name, type: .subject, displayName: name)
        }

        return nil
    }

    // MARK: - Context Extraction

    /// Get context data for a list of mentions to include in AI prompt
    func getContextForMentions(_ mentions: [Mention]) -> String {
        var context = ""

        for mention in mentions {
            switch mention.type {
            case .note:
                if let noteContext = getNoteContext(id: mention.id) {
                    context += "\n\n--- Note: \(mention.displayName) ---\n\(noteContext)"
                }
            case .folder:
                if let folderContext = getFolderContext(id: mention.id) {
                    context += "\n\n--- Folder: \(mention.displayName) ---\n\(folderContext)"
                }
            case .subject:
                if let subjectContext = getSubjectContext(name: mention.displayName) {
                    context += "\n\n--- Subject: \(mention.displayName) ---\n\(subjectContext)"
                }
            }
        }

        return context
    }

    private func getNoteContext(id: String) -> String? {
        guard let uuid = UUID(uuidString: id),
              let note = storageManager.notes.first(where: { $0.id == uuid }) else {
            return nil
        }

        var context = "Title: \(note.title)\n"
        context += "Subject: \(note.subject)\n"
        if !note.content.isEmpty {
            context += "Content: \(note.content)\n"
        }

        // Add text from textboxes
        var textBoxContent: [String] = []
        for (_, textBoxes) in note.textBoxDataByPage {
            for textBoxData in textBoxes {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
                    textBoxContent.append(textBox.text)
                }
            }
        }
        if !textBoxContent.isEmpty {
            context += "Additional text: \(textBoxContent.joined(separator: " | "))\n"
        }

        return context
    }

    private func getFolderContext(id: String) -> String? {
        guard let uuid = UUID(uuidString: id),
              let folder = storageManager.folders.first(where: { $0.id == uuid }) else {
            return nil
        }

        var context = "Folder Name: \(folder.name)\n"
        if !folder.subject.isEmpty {
            context += "Subject: \(folder.subject)\n"
        }

        // List notes in folder
        let noteCount = folder.noteIDs.count
        context += "Number of notes: \(noteCount)\n"

        if noteCount > 0 {
            let noteNames = folder.noteIDs.compactMap { noteID in
                storageManager.notes.first(where: { $0.id == noteID })?.title
            }
            context += "Notes: \(noteNames.joined(separator: ", "))\n"
        }

        // List subfolders
        if !folder.childFolders.isEmpty {
            let subfolderNames = folder.childFolders.map { $0.name }
            context += "Subfolders: \(subfolderNames.joined(separator: ", "))\n"
        }

        return context
    }

    private func getSubjectContext(name: String) -> String? {
        // Find all notes with this subject
        let notesInSubject = storageManager.notes.filter { $0.subject == name }

        var context = "Subject: \(name)\n"
        context += "Number of notes: \(notesInSubject.count)\n"

        if !notesInSubject.isEmpty {
            let noteTitles = notesInSubject.map { $0.title }
            context += "Notes: \(noteTitles.joined(separator: ", "))\n"
        }

        return context
    }

    // MARK: - Clear State

    func clearSuggestions() {
        objectWillChange.send()
        suggestions = []
        isShowingSuggestions = false
        currentMentionQuery = ""
    }
}
