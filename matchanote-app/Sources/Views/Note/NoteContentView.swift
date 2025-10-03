import PencilKit
import SwiftDown
import SwiftUI
import UIKit

// Written Note View with PencilKit
struct WrittenNoteView: View {
    var note: Note
    @Binding var isEdited: Bool
    @Binding var toolPickerIsVisible: Bool
    @Binding var canvasViews: [PKCanvasView]
    @Binding var currentPage: Int
    @Binding var currentTool: PenTool?
    @ObservedObject var imageManager: CanvasImageManager
    @ObservedObject var textBoxManager: TextBoxManager
    // Shape recognition removed
    
    // Callback to expose add page functionality
    var onAddPageCallback: ((@escaping (PagePlacement) -> Void) -> Void)?
    var onDeletePageCallback: ((@escaping (Int) -> Void) -> Void)?
    @State private var pageCount = 1
    @State private var toolPicker = PKToolPicker()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storageManager: StorageManager
    @ObservedObject private var tabManager = TabManager.shared
    @State private var currentNoteId: UUID?
    
    // Persist a unified zoom scale across pages
    @State private var unifiedZoomScale: CGFloat = 1.0
    // Persist content offset across pages
    @State private var unifiedContentOffset: CGPoint = .zero
    
    // Stable page identifiers to prevent view recreation
    @State private var pageIdentifiers: [UUID] = [UUID()]
    
