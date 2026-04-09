import SwiftUI

// MARK: - Drag and Drop Extension for TabManager
extension TabManager {

  // MARK: - Drag State

  /// Tracks which tab is currently being dragged (nil when not dragging)
  private static var draggedTabIDStorage: UUID?

  var draggedTabID: UUID? {
    get { TabManager.draggedTabIDStorage }
    set { TabManager.draggedTabIDStorage = newValue }
  }

  // MARK: - Drag Functions

  /// Initiates dragging for a tab
  /// - Parameter tab: The tab to start dragging
  /// - Returns: NSItemProvider for the drag operation
  func startDraggingTab(_ tab: NoteTab) -> NSItemProvider {
    draggedTabID = tab.id
    return NSItemProvider(object: tab.id.uuidString as NSString)
  }

  /// Handles dropping a tab onto another tab to reorder
  /// - Parameters:
  ///   - sourceID: The ID of the tab being dragged
  ///   - targetID: The ID of the tab being dropped onto
  /// - Returns: Bool indicating success
  func handleTabDrop(sourceID: UUID, targetID: UUID) -> Bool {
    // Don't allow dropping on self
    guard sourceID != targetID else {
      resetDragState()
      return false
    }

    // Find source and target indices
    guard let sourceIndex = tabs.firstIndex(where: { $0.id == sourceID }),
          let targetIndex = tabs.firstIndex(where: { $0.id == targetID }) else {
      resetDragState()
      return false
    }

    // Reorder the tabs array
    reorderTab(from: sourceIndex, to: targetIndex)

    // Clear drag state
    resetDragState()

    return true
  }

  // MARK: - Helper Functions

  /// Reorders a tab from one index to another
  /// - Parameters:
  ///   - sourceIndex: The current index of the tab
  ///   - targetIndex: The desired index for the tab
  private func reorderTab(from sourceIndex: Int, to targetIndex: Int) {
    guard sourceIndex != targetIndex else { return }

    // Remove tab from source position
    let tab = tabs.remove(at: sourceIndex)

    // Insert at target position
    // If moving forward, adjust index since we removed an element
    let insertIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
    tabs.insert(tab, at: insertIndex)

    // Trigger UI update via @Published
    objectWillChange.send()
  }

  /// Resets the drag state
  func resetDragState() {
    draggedTabID = nil
  }
}
