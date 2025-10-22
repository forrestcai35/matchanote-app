import SwiftUI

// Extension to handle drag and drop operations for HomeView
extension HomeView {
    // Start dragging a folder
    func startDragging(folder: Folder) -> NSItemProvider {
        dragItem = (.folder, folder.id)
        return NSItemProvider(object: folder.id.uuidString as NSString)
    }

    // Start dragging a note
    func startDragging(note: Note) -> NSItemProvider {
        dragItem = (.note, note.id)
        return NSItemProvider(object: note.id.uuidString as NSString)
    }

    // Handle drop to root level
    func handleDropToRoot() -> Bool {
        guard let draggedItemType = self.dragItem else {
            return false
        }

        switch draggedItemType.type {
        case .folder:
            // Move folder to root level
            if let sourceFolder = storageManager.folders.first(where: {
                $0.id == draggedItemType.id
            }) {
                var updatedFolder = sourceFolder
                updatedFolder.parentID = nil
                _ = storageManager.saveFolder(updatedFolder)
                return true
            }
        case .note:
            // Remove note from all folders
            let foldersContainingNote = storageManager.folders.filter {
                $0.noteIDs.contains(draggedItemType.id)
            }
            for folder in foldersContainingNote {
                var updatedFolder = folder
                updatedFolder.noteIDs.removeAll(where: { $0 == draggedItemType.id })
                updatedFolder.dateModified = Date()
                _ = storageManager.saveFolder(updatedFolder)
                print("Removed note \(draggedItemType.id) from folder \(updatedFolder.id)")
            }
            return true
        }

        return false
    }

    // Handle drop onto a specific folder
    func handleDrop(onto targetFolder: Folder? = nil) -> Bool {
        guard let (type, id) = dragItem else { return false }

        switch type {
        case .folder:
            if let targetFolder = targetFolder {
                // Don't allow dropping on self or circular references
                if id == targetFolder.id
                    || wouldCreateCircularReference(sourceID: id, targetID: targetFolder.id)
                {
                    return false
                }

                // Move folder to target folder
                if let sourceFolderIndex = storageManager.folders.firstIndex(where: { $0.id == id }) {
                    storageManager.folders[sourceFolderIndex].parentID = targetFolder.id

                    // Update target folder's modified date
                    if let targetFolderIndex = storageManager.folders.firstIndex(where: { $0.id == targetFolder.id }) {
                        storageManager.folders[targetFolderIndex].dateModified = Date()
                    }

                    // Save all folder changes at once
                    storageManager.saveFoldersState()
                }
            } else {
                // Move to root
                if let sourceFolderIndex = storageManager.folders.firstIndex(where: { $0.id == id }) {
                    storageManager.folders[sourceFolderIndex].parentID = nil
                    storageManager.saveFoldersState()
                }
            }

        case .note:
            // Remove note from all folders that contain it
            for i in 0..<storageManager.folders.count {
                if storageManager.folders[i].noteIDs.contains(id) {
                    storageManager.folders[i].noteIDs.removeAll { $0 == id }
                    storageManager.folders[i].dateModified = Date()
                }
            }

            // Add to target folder if provided
            if let targetFolder = targetFolder {
                if let targetIndex = storageManager.folders.firstIndex(where: { $0.id == targetFolder.id }) {
                    storageManager.folders[targetIndex].noteIDs.append(id)
                    storageManager.folders[targetIndex].dateModified = Date()
                }
            }

            // Save all folder changes at once to ensure persistence
            storageManager.saveFoldersState()
        }

        // Refresh UI
        DispatchQueue.main.async {
            self.refreshID = UUID()
            self.dragItem = nil
        }

        return true
    }

    // Helper to check if moving a folder would create a circular reference
    func wouldCreateCircularReference(sourceID: UUID, targetID: UUID) -> Bool {
        // If source and target are the same, it would create a circular reference
        if sourceID == targetID {
            return true
        }

        // Check if target is a child of source (which would create a loop)
        var currentID = targetID
        while let folder = storageManager.folders.first(where: { $0.id == currentID }) {
            if folder.parentID == sourceID {
                return true
            }

            if let parentID = folder.parentID {
                currentID = parentID
            } else {
                break
            }
        }

        return false
    }

    // Reset drag state
    func resetDragState() {
        withAnimation(.easeInOut(duration: 0.2)) {
            dragItem = nil
        }
    }
}