    // Debounce timer for saving operations
    @State private var saveTimer: Timer?
    // Ensure we only auto-fit once per note load
    @State private var didApplyInitialFit: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pageIdentifiers.enumerated()), id: \.element) { index, pageId in
                    if index < pageCount {
                        pageContent(pageIndex: index, isInfinite: false)
                            .tag(index)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale),
                                    removal: .opacity
                                ))
                    }
                }
            }
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                controlsOverlay
            }
        }
        .background(
            (colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
        )
        .ignoresSafeArea(.all, edges: .bottom)
        
        .onAppear {
            // Only load if this is a different note
            if currentNoteId != note.id {
                currentNoteId = note.id
                loadDrawingData()
            }
            setupToolPicker()
        }
        .onChange(of: note.id) { _, newNoteId in
            // Note changed, load new drawing data
            if currentNoteId != newNoteId {
                // Save current note data before switching
                if let currentId = currentNoteId {
                    saveDrawingDataForNote(noteId: currentId)
                }
                currentNoteId = newNoteId
                loadDrawingData()
            }
        }
        .onChange(of: toolPickerIsVisible) { _, newValue in
            updateToolPickerVisibility(newValue)
        }
        .onChange(of: currentPage) { _, newPage in
            updateActiveCanvas()
        }
        .onChange(of: currentTool) { _, newTool in
            updateCanvasTool()
        }
        .onChange(of: isEdited) { _, newValue in
            if newValue {
                saveCurrentDrawingDataDebounced()
            }
        }
        .onReceive(textBoxManager.objectWillChange) { _ in
            // Save when textboxes change
            isEdited = true
        }
        .onAppear {
            // Expose the add page functionality to the parent
            onAddPageCallback? { placement in
                addPageAtPosition(placement)
            }
            
            // Expose the delete page functionality to the parent
            onDeletePageCallback? { pageIndex in
                deletePage(at: pageIndex)
            }
        }
        .onDisappear {
            // Save any unsaved drawing data when view disappears
            saveCurrentDrawingData()
        }
    }
    
    // Load drawing data when view appears
    private func loadDrawingData() {
        // Clean up existing canvas views properly
        cleanupCanvasViews()
        
        // Determine the number of pages based on stored drawings and images
        let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
        let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? 0
        let maxPage = max(maxDrawingPage, maxImagePage)
        let requiredPageCount = max(1, maxPage + 1)
        
        // Initialize page identifiers for required pages
        pageIdentifiers = Array(0..<requiredPageCount).map { _ in UUID() }
        
        // Create canvas views for all required pages
        for pageIndex in 0..<requiredPageCount {
            let canvas = PKCanvasView()
            canvas.overrideUserInterfaceStyle = .light
            canvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
            canvas.isScrollEnabled = false
            canvas.backgroundColor = .clear

            // Configure for high-resolution rendering
            canvas.contentScaleFactor = UIScreen.main.scale * 2
            canvas.layer.contentsScale = UIScreen.main.scale * 2
            canvas.layer.shouldRasterize = false
            
            // Clear undo manager for fresh start on each note
            canvas.undoManager?.removeAllActions()
            
            // Load drawing data if it exists for this page
            if let drawingData = note.drawingDataByPage[String(pageIndex)] {
                do {
                    let drawing = try PKDrawing(data: drawingData)
                    canvas.drawing = drawing
                    
                    // Initialize undo history with the loaded drawing
                    // This ensures we have a starting point for undo operations
                    // Note: We need to access the parent's canvas manager for this
                    // For now, this will be handled by the parent view
                } catch {
                    print("Error loading drawing for page \(pageIndex): \(error)")
                }
            }
            
            canvasViews.append(canvas)
        }
        
        // Update page count
        pageCount = requiredPageCount
        
        // Reset current page to 0 when loading new note
        currentPage = 0
        
        // Reset unified zoom scale and content offset to center the canvas for new note
        unifiedZoomScale = 1.0
        unifiedContentOffset = .zero
        didApplyInitialFit = false
        
        
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
        
        // Load only canvas images into the image manager
        imageManager.loadImagesData(canvasImageData)
        
        // Load textbox data
        textBoxManager.loadTextBoxesData(note.textBoxDataByPage)
    }
    
    // Clean up canvas views properly
    private func cleanupCanvasViews() {
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
    private func saveCurrentDrawingData() {
        if let currentId = currentNoteId {
            saveDrawingDataForNote(noteId: currentId)
        }
    }
    
    // Save drawing data for a specific note ID
    private func saveDrawingDataForNote(noteId: UUID) {
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
                    break
                }
            }
        }
        
        // CRITICAL FIX: Properly handle both image types without overwriting
        // 1. Background images (from home page uploads): stored as raw Data in note.imageDataByPage
        // 2. Canvas overlay images (from in-note uploads): stored as encoded CanvasImage objects
        
        let canvasImageData = imageManager.getAllImagesData() // Encoded CanvasImage objects
        let backgroundImages = noteToSave.imageDataByPage    // Raw image Data from uploads
        
        // Create a merged image data structure that preserves both types
        var finalImageData = backgroundImages // Start with background images
        
        // Add canvas images (encoded CanvasImage objects) to the data structure
        // These will be stored alongside background images but with different data formats
        for (pageKey, canvasImages) in canvasImageData {
            if finalImageData[pageKey] == nil {
                finalImageData[pageKey] = []
            }
            // Append encoded canvas images to existing background images for this page
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
    private func saveCurrentDrawingDataDebounced(delay: TimeInterval = 0.5) {
        // Cancel previous timer
        saveTimer?.invalidate()
        
        // Create new timer
        saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                self.saveCurrentDrawingData()
            }
        }
    }
    
    // Setup the PKToolPicker for the current canvas
    private func setupToolPicker() {
        guard let currentCanvas = getCurrentCanvas() else { return }
        
        // Set tool based on current selection
        if let selectedTool = currentTool {
            currentCanvas.tool = selectedTool.toolInstance()
        } else {
            // Default to pen if no tool is selected
            currentCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
        }
        
        // Set the image manager's undo manager to match current canvas
        imageManager.setUndoManager(currentCanvas.undoManager)
        
        // Let the PencilKit system handle drawing policies
        toolPicker.setVisible(toolPickerIsVisible, forFirstResponder: currentCanvas)
        toolPicker.addObserver(currentCanvas)
        
        if toolPickerIsVisible {
            currentCanvas.becomeFirstResponder()
        }
    }
    
    private func getCurrentCanvas() -> PKCanvasView? {
        guard currentPage < canvasViews.count else { return nil }
        return canvasViews[currentPage]
    }
    
    // Update active canvas when page changes
    private func updateActiveCanvas() {
        ensureCanvasExists(for: currentPage)
        
        // Update tool picker for the current canvas
        guard let currentCanvas = getCurrentCanvas() else { return }
        
        // Update image manager's undo manager to match current canvas
        imageManager.setUndoManager(currentCanvas.undoManager)
        
        // Update visibility for current canvas
        toolPicker.setVisible(toolPickerIsVisible, forFirstResponder: currentCanvas)
        
        if toolPickerIsVisible {
            currentCanvas.becomeFirstResponder()
        }
    }
    
    // Update tool picker visibility
    private func updateToolPickerVisibility(_ isVisible: Bool) {
        guard let currentCanvas = getCurrentCanvas() else { return }
        
        toolPicker.setVisible(isVisible, forFirstResponder: currentCanvas)
        
        if isVisible {
            currentCanvas.becomeFirstResponder()
        } else {
            currentCanvas.resignFirstResponder()
        }
    }
    
    // Make sure a canvas exists for the given page index
    private func ensureCanvasExists(for pageIndex: Int) {
        // Add new canvases if needed
        while canvasViews.count <= pageIndex {
            let newCanvas = PKCanvasView()
            newCanvas.overrideUserInterfaceStyle = .light
            newCanvas.isScrollEnabled = false
            newCanvas.backgroundColor = .clear

            // Configure for high-resolution rendering
            newCanvas.contentScaleFactor = UIScreen.main.scale * 2
            newCanvas.layer.contentsScale = UIScreen.main.scale * 2
            newCanvas.layer.shouldRasterize = false
            
            // Clear undo manager for fresh start
            newCanvas.undoManager?.removeAllActions()
            
            toolPicker.addObserver(newCanvas)
            canvasViews.append(newCanvas)
            
            // Update image manager's undo manager if this is the current page
            if pageIndex == currentPage {
                imageManager.setUndoManager(newCanvas.undoManager)
            }
        }
    }
    
    // Extracted Page Content View Builder
    @ViewBuilder
    private func pageContent(pageIndex: Int, isInfinite: Bool) -> some View {
        // Wrap Canvas in a GeometryReader to get parent size for centering and safe area insets
        GeometryReader { geometry in
            // Use static zoom caps for consistent behavior across orientations
            let staticMinScale: CGFloat = 0.75
            let staticMaxScale: CGFloat = 5.0
            
            ZoomableScrollView(
                minScale: staticMinScale,
                maxScale: staticMaxScale,
                resetOnDoubleTap: true,
                currentScale: $unifiedZoomScale,
                contentOffset: $unifiedContentOffset,
                isPanEnabled: .constant(true)
            ) {

                // Content is now fixed without scrolling

                ZStack {
                    paperBackground(pageIndex: pageIndex)

                    
                    // Background images for this page (behind the canvas)
                    backgroundImagesView(pageIndex: pageIndex)
                    
                    if pageIndex < canvasViews.count {
                        PencilKitCanvasView(
                            canvasView: canvasViews[pageIndex],
                            currentTool: $currentTool,
                            canvasViews: $canvasViews,
                            currentPage: $currentPage
                        )
                        .frame(
                            width: perPageSize(pageIndex).width,
                            height: perPageSize(pageIndex).height
                        )
                        .onChange(of: canvasViews[pageIndex].drawing) { _, _ in
                            isEdited = true
                        }
                        
                        // Image overlay for this page (on top of canvas for user-added images)
                        CanvasImageOverlay(
                            imageManager: imageManager,
                            pageIndex: pageIndex,
                            canvasSize: CGSize(
                                width: perPageSize(pageIndex).width,
                                height: perPageSize(pageIndex).height
                            )
                        )
                        .frame(
                            width: perPageSize(pageIndex).width,
                            height: perPageSize(pageIndex).height
                        )
                        
                        // TextBox overlay for this page (on top of everything)
                        // Only show when textbox tool is active or there are textboxes to display
                        if currentTool == .textbox || !textBoxManager.textBoxes(for: pageIndex).isEmpty {
                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                pageIndex: pageIndex,
                                canvasSize: CGSize(
                                width: perPageSize(pageIndex).width,
                                height: perPageSize(pageIndex).height
                            )
                            )
                            .frame(
                                width: perPageSize(pageIndex).width,
                                height: perPageSize(pageIndex).height
                            )
                            .allowsHitTesting(currentTool == .textbox || textBoxManager.isEditingText)
                        }
                    } else {
                        Text("Error: Canvas not available for page \(pageIndex + 1)")
                            .foregroundColor(.red)
                            .frame(
                                width: perPageSize(pageIndex).width,
                                height: perPageSize(pageIndex).height
                            )
                    }
                }
            }
            .onAppear {
                // Auto-fit to screen on first appearance of the content after loading a note
                if !didApplyInitialFit {
                    // Calculate fit scale for initial display but don't use it as minimum
                    let contentSize = perPageSize(pageIndex)
                    let viewportSize = geometry.size
                    let fitScale = min(viewportSize.width / max(contentSize.width, 1), viewportSize.height / max(contentSize.height, 1))
                    let initialScale = max(staticMinScale, min(fitScale * 0.999, 1.0))
                    unifiedZoomScale = initialScale
                    unifiedContentOffset = .zero
                    didApplyInitialFit = true
                }
            }
            .onChange(of: geometry.size) { _, _ in
                clampScaleIfNeeded(staticMinScale)
            }
            .onChange(of: currentPage) { _, _ in
                clampScaleIfNeeded(staticMinScale)
            }
            .coordinateSpace(name: "scroll")
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    // Ensure current scale is not below the static minimum when page or geometry changes
    private func clampScaleIfNeeded(_ minScale: CGFloat) {
        if unifiedZoomScale < minScale {
            unifiedZoomScale = minScale
        }
    }
    
    @ViewBuilder
    private func backgroundImagesView(pageIndex: Int) -> some View {
        // Display images from note.imageDataByPage as backgrounds
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let imageData = imageDataArray.first,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: perPageSize(pageIndex).width,
                    height: perPageSize(pageIndex).height
                )
                .clipped()

        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func paperBackground(pageIndex: Int) -> some View {
        let paperBackground: Color = getPaperBackgroundColor(for: note.paperColor)
        Rectangle()
            .fill(paperBackground)
            .frame(
                width: perPageSize(pageIndex).width,
                height: perPageSize(pageIndex).height
            )
            .overlay {
                GeometryReader { geometry in
                    switch note.paperStyle {
                    case .grid:
                        gridOverlay(size: geometry.size)
                    case .dotted:
                        dottedOverlay(size: geometry.size)
                    case .lined:
                        linedOverlay(size: geometry.size)
                    case .blank:
                        EmptyView()
                    }
                }
            }
    }
    // Determine per-page size from background image if present; fallback to note paper size
    private func perPageSize(_ pageIndex: Int) -> CGSize {
        let baseSize: CGSize
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let imageData = imageDataArray.first,
           let uiImage = UIImage(data: imageData) {
            baseSize = uiImage.size
        } else {
            baseSize = CGSize(width: getPaperWidth(for: note.paperSize), height: getPaperHeight(for: note.paperSize))
        }
        // Render at natural size; rely on UIScreen scale for crispness
        return baseSize
    }

    @ViewBuilder
    private func gridOverlay(size: CGSize) -> some View {
        // Match prior visual density now that we render at natural size
        let gridSpacing: CGFloat = 20

        ZStack {
            // Horizontal lines
            ForEach(0..<Int(size.height / gridSpacing + 1), id: \.self) { i in
                let y = CGFloat(i) * gridSpacing
                Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
            // Vertical lines
            ForEach(0..<Int(size.width / gridSpacing + 1), id: \.self) { i in
                let x = CGFloat(i) * gridSpacing
                Line(start: CGPoint(x: x, y: 0), end: CGPoint(x: x, y: size.height))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
        }
    }
    @ViewBuilder
    private func dottedOverlay(size: CGSize) -> some View {
        // Match prior visual density at natural size
        let baseSpacing: CGFloat = 18
        let dotRadius: CGFloat = 1
        let margin: CGFloat = baseSpacing

        Canvas { context, canvasSize in
                // Calculate available space after margins
                let availableWidth = canvasSize.width - 2 * margin
                let availableHeight = canvasSize.height - 2 * margin
                
                // Calculate number of intervals that can fit
                let horizontalIntervals = max(1, Int(availableWidth / baseSpacing))
                let verticalIntervals = max(1, Int(availableHeight / baseSpacing))
                
                // Calculate dynamic spacing to fill available width
                let horizontalSpacing = availableWidth / CGFloat(horizontalIntervals)
                let verticalSpacing = availableHeight / CGFloat(verticalIntervals)
                
                // Draw dots within margins
                for y in 0...verticalIntervals {
                    for x in 0...horizontalIntervals {
                        let xPos = margin + CGFloat(x) * horizontalSpacing
                        let yPos = margin + CGFloat(y) * verticalSpacing
                        context.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: xPos - dotRadius,
                                    y: yPos - dotRadius,
                                    width: 2 * dotRadius,
                                    height: 2 * dotRadius
                                )),
                            with: .color(Color.gray.opacity(0.35))
                        )
                    }
                }
        }
        .frame(width: size.width, height: size.height)
    }
    @ViewBuilder
    private func linedOverlay(size: CGSize) -> some View {
        // Match prior visual density at natural size
        let lineSpacing: CGFloat = 24
        let marginTop: CGFloat = 30

        ZStack {
            ForEach(0..<Int((size.height - marginTop) / lineSpacing + 1), id: \.self) { i in
                let y = marginTop + CGFloat(i) * lineSpacing
                Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
        }
    }
    // Page Control View
    @ViewBuilder
    private var controlsOverlay: some View {
        Button {
            // Preserve current zoom scale and scroll position during page addition
            let currentZoom = unifiedZoomScale
            let currentOffset = unifiedContentOffset
            
            // CRITICAL FIX: Create canvas FIRST, before updating page identifiers
            // This prevents the race condition where TabView tries to access a non-existent canvas
            let newPageIndex = pageCount
            ensureCanvasExists(for: newPageIndex)
            
            // NOW it's safe to update page identifiers and count - canvas is guaranteed to exist
            pageCount += 1
            pageIdentifiers.append(UUID())
            
            // Restore zoom scale and scroll position to prevent view jumping
            DispatchQueue.main.async {
                unifiedZoomScale = currentZoom
                unifiedContentOffset = currentOffset
            }
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Text("\(currentPage + 1)/\(pageCount)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                }
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color.matchalight_dark)
            }
            .padding(8)
            .background(Color.white.opacity(0.9))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
        
        // Helper function for background color
        private func getPaperBackgroundColor(for color: PaperColor) -> Color {
            return PaperUtilities.getPaperBackgroundColor(for: color)
        }
        
        // Helper functions to get paper dimensions
        private func getPaperWidth(for size: PaperSize) -> CGFloat {
            return PaperUtilities.getPaperWidth(for: size)
        }
        
        private func getPaperHeight(for size: PaperSize) -> CGFloat {
            return PaperUtilities.getPaperHeight(for: size)
        }
        
        // MARK: - Page Management Functions
        
        func addPageAtPosition(_ position: PagePlacement) {
            // Preserve current zoom scale and scroll position during page addition
            let currentZoom = unifiedZoomScale
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
            
            // Restore zoom scale and scroll position to prevent view jumping
            DispatchQueue.main.async {
                unifiedZoomScale = currentZoom
                unifiedContentOffset = currentOffset
            }
        }
        
        
        // Update drawing data key mappings when a page is inserted
        private func updateDrawingDataMappingsAfterInsertion(at insertIndex: Int, for noteId: UUID) {
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
        private func updateDrawingDataMappingsAfterDeletion(at deletedIndex: Int, for noteId: UUID) {
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
        
        // Update canvas tool when tool selection changes
        private func updateCanvasTool() {
            guard let currentCanvas = getCurrentCanvas() else { return }
            if let selectedTool = currentTool {
                currentCanvas.tool = selectedTool.toolInstance()
            } else {
                currentCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
            }
        }
    }
    
    // Line Shape for drawing grids and lines
    struct Line: Shape {
        var start, end: CGPoint
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            return path
        }
    }
    
    // PencilKit Canvas SwiftUI wrapper
    struct PencilKitCanvasView: UIViewRepresentable {
        var canvasView: PKCanvasView
        @Binding var currentTool: PenTool?
        @Binding var canvasViews: [PKCanvasView]
        @Binding var currentPage: Int
        // Shape recognition removed
        
        func makeUIView(context: Context) -> PKCanvasView {
            canvasView.backgroundColor = .clear
            canvasView.isScrollEnabled = false  // Disable to let outer scroll view handle pan/zoom
            canvasView.overrideUserInterfaceStyle = .light

            // Configure for high-resolution rendering
            canvasView.contentScaleFactor = UIScreen.main.scale * 2  // 2x scale for crisp rendering
            canvasView.layer.contentsScale = UIScreen.main.scale * 2
            canvasView.layer.shouldRasterize = false  // Never rasterize to avoid blur

            // Set up drawing change delegate for shape recognition
            canvasView.delegate = context.coordinator

            // Add pencil interaction for double tap
            if UIPencilInteraction.preferredTapAction == .switchEraser {
                let pencilInteraction = UIPencilInteraction()
                pencilInteraction.delegate = context.coordinator
                canvasView.addInteraction(pencilInteraction)
            }

            return canvasView
        }
        
        func updateUIView(_ uiView: PKCanvasView, context: Context) {
            // No custom policy updates needed
            context.coordinator.parent = self
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, UIPencilInteractionDelegate, PKCanvasViewDelegate {
            var parent: PencilKitCanvasView
            private var previousTool: PenTool = .pen
            
            init(_ parent: PencilKitCanvasView) {
                self.parent = parent
                super.init()
                // Shape recognition configuration removed
            }
            
            func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
                // Handle double tap to switch between eraser and previous tool
                if let currentTool = parent.currentTool {
                    if currentTool == .eraser {
                        // Switch back to previous tool
                        parent.currentTool = previousTool
                        if parent.currentPage < parent.canvasViews.count {
                            parent.canvasViews[parent.currentPage].tool = previousTool.toolInstance()
                        }
                    } else {
                        // Store current tool and switch to eraser
                        previousTool = currentTool
                        parent.currentTool = .eraser
                        if parent.currentPage < parent.canvasViews.count {
                            parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
                        }
                    }
                } else {
                    // If no current tool, default to pen then switch to eraser
                    previousTool = .pen
                    parent.currentTool = .eraser
                    if parent.currentPage < parent.canvasViews.count {
                        parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
                    }
                }
            }
            
            // MARK: - PKCanvasViewDelegate
            
            func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
                // This gets called immediately when a stroke is completed
                // We can trigger recognition here by posting a notification
                NotificationCenter.default.post(name: NSNotification.Name("StrokeCompleted"), object: canvasView)
            }
            
            deinit {
                // Shape recognition cleanup removed
            }
        }
    }
    
    //Markdown View
    struct TextNoteView: View {
        var note: Note
        @State private var textContent: String
        @Binding var isEdited: Bool
        @State private var currentNoteId: UUID?
        private let infiniteScrollHeight: CGFloat = 10000
        @Environment(\.colorScheme) private var colorScheme
        @EnvironmentObject private var storageManager: StorageManager
        @ObservedObject private var tabManager = TabManager.shared
        
        // Debounce timer for saving operations
        @State private var saveTimer: Timer?
        
        // Use computed property instead of @State for theme
        private var currentTheme: Theme {
            colorScheme == .dark ? Theme.BuiltIn.defaultDark.theme() : Theme.BuiltIn.defaultLight.theme()
        }
        
        init(note: Note, isEdited: Binding<Bool>) {
            self.note = note
            _textContent = State(initialValue: note.content)
            _isEdited = isEdited
        }
        
        var body: some View {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        SwiftDownEditor(text: $textContent)
                            .insetsSize(40)
                            .theme(currentTheme)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: infiniteScrollHeight)
                            .frame(width: 700)
                            .id(colorScheme) // Force recreation when color scheme changes
                            .onChange(of: textContent) { oldValue, newValue in
                                if oldValue != newValue {
                                    isEdited = true
                                }
                            }
                        
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                }
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                .background(
                    (colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .onAppear {
                // Load content when view appears
                if currentNoteId != note.id {
                    currentNoteId = note.id
                    textContent = note.content
                }
            }
            .onChange(of: note.id) { _, newNoteId in
                // Save current note before switching
                if let currentId = currentNoteId, currentId != newNoteId {
                    saveTextContentForNote(noteId: currentId)
                }
                // Load new note content
                currentNoteId = newNoteId
                textContent = note.content
                isEdited = false
            }
            .onChange(of: isEdited) { _, newValue in
                if newValue {
                    saveCurrentTextContentDebounced()
                }
            }
            .onDisappear {
                // Save content when view disappears
                saveCurrentTextContent()
            }
        }
        
        // Save text content for the current note
        private func saveCurrentTextContent() {
            if let currentId = currentNoteId {
                saveTextContentForNote(noteId: currentId)
            }
        }
        
        // Save text content for a specific note ID
        private func saveTextContentForNote(noteId: UUID) {
            // Find the note in storage to ensure we have the latest version
            guard let noteToSave = storageManager.notes.first(where: { $0.id == noteId }) else {
                print("Warning: Could not find note with ID \(noteId) to save")
                return
            }
            
            // Only save if content has actually changed
            if textContent != noteToSave.content {
                var updatedNote = noteToSave
                updatedNote.content = textContent
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
        private func saveCurrentTextContentDebounced(delay: TimeInterval = 0.5) {
            // Cancel previous timer
            saveTimer?.invalidate()
            
            // Create new timer
            saveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.saveCurrentTextContent()
                }
            }
        }
        
        // Helper function for background color
        private func getPaperBackgroundColor(for color: PaperColor) -> Color {
            return PaperUtilities.getPaperBackgroundColor(for: color)
        }
        
    }
    
    // Custom ZoomableScrollView that provides a much more natural zooming experience
    struct ZoomableScrollView<Content: View>: UIViewRepresentable {
        private var content: Content
        private var minScale: CGFloat
        private var maxScale: CGFloat
        private var resetOnDoubleTap: Bool
        @Binding private var isPanEnabled: Bool
        
        @Binding private var currentScale: CGFloat
        @Binding private var contentOffset: CGPoint
        
        // Initialize with default scale binding
        init(
            minScale: CGFloat = 0.5,
            maxScale: CGFloat = 6.0,
            resetOnDoubleTap: Bool = true,
            currentScale: Binding<CGFloat> = .constant(1.0),
            contentOffset: Binding<CGPoint> = .constant(.zero),
            isPanEnabled: Binding<Bool> = .constant(true),
            @ViewBuilder content: () -> Content
        ) {
            self.minScale = minScale
            self.maxScale = maxScale
            self.resetOnDoubleTap = resetOnDoubleTap
            self._currentScale = currentScale
            self._contentOffset = contentOffset
            self._isPanEnabled = isPanEnabled
            self.content = content()
        }
        
        func makeUIView(context: Context) -> UIScrollView {
            // Set up the UIScrollView
            let scrollView = UIScrollView()
            scrollView.delegate = context.coordinator
            scrollView.maximumZoomScale = maxScale
            scrollView.minimumZoomScale = minScale
            scrollView.bouncesZoom = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.clipsToBounds = true
            // Disable automatic safe area content inset adjustments
            scrollView.contentInsetAdjustmentBehavior = .never
            
            // Apply initial zoom scale from binding
            let initialScale = max(min(currentScale, maxScale), minScale)
            scrollView.zoomScale = initialScale
            
            // Add the SwiftUI content
            let hostedView = UIHostingController(rootView: content).view!
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            hostedView.backgroundColor = .clear

            // Configure for lossless scaling
            hostedView.contentScaleFactor = UIScreen.main.scale
            hostedView.layer.rasterizationScale = UIScreen.main.scale
            hostedView.layer.shouldRasterize = false  // Disable rasterization to avoid blur
            
            scrollView.addSubview(hostedView)
            
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ])
            
            // Add double-tap gesture if needed
            if resetOnDoubleTap {
                let doubleTapGesture = UITapGestureRecognizer(
                    target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
                doubleTapGesture.numberOfTapsRequired = 2
                scrollView.addGestureRecognizer(doubleTapGesture)
            }
            
            // Apply initial content offset after a brief delay to ensure layout is complete
            DispatchQueue.main.async {
                if contentOffset != .zero {
                    scrollView.contentOffset = contentOffset
                } else {
                    // Force centering when content offset is zero by calling zoom delegate
                    context.coordinator.scrollViewDidZoom(scrollView)
                }
            }
            
            return scrollView
        }
        
        func updateUIView(_ uiView: UIScrollView, context: Context) {
            // Update the coordinator's parent reference
            context.coordinator.parent = self
            // Keep zoom enabled but disable panning when requested
            uiView.isScrollEnabled = true
            uiView.panGestureRecognizer.isEnabled = isPanEnabled
            
            // Update the hosting controller's rootView
            if let hostedView = uiView.subviews.first,
               let hostingController = hostedView.findViewController() as? UIHostingController<Content>
            {
                hostingController.rootView = content
            }
            
            // Only update zoom scale if the user is not currently interacting with the scroll view
            // and if there's a significant difference to avoid unnecessary updates
            let clampedScale = max(min(currentScale, maxScale), minScale)
            if !context.coordinator.isUserInteracting && abs(uiView.zoomScale - clampedScale) > 0.01 {
                uiView.setZoomScale(clampedScale, animated: false)
            }
            
            // Only update content offset for significant changes and when not interacting
            if !context.coordinator.isUserInteracting && contentOffset != .zero {
                let currentOffset = uiView.contentOffset
                let targetOffset = contentOffset
                let offsetDistance = sqrt(pow(currentOffset.x - targetOffset.x, 2) + pow(currentOffset.y - targetOffset.y, 2))
                // Use a larger threshold to reduce unwanted offset adjustments
                if offsetDistance > 20.0 {
                    uiView.contentOffset = targetOffset
                }
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, UIScrollViewDelegate {
            var parent: ZoomableScrollView
            var isUserInteracting = false
            
            init(_ parent: ZoomableScrollView) {
                self.parent = parent
            }
            
            func viewForZooming(in scrollView: UIScrollView) -> UIView? {
                return scrollView.subviews.first
            }
            
            func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
                isUserInteracting = true
            }
            
            func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
                isUserInteracting = true
            }
            
            func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
                isUserInteracting = false
                // Update the binding after user interaction ends
                if abs(parent.currentScale - scale) > 0.01 {
                    parent.currentScale = scale
                }
                // Update content offset
                parent.contentOffset = scrollView.contentOffset
            }
            
            func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
                if !decelerate {
                    isUserInteracting = false
                    parent.contentOffset = scrollView.contentOffset
                }
            }
            
            func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
                isUserInteracting = false
                parent.contentOffset = scrollView.contentOffset
            }
            
            func scrollViewDidZoom(_ scrollView: UIScrollView) {
                // Center content when it's smaller than the viewport, otherwise allow free scrolling
                let contentWidth = scrollView.contentSize.width
                let contentHeight = scrollView.contentSize.height
                let boundsWidth = scrollView.bounds.width
                let boundsHeight = scrollView.bounds.height
                
                var insets = UIEdgeInsets.zero
                
                // Only center if content is significantly smaller than viewport
                if contentWidth < boundsWidth * 0.95 {
                    let horizontalInset = max((boundsWidth - contentWidth) * 0.5, 0)
                    insets.left = horizontalInset
                    insets.right = horizontalInset
                }
                
                if contentHeight < boundsHeight * 0.95 {
                    let verticalInset = max((boundsHeight - contentHeight) * 0.5, 0)
                    insets.top = verticalInset
                    insets.bottom = verticalInset
                }
                
                scrollView.contentInset = insets
                
                // Only update binding during user interaction if the change is significant
                if isUserInteracting {
                    let newScale = scrollView.zoomScale
                    if abs(parent.currentScale - newScale) > 0.02 {
                        parent.currentScale = newScale
                    }
                }
            }
            
            func scrollViewDidScroll(_ scrollView: UIScrollView) {
                // Update content offset during scrolling, but only for significant changes
                if isUserInteracting {
                    let currentOffset = scrollView.contentOffset
                    let parentOffset = parent.contentOffset
                    let offsetDistance = sqrt(pow(currentOffset.x - parentOffset.x, 2) + pow(currentOffset.y - parentOffset.y, 2))
                    // Increase threshold to reduce update frequency and improve performance
                    if offsetDistance > 25.0 {
                        parent.contentOffset = currentOffset
                    }
                }
            }
            
            @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
                guard let scrollView = gestureRecognizer.view as? UIScrollView else { return }
                
                if scrollView.zoomScale > scrollView.minimumZoomScale {
                    // Zoom out to minimum scale
                    scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                } else {
                    // Zoom in to a reasonable scale (halfway between min and max)
                    let targetScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
                    let point = gestureRecognizer.location(in: scrollView.subviews.first ?? scrollView)
                    
                    // Calculate zoom rect centered on tap point
                    let zoomSize = CGSize(
                        width: scrollView.bounds.width / targetScale,
                        height: scrollView.bounds.height / targetScale
                    )
                    let zoomRect = CGRect(
                        x: point.x - zoomSize.width / 2,
                        y: point.y - zoomSize.height / 2,
                        width: zoomSize.width,
                        height: zoomSize.height
                    )
                    scrollView.zoom(to: zoomRect, animated: true)
                }
            }
        }
    }
    
    // Extension to find the UIViewController
    extension UIView {
        func findViewController() -> UIViewController? {
            if let nextResponder = self.next as? UIViewController {
                return nextResponder
            } else if let nextResponder = self.next as? UIView {
                return nextResponder.findViewController()
            } else {
                return nil
            }
        }
    }


