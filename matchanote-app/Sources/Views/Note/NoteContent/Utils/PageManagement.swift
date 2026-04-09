import PencilKit
import SwiftUI
import Foundation

// MARK: - Page Management Extension

extension WrittenNoteView {

    // MARK: - Page Management Functions

    func addPageAtPosition(_ position: PagePlacement) {
        // Clear any selection states that could block interactions
        imageManager.deselectImage()
        textBoxManager.deselectAllTextBoxes()


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
        let newCanvas = createCanvas()

        // Insert the new canvas at the correct position BEFORE updating page identifiers
        canvasViews.insert(newCanvas, at: insertIndex)

        // Update drawing data mappings - shift all data after insert index
        if let currentId = currentNoteId {
            updateDrawingDataMappingsAfterInsertion(at: insertIndex, for: currentId)
        }

        // NOW it's safe to update page identifiers and count - canvas is guaranteed to exist
        pageIdentifiers.insert(UUID(), at: insertIndex)
        pageCount += 1
        
        // Force TabView recreation to ensure state synchronization
        // This fixes the "frozen page" bug where TabView gets desynced after page insertion
        viewModeIdentifier = UUID()

        // Navigate to the new page if it's before or after current
        if position == .before || position == .after {
            // Use a tiny delay to let TabView register the new page structure
            // asyncAfter with 0.01s gives TabView time to update while minimizing race condition window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.currentPage = insertIndex
                }
    
                updateActiveCanvas()
            }
        }
          // Restore relative zoom level and scroll position to prevent view jumping
        DispatchQueue.main.async {
            relativeZoomLevel = currentZoom
            unifiedContentOffset = currentOffset
            updateActiveCanvas()
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
        var newTextBoxData: [String: [Data]] = [:]
        var newBookmarkedPages: Set<Int> = []

        // Process all existing page data
        let maxExistingPage = max(
            updatedNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.textBoxDataByPage.keys.compactMap { Int($0) }.max() ?? -1
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

            // Migrate textbox data
            if let textBoxDataArray = updatedNote.textBoxDataByPage[oldKey] {
                newTextBoxData[newKey] = textBoxDataArray
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
        updatedNote.textBoxDataByPage = newTextBoxData
        updatedNote.bookmarkedPages = newBookmarkedPages
        updatedNote.currentPage = currentPage
        updatedNote.dateModified = Date()

        // Save the updated note
        let savedNote = storageManager.saveNote(updatedNote)
        tabManager.updateNote(savedNote)

        // Update image manager with new data structure
        imageManager.loadImagesData(newImageData)

        // Update textbox manager with new data structure
        textBoxManager.loadTextBoxesData(newTextBoxData)
    }

    // Delete a page and restructure data mappings
    func deletePage(at pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pageCount && pageCount > 1 else {
            return // Can't delete if only one page or invalid index
        }

        // Save current drawing data before restructuring
        saveCurrentDrawingData()

        // Calculate the new current page before deletion
        let newCurrentPage: Int
        if currentPage >= pageCount - 1 {
            // If we're on the last page, move to the new last page
            newCurrentPage = pageCount - 2
        } else if currentPage >= pageIndex {
            // If we're on or after the deleted page, adjust the current page
            newCurrentPage = max(0, currentPage - (currentPage > pageIndex ? 1 : 0))
        } else {
            newCurrentPage = currentPage
        }

        // Restructure data mappings in storage
        if let currentId = currentNoteId {
            updateDrawingDataMappingsAfterDeletion(at: pageIndex, for: currentId, newCurrentPage: newCurrentPage)
        }

        // The note update will trigger onChange(of: note.dateModified) which will call loadDrawingData()
        // Set the current page in the next run loop to ensure smooth transition
        DispatchQueue.main.async {
            self.currentPage = newCurrentPage
        }
    }

    // Update drawing data key mappings when a page is deleted
    func updateDrawingDataMappingsAfterDeletion(at deletedIndex: Int, for noteId: UUID, newCurrentPage: Int) {
        guard let noteToUpdate = storageManager.notes.first(where: { $0.id == noteId }) else {
            return
        }

        var updatedNote = noteToUpdate
        var newDrawingData: [String: Data] = [:]
        var newImageData: [String: [Data]] = [:]
        var newTextBoxData: [String: [Data]] = [:]
        var newBookmarkedPages: Set<Int> = []

        // Process all existing page data, excluding the deleted page
        let maxExistingPage = max(
            updatedNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1,
            updatedNote.textBoxDataByPage.keys.compactMap { Int($0) }.max() ?? -1
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

            // Migrate textbox data
            if let textBoxDataArray = updatedNote.textBoxDataByPage[oldKey] {
                newTextBoxData[newKey] = textBoxDataArray
            }

            // Update bookmarked pages
            if updatedNote.bookmarkedPages.contains(oldPageIndex) {
                newBookmarkedPages.insert(newPageIndex)
            }
        }

        // Update note with new data structure
        updatedNote.drawingDataByPage = newDrawingData
        updatedNote.imageDataByPage = newImageData
        updatedNote.textBoxDataByPage = newTextBoxData
        updatedNote.bookmarkedPages = newBookmarkedPages
        updatedNote.currentPage = newCurrentPage
        updatedNote.dateModified = Date()

        // Save the updated note
        let savedNote = storageManager.saveNote(updatedNote)
        tabManager.updateNote(savedNote)

        // Update image manager with new data structure
        imageManager.loadImagesData(newImageData)

        // Update textbox manager with new data structure
        textBoxManager.loadTextBoxesData(newTextBoxData)
    }
}
