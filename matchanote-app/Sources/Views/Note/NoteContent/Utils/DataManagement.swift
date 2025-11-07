import PencilKit
import SwiftUI
import Foundation

// MARK: - Data Management Extension

extension WrittenNoteView {

    // Calculate page count from note data (used to detect external changes)
    func calculatePageCountFromNote() -> Int {
        let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
        let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? 0
        let maxPage = max(maxDrawingPage, maxImagePage)
        return max(1, maxPage + 1)
    }

    // Load drawing data when view appears
    func loadDrawingData(preserveZoom: Bool = false) {
        // Clean up existing canvas views properly
        cleanupCanvasViews()

        // Determine the number of pages based on stored drawings and images
        let requiredPageCount = calculatePageCountFromNote()

        // Initialize page identifiers for required pages
        pageIdentifiers = Array(0..<requiredPageCount).map { _ in UUID() }

        // Create canvas views for all required pages using centralized function
        for pageIndex in 0..<requiredPageCount {
            let canvas = createCanvas()

            // Load drawing data if it exists for this page
            if let drawingData = note.drawingDataByPage[String(pageIndex)] {
                do {
                    let drawing = try PKDrawing(data: drawingData)
                    canvas.drawing = drawing
                } catch {
                    print("Error loading drawing for page \(pageIndex): \(error)")
                }
            }

            canvasViews.append(canvas)
        }

        // Update page count
        pageCount = requiredPageCount

        // Restore saved page position, ensuring it's within valid range
        currentPage = min(max(0, note.currentPage), requiredPageCount - 1)

        // Reset zoom/offset only if not preserving them (e.g., full reloads)
        if !preserveZoom {
            relativeZoomLevel = ZoomConstants.initialFitZoom
            unifiedContentOffset = .zero
            didApplyInitialFit = false
        }


        // Load image data
        // CRITICAL FIX: Separate background images from canvas images during loading
        // Background images (raw Data) should NOT be loaded into canvas image manager
        // Canvas images (encoded CanvasImage objects) should be loaded into image manager

        var canvasImageData: [String: [Data]] = [:]

        for (pageKey, imageDataArray) in note.imageDataByPage {
            var canvasImages: [Data] = []

            for imageData in imageDataArray {
                // Try to decode as CanvasImage first
                if let _ = try? JSONDecoder().decode(CanvasImage.self, from: imageData) {
                    // This is an encoded CanvasImage object
                    canvasImages.append(imageData)
                }
                // Raw image data (background images from uploads) are ignored here
                // They will be displayed by backgroundImagesView() directly from note.imageDataByPage
            }

            // Only load canvas images into the image manager
            if !canvasImages.isEmpty {
                canvasImageData[pageKey] = canvasImages
            }
        }
        DispatchQueue.main.async {
        imageManager.loadImagesData(canvasImageData)
        }
        // Load textbox data
        // PERFORMANCE FIX: Defer textbox loading to next run loop to avoid interfering with zoom state
        DispatchQueue.main.async {
            textBoxManager.loadTextBoxesData(note.textBoxDataByPage)
        }
    }

    // Clean up canvas views properly
    func cleanupCanvasViews() {
        // Remove tool picker observers from existing canvas views
        for canvas in canvasViews {
            toolPicker.removeObserver(canvas)
            canvas.resignFirstResponder()
            // Clear undo manager to prevent cross-note persistence and improve performance
            canvas.undoManager?.removeAllActions()
        }

        // Clear the canvas views array
        canvasViews.removeAll()
    }

    // Save drawing data for the current note
    // Made public so it can be called before exports to ensure latest data is saved
    func saveCurrentDrawingData() {
        if let currentId = currentNoteId {
            saveDrawingDataForNote(noteId: currentId)
        }
    }

    // Helper function to filter out old canvas images from imageDataByPage
    // Returns only background images (raw image data), removing encoded CanvasImage objects
    func filterBackgroundImages(from imageDataByPage: [String: [Data]]) -> [String: [Data]] {
        var backgroundOnly: [String: [Data]] = [:]

        for (pageKey, imageDataArray) in imageDataByPage {
            // Filter to keep only raw image data (not JSON-encoded CanvasImage)
            let filteredImages = imageDataArray.filter { imageData in
                // Try to decode as CanvasImage - if it succeeds, it's a canvas image (skip it)
                // If it fails, it's raw image data (keep it)
                do {
                    _ = try JSONDecoder().decode(CanvasImage.self, from: imageData)
                    return false // Successfully decoded as CanvasImage, so skip it
                } catch {
                    return true // Failed to decode, so it's raw image data, keep it
                }
            }

            if !filteredImages.isEmpty {
                backgroundOnly[pageKey] = filteredImages
            }
        }

        return backgroundOnly
    }

