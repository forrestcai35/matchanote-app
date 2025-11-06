import SwiftUI

// Tab model to represent an open note tab
struct NoteTab: Identifiable {
  var id = UUID()
  var note: Note
  var isActive: Bool = false
  var currentPage: Int = 0
  var scrollPosition: Int? = nil  // Per-tab scroll position for vertical scroll mode
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

  // Helper method to get valid page count for a note
  private func getPageCount(for note: Note) -> Int {
    return max(1, note.drawingDataByPage.keys.compactMap { Int($0) }.max().map { $0 + 1 } ?? 1)
  }

  // Helper method to validate and get valid page index for a note
  private func getValidPageIndex(for note: Note, requestedPage: Int) -> Int {
    let pageCount = getPageCount(for: note)
    return min(max(0, requestedPage), pageCount - 1)
  }

  // Update the current page for a specific tab
  func updateCurrentPage(tabId: UUID, page: Int) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      let validPage = getValidPageIndex(for: tabs[index].note, requestedPage: page)
      tabs[index].currentPage = validPage
    }
  }

  // Update the scroll position for a specific tab (vertical scroll mode)
  func updateScrollPosition(tabId: UUID, position: Int?) {
    if let index = tabs.firstIndex(where: { $0.id == tabId }) {
      tabs[index].scrollPosition = position
    }
  }

  func openTab(note: Note) {
    // Check if tab with this note already exists
    if let existingIndex = tabs.firstIndex(where: { $0.note.id == note.id }) {
      // Update the note data in the existing tab to ensure it's current
      tabs[existingIndex].note = note
      // Don't change currentPage - each tab maintains its own independent page position
      // Initialize scrollPosition if it's nil (for vertical scroll mode)
      if tabs[existingIndex].scrollPosition == nil {
        tabs[existingIndex].scrollPosition = tabs[existingIndex].currentPage
      }
      // Set this tab as active
      setActiveTab(at: existingIndex)
    } else {
      // Make all existing tabs inactive
      for i in 0..<tabs.count {
        tabs[i].isActive = false
      }

      // Add new tab as active with validated current page from note
      let validPage = getValidPageIndex(for: note, requestedPage: note.currentPage)
      let newTab = NoteTab(note: note, isActive: true, currentPage: validPage, scrollPosition: validPage)
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
          // Revalidate current page in case page count changed
          let validPage = self.getValidPageIndex(for: updatedNote, requestedPage: self.tabs[i].currentPage)
          self.tabs[i].currentPage = validPage
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
