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
                    // Check if folder is already in this parent
                    if storageManager.folders[sourceFolderIndex].parentID == targetFolder.id {
                        return false // Already in this folder
                    }

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
                    // Check if folder is already at root
                    if storageManager.folders[sourceFolderIndex].parentID == nil {
                        return false // Already at root
                    }

                    storageManager.folders[sourceFolderIndex].parentID = nil
                    storageManager.saveFoldersState()
                }
            }

        case .note:
            // Check if note is already in the target location
            if let targetFolder = targetFolder {
                // Check if note is already in this folder
                let targetFolderContainsNote = storageManager.folders.first(where: { $0.id == targetFolder.id })?.noteIDs.contains(id) ?? false
                if targetFolderContainsNote {
                    return false // Already in this folder
                }
            } else {
                // Check if note is already at root (not in any folder)
                let noteInAnyFolder = storageManager.folders.contains(where: { $0.noteIDs.contains(id) })
                if !noteInAnyFolder {
                    return false // Already at root
                }
            }

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
        var visitedIDs = Set<UUID>()
        
        while let folder = storageManager.folders.first(where: { $0.id == currentID }) {
            // Cycle detection: if we've seen this folder before, break to avoid infinite loop
            if visitedIDs.contains(folder.id) {
                print("⚠️ Cycle detected in folder hierarchy at \(folder.id)")
                break
            }
            visitedIDs.insert(folder.id)
            
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

// MARK: - Drag Preview Views
// Folder drag preview that adapts to grid or list view
struct FolderDragPreview: View {
    let folder: Folder
    let isGridView: Bool

    var body: some View {
        if isGridView {
            // Grid view folder preview
            Image("folder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 175, height: 140)
                .contentShape(.dragPreview, Rectangle())
        } else {
            // List view folder preview
            Image("folder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 40)
                .contentShape(.dragPreview, Rectangle())
        }
    }
}

// Note drag preview that adapts to grid or list view
struct NoteDragPreview: View {
    let note: Note
    let isGridView: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var previewImage: UIImage? {
        // Get cached preview only (synchronous)
        let size: PreviewGenerator.PreviewSize = isGridView ? .grid : .list
        return PreviewCache.shared.getCachedPreview(for: note, size: size)
    }

    private var previewSize: CGSize {
        if isGridView {
            // Grid view sizing
            return note.paperOrientation == .landscape
                ? CGSize(width: 175, height: 140)
                : CGSize(width: 160, height: 200)
        } else {
            // List view sizing
            let baseSize: CGSize = note.paperOrientation == .landscape
                ? CGSize(width: 40, height: 32)
                : CGSize(width: 32, height: 40)
            let noteAspectRatio = PaperUtilities.paperAspectRatio(
                for: note.paperSize,
                orientation: note.paperOrientation
            )
            let area = baseSize.width * baseSize.height
            guard noteAspectRatio > 0, area > 0 else { return baseSize }
            let width = sqrt(area * noteAspectRatio)
            let height = area / width
            return CGSize(width: width, height: height)
        }
    }

    private var cornerRadius: CGFloat {
        if isGridView {
            return note.noteType == .written ? 10 : 0
        } else {
            return note.noteType == .written ? 6 : 2
        }
    }

    var body: some View {
        ZStack {
            // Background color
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(note.color)

            // Preview image if available in cache
            if let preview = previewImage {
                if isGridView {
                    TopAlignedFillImage(image: preview, targetSize: previewSize)
                } else {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: previewSize.width, height: previewSize.height, alignment: .top)
                        .clipped()
                }
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// Helper view to render a UIImage scaled to fill and top-aligned within a target size
private struct TopAlignedFillImage: View {
    let image: UIImage
    let targetSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let imgSize = image.size
            // Compute scale to cover the frame (fill)
            let scale = max(frame.width / max(imgSize.width, 1), frame.height / max(imgSize.height, 1))
            let scaledHeight = imgSize.height * scale

            Image(uiImage: image)
                .resizable()
                .frame(width: frame.width, height: scaledHeight)
                .clipped()
        }
        .frame(width: targetSize.width, height: targetSize.height)
    }
}