    // Get the current note with latest drawing data without saving to storage
    // Useful for operations that need fresh data (like exports)
    func getCurrentNoteWithLatestData() -> Note? {
        guard let currentId = currentNoteId else { return nil }
        guard let noteToUpdate = storageManager.notes.first(where: { $0.id == currentId }) else { return nil }

        var updatedNote = noteToUpdate

        // Collect current drawing data from canvases
        var newDrawingData: [String: Data] = [:]
        for index in 0..<min(pageCount, canvasViews.count) {
            let canvas = canvasViews[index]
            let drawingData = canvas.drawing.dataRepresentation()
            newDrawingData[String(index)] = drawingData
        }

        // FIX: Filter out old canvas images before merging to prevent duplicates
        // This keeps background images while replacing old canvas images with new ones
        let canvasImageData = imageManager.getAllImagesData()
        let backgroundImages = filterBackgroundImages(from: noteToUpdate.imageDataByPage)
        var finalImageData = backgroundImages

        for (pageKey, canvasImages) in canvasImageData {
            if finalImageData[pageKey] == nil {
                finalImageData[pageKey] = []
            }
            finalImageData[pageKey]?.append(contentsOf: canvasImages)
        }

        // Get textbox data
        let textBoxData = textBoxManager.getAllTextBoxesData()

        // Update note with latest data
        updatedNote.drawingDataByPage = newDrawingData
        updatedNote.imageDataByPage = finalImageData
        updatedNote.textBoxDataByPage = textBoxData
        updatedNote.dateModified = Date()

        return updatedNote
    }

    // Save drawing data for a specific note ID
    func saveDrawingDataForNote(noteId: UUID) {
        // Find the note in storage to ensure we have the latest version
        guard let noteToSave = storageManager.notes.first(where: { $0.id == noteId }) else {
            print("Warning: Could not find note with ID \(noteId) to save")
            return
        }

        var updatedNote = noteToSave
        var hasChanges = false

        // Create new drawing data dictionary (only for pages with existing canvases)
        var newDrawingData: [String: Data] = [:]
        for index in 0..<min(pageCount, canvasViews.count) {
            let canvas = canvasViews[index]
            let drawingData = canvas.drawing.dataRepresentation()
            newDrawingData[String(index)] = drawingData
        }

        // Quick check: if the number of pages with data changed
        if newDrawingData.keys.count != noteToSave.drawingDataByPage.keys.count {
            hasChanges = true
        } else {
            // Check if any drawing data actually changed
            for (key, newData) in newDrawingData {
                if let existingData = noteToSave.drawingDataByPage[key] {
                    // Compare data sizes first for quick comparison
                    if newData.count != existingData.count || newData != existingData {
                        hasChanges = true
                        break
                    }
                } else {
                    hasChanges = true
                }
            }
        }

        // FIX: Filter out old canvas images before merging to prevent duplicates
        // 1. Background images (from home page uploads): stored as raw Data in note.imageDataByPage
        // 2. Canvas overlay images (from in-note uploads): stored as encoded CanvasImage objects

        let canvasImageData = imageManager.getAllImagesData() // Encoded CanvasImage objects
        let backgroundImages = filterBackgroundImages(from: noteToSave.imageDataByPage) // Filter out old canvas images

        // Create a merged image data structure that preserves background images
        // and replaces old canvas images with current ones
        var finalImageData = backgroundImages // Start with background images only

        // Add current canvas images (encoded CanvasImage objects) to the data structure
        for (pageKey, canvasImages) in canvasImageData {
            if finalImageData[pageKey] == nil {
                finalImageData[pageKey] = []
            }
            // Append current canvas images to background images for this page
            finalImageData[pageKey]?.append(contentsOf: canvasImages)
        }

        // Check if the final image data has changed
        if finalImageData != noteToSave.imageDataByPage {
            hasChanges = true
        }

        // Handle textbox data
        let textBoxData = textBoxManager.getAllTextBoxesData()
        if textBoxData != noteToSave.textBoxDataByPage {
            hasChanges = true
        }

        // Only save if there are actual changes
        if hasChanges {
            updatedNote.drawingDataByPage = newDrawingData
            updatedNote.imageDataByPage = finalImageData // Use merged data containing both background and canvas images
            updatedNote.textBoxDataByPage = textBoxData
            updatedNote.dateModified = Date()
            let savedNote = storageManager.saveNote(updatedNote)
            tabManager.updateNote(savedNote)

            // Reset edited flag only if this is the current note
            if noteId == note.id {
                DispatchQueue.main.async {
                    isEdited = false
                }
            }
        }
    }

    // Debounced save method to prevent rapid successive saves
    func saveCurrentDrawingDataDebounced(delay: TimeInterval = 0.5) {
        // Cancel previous timer
        saveTimer?.invalidate()

        // Create new timer
        saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                self.saveCurrentDrawingData()
            }
        }
    }

    // MARK: - Auto-Save Timer

    // Start auto-save timer that saves every 10 seconds
    func startAutoSaveTimer() {
        // Stop any existing timer first
        stopAutoSaveTimer()

        // Capture values needed for the timer closure
        let noteId = note.id
        let tabManagerRef = tabManager

        // Create new timer that repeats every 10 seconds
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            // Only save if this note is the currently active tab
            if let activeTab = tabManagerRef.getActiveTab(),
               activeTab.note.id == noteId {
                // Save current drawing data in background
                // No need to dispatch to main queue - saveCurrentDrawingData already handles threading
                saveCurrentDrawingData()
            }
        }
    }

    // Stop auto-save timer
    func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
}
