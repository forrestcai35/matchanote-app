import SwiftUI
import matchanote_app

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

  func openTab(note: Note) {
    // Check if tab with this note already exists
    if let existingIndex = tabs.firstIndex(where: { $0.note.id == note.id }) {
      // Set this tab as active
      for i in 0..<tabs.count {
        tabs[i].isActive = (i == existingIndex)
      }
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
    }
  }

  func getActiveTab() -> NoteTab? {
    return tabs.first(where: { $0.isActive })
  }
}
