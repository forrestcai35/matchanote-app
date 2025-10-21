import SwiftUI

// Tab model to represent an open note tab
struct NoteTab: Identifiable {
  var id = UUID()
  var note: Note
  var isActive: Bool = false
}

// Tab manager to handle shared tab state across the app using a singleton pattern
class TabManager: ObservableObject {
  static let shared = TabManager()

  // Private initializer for singleton
  private init() {}

  @Published var tabs: [NoteTab] = []
  
  // Callback to trigger when all tabs are closed
  var onAllTabsClosed: (() -> Void)?
  
  // Debounce timer for saving operations
  private var saveTimer: Timer?

  func openTab(note: Note) {
    // Check if tab with this note already exists
    if let existingIndex = tabs.firstIndex(where: { $0.note.id == note.id }) {
      // Update the note data in the existing tab to ensure it's current
      tabs[existingIndex].note = note
      // Set this tab as active
      setActiveTab(at: existingIndex)
    } else {
      // Make all existing tabs inactive
      for i in 0..<tabs.count {
        tabs[i].isActive = false
      }

      // Add new tab as active
      let newTab = NoteTab(note: note, isActive: true)
      tabs.append(newTab)
    }
  }
  
  // Helper method to set active tab
  private func setActiveTab(at index: Int) {
    for i in 0..<tabs.count {
      tabs[i].isActive = (i == index)
    }
  }

  func closeTab(id: UUID) {
    // Find the index of this tab
    if let index = tabs.firstIndex(where: { $0.id == id }) {
      let wasActive = tabs[index].isActive

      // Remove tab
      tabs.remove(at: index)

      // If the closed tab was active and there are remaining tabs, activate another one
      if wasActive && !tabs.isEmpty {
        if index > 0 {
          // Activate previous tab
          tabs[index - 1].isActive = true
        } else {
          // Activate first tab
          tabs[0].isActive = true
        }
      }
      
      // If no tabs remain, trigger the callback to dismiss
      if tabs.isEmpty {
        onAllTabsClosed?()
      }
    }
  }

  func getActiveTab() -> NoteTab? {
    return tabs.first(where: { $0.isActive })
  }
  
  func updateNote(_ updatedNote: Note) {
    // Update the note in any tabs that contain it
    DispatchQueue.main.async {
      for i in 0..<self.tabs.count {
        if self.tabs[i].note.id == updatedNote.id {
          self.tabs[i].note = updatedNote
        }
      }
    }
  }
  
  // Debounced update method to prevent rapid successive updates
  func updateNoteDebounced(_ updatedNote: Note, delay: TimeInterval = 0.5) {
    // Cancel previous timer
    saveTimer?.invalidate()
    
    // Create new timer
    saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      DispatchQueue.main.async {
        self?.updateNote(updatedNote)
      }
    }
  }
  
  // Clean up timer when deinitializing
  deinit {
    saveTimer?.invalidate()
  }
  
  func closeTabsForDeletedNote(noteId: UUID) {
    // Find and close all tabs with this note ID
    let tabsToClose = tabs.filter { $0.note.id == noteId }
    
    for tab in tabsToClose {
      closeTab(id: tab.id)
    }
  }
}
