import PencilKit
import SwiftUI
import Foundation

// MARK: - Page Management Extension

extension WrittenNoteView {

    // MARK: - Page Management Functions

    func addPageAtPosition(_ position: PagePlacement) {
        // Preserve current relative zoom level and scroll position during page addition
        let currentZoom = relativeZoomLevel
        let currentOffset = unifiedContentOffset

        var insertIndex: Int
        switch position {
        case .before:
            insertIndex = currentPage
        case .after:
            insertIndex = currentPage + 1
        case .end:
            insertIndex = pageCount
        }

        // Save current drawing data before restructuring
        saveCurrentDrawingData()

        // CRITICAL FIX: Create and insert the new canvas FIRST, before updating page identifiers
        // This prevents the race condition where TabView tries to access a non-existent canvas
        let newCanvas = PKCanvasView()
        newCanvas.overrideUserInterfaceStyle = .light
        newCanvas.isScrollEnabled = false
        newCanvas.backgroundColor = .clear

        // Configure for high-resolution rendering
        newCanvas.contentScaleFactor = UIScreen.main.scale * 2
        newCanvas.layer.contentsScale = UIScreen.main.scale * 2
        newCanvas.layer.shouldRasterize = false

        newCanvas.undoManager?.removeAllActions()
        toolPicker.addObserver(newCanvas)

        // Insert the new canvas at the correct position BEFORE updating page identifiers
        canvasViews.insert(newCanvas, at: insertIndex)

        // Update drawing data mappings - shift all data after insert index
        if let currentId = currentNoteId {
            updateDrawingDataMappingsAfterInsertion(at: insertIndex, for: currentId)
        }

        // NOW it's safe to update page identifiers and count - canvas is guaranteed to exist
        pageIdentifiers.insert(UUID(), at: insertIndex)
        pageCount += 1

        // Navigate to the new page if it's before or after current
        if position == .before || position == .after {
            currentPage = insertIndex
        }

        // Update active canvas after page change
        updateActiveCanvas()

        // Restore relative zoom level and scroll position to prevent view jumping
        DispatchQueue.main.async {
            relativeZoomLevel = currentZoom
            unifiedContentOffset = currentOffset
        }
    }


    // Update drawing data key mappings when a page is inserted
    func updateDrawingDataMappingsAfterInsertion(at insertIndex: Int, for noteId: UUID) {
        guard let noteToUpdate = storageManager.notes.first(where: { $0.id == noteId }) else {
            return
        }

        var updatedNote = noteToUpdate
        var newDrawingData: [String: Data] = [:]
        var newImageData: [String: [Data]] = [:]
        var newBookmarkedPages: Set<Int> = []

        // Process all existing page data
        let maxExistingPage = max(
            updatedNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1
        )

        // Shift data for pages at or after the insert index
        for oldPageIndex in 0...max(maxExistingPage, pageCount - 2) {
            let oldKey = String(oldPageIndex)
            let newPageIndex = oldPageIndex >= insertIndex ? oldPageIndex + 1 : oldPageIndex
            let newKey = String(newPageIndex)

            // Migrate drawing data
            if let drawingData = updatedNote.drawingDataByPage[oldKey] {
                newDrawingData[newKey] = drawingData
            }

            // Migrate image data
            if let imageDataArray = updatedNote.imageDataByPage[oldKey] {
                newImageData[newKey] = imageDataArray
            }

            // Update bookmarked pages
            if updatedNote.bookmarkedPages.contains(oldPageIndex) {
                newBookmarkedPages.insert(newPageIndex)
            }
        }

        // Insert empty data for the new page
        let newPageKey = String(insertIndex)
        if newDrawingData[newPageKey] == nil {
            let emptyDrawing = PKDrawing()
            newDrawingData[newPageKey] = emptyDrawing.dataRepresentation()
        }

        // Update note with new data structure
        updatedNote.drawingDataByPage = newDrawingData
        updatedNote.imageDataByPage = newImageData
        updatedNote.bookmarkedPages = newBookmarkedPages
        updatedNote.dateModified = Date()

        // Save the updated note
        let savedNote = storageManager.saveNote(updatedNote)
        tabManager.updateNote(savedNote)

        // Update image manager with new data structure
        imageManager.loadImagesData(newImageData)

        // Handle textbox data migration for page insertion
        textBoxManager.handlePageInsertion(at: insertIndex)
    }

    // Delete a page and restructure data mappings
    func deletePage(at pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pageCount && pageCount > 1 else {
            return // Can't delete if only one page or invalid index
        }

        // Save current drawing data before restructuring
        saveCurrentDrawingData()

        // Remove the page identifier and canvas
        pageIdentifiers.remove(at: pageIndex)
        if pageIndex < canvasViews.count {
            let removedCanvas = canvasViews.remove(at: pageIndex)
            toolPicker.removeObserver(removedCanvas)
        }
        pageCount -= 1

        // Update current page if necessary
        if currentPage >= pageCount {
            currentPage = pageCount - 1
        } else if currentPage >= pageIndex {
            // If we're on or after the deleted page, adjust the current page
            currentPage = max(0, currentPage - (currentPage > pageIndex ? 1 : 0))
        }

        // Restructure data mappings
        if let currentId = currentNoteId {
            updateDrawingDataMappingsAfterDeletion(at: pageIndex, for: currentId)
        }

        // Update active canvas
        updateActiveCanvas()
    }

    // Update drawing data key mappings when a page is deleted
    func updateDrawingDataMappingsAfterDeletion(at deletedIndex: Int, for noteId: UUID) {
        guard let noteToUpdate = storageManager.notes.first(where: { $0.id == noteId }) else {
            return
        }

        var updatedNote = noteToUpdate
        var newDrawingData: [String: Data] = [:]
        var newImageData: [String: [Data]] = [:]
        var newBookmarkedPages: Set<Int> = []

        // Process all existing page data, excluding the deleted page
        let maxExistingPage = max(
            updatedNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1
        )

        for oldPageIndex in 0...maxExistingPage {
            // Skip the deleted page
            if oldPageIndex == deletedIndex {
                continue
            }

            let oldKey = String(oldPageIndex)
            let newPageIndex = oldPageIndex > deletedIndex ? oldPageIndex - 1 : oldPageIndex
            let newKey = String(newPageIndex)

            // Migrate drawing data
            if let drawingData = updatedNote.drawingDataByPage[oldKey] {
                newDrawingData[newKey] = drawingData
            }

            // Migrate image data
            if let imageDataArray = updatedNote.imageDataByPage[oldKey] {
                newImageData[newKey] = imageDataArray
            }

            // Update bookmarked pages
            if updatedNote.bookmarkedPages.contains(oldPageIndex) {
                newBookmarkedPages.insert(newPageIndex)
            }
        }

        // Update note with new data structure
        updatedNote.drawingDataByPage = newDrawingData
        updatedNote.imageDataByPage = newImageData
        updatedNote.bookmarkedPages = newBookmarkedPages
        updatedNote.dateModified = Date()

        // Save the updated note
        let savedNote = storageManager.saveNote(updatedNote)
        tabManager.updateNote(savedNote)

        // Update image manager with new data structure
        imageManager.loadImagesData(newImageData)

        // Handle textbox data migration for page deletion
        textBoxManager.handlePageDeletion(at: deletedIndex)
    }
}
