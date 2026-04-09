import PencilKit
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
    @ObservedObject var toolState: ToolState

    // Callback to expose add page functionality
    var onAddPageCallback: ((@escaping (PagePlacement) -> Void) -> Void)?
    var onDeletePageCallback: ((@escaping (Int) -> Void) -> Void)?
    var onSaveCallback: ((@escaping () -> Void) -> Void)?
    @State var pageCount = 1
    @State var toolPicker = PKToolPicker()
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var storageManager: StorageManager
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var preferencesManager = PreferencesManager.shared
    @State var currentNoteId: UUID?

    // Persist a relative zoom level across pages (1.0 = fit to screen, 2.0 = 2x fit size)
    @State var relativeZoomLevel: CGFloat = ZoomConstants.initialFitZoom
    // Persist content offset across pages
    @State var unifiedContentOffset: CGPoint = .zero

    // Separate state for vertical scroll mode
    @State var verticalZoomLevel: CGFloat = ZoomConstants.initialFitZoom
    @State var verticalUnifiedContentOffset: CGPoint = .zero  // Unified offset shared across all pages
    @State var isProgrammaticScroll: Bool = false  // Flag to prevent automatic currentPage updates during programmatic scrolls

    // Stable page identifiers to prevent view recreation
    @State var pageIdentifiers: [UUID] = [UUID()]

    // Computed binding for scroll position that reads/writes to TabManager
    // This ensures each tab maintains its own independent scroll position
    private var scrollPosition: Binding<Int?> {
        Binding(
            get: {
                tabManager.getActiveTab()?.scrollPosition
            },
            set: { newValue in
                if let activeTab = tabManager.getActiveTab() {
                    tabManager.updateScrollPosition(tabId: activeTab.id, position: newValue)
                }
            }
        )
    }

    // Debounce timer for saving operations
    @State var saveTimer: Timer?
    // Auto-save timer for periodic saves every 10 seconds
    @State var autoSaveTimer: Timer?
    // Ensure we only auto-fit once per note load
    @State var didApplyInitialFit: Bool = false

    // Track view mode changes to force TabView recreation when switching modes
    @State var viewModeIdentifier: UUID = UUID()
    // Track which page is currently transitioning out to control layering/offset
    @State private var transitioningPageIndex: Int? = nil
    

    var body: some View {
        mainContentView
            .background(backgroundColorView)
            .ignoresSafeArea(.all, edges: .bottom)
            .onAppear(perform: handleInitialAppear)
            .onChange(of: note.id) { oldValue, newValue in
                handleNoteIdChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: note.dateModified) { oldValue, newValue in
                handleNoteDateModifiedChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: note.paperOrientation) { oldValue, newValue in
                handlePaperOrientationChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: toolPickerIsVisible) { oldValue, newValue in
                handleToolPickerVisibilityChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: currentPage) { oldValue, newValue in
                handleCurrentPageChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: currentTool) { oldValue, newValue in
                handleCurrentToolChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: isEdited) { oldValue, newValue in
                handleIsEditedChange(oldValue: oldValue, newValue: newValue)
            }
            .onReceive(textBoxManager.objectWillChange) { _ in
                handleTextBoxManagerChange()
            }
            .onReceive(imageManager.objectWillChange) { _ in
                handleImageManagerChange()
            }
            .onAppear(perform: exposeCallbacks)
            .onDisappear(perform: handleDisappear)
            .onChange(of: preferencesManager.noteEditorDarkModeForWhitePaper) { oldValue, newValue in
                handleDarkModePreferenceChange(oldValue: oldValue, newValue: newValue)
            }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if preferencesManager.noteEditorVerticalScrollMode {
                verticalScrollContent()
            } else {
                pageTabView
            }
        }
    }

    @ViewBuilder
    private var pageTabView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            TabView(selection: $currentPage) {
                ForEach(Array(pageIdentifiers.enumerated()), id: \.element) { index, pageId in
                    if index < pageCount {
                        pageContent(pageIndex: index)
                            .zIndex(currentPage == index ? 2 : 0)
                            .tag(index)
                            .id(pageId)
                    }
                }
            }
            .id("\(viewModeIdentifier)-\(note.id)")
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Disable implicit SwiftUI animations for TabView state updates to avoid
            // orientation-change transition quirks from UIPageViewController bridging
            .transaction { txn in
                txn.disablesAnimations = true
            }
            .clipped()
            .ignoresSafeArea(.all, edges: .bottom)
            .overlay(alignment: .bottomTrailing) {
                controlsOverlay
            }
            .onChange(of: width) { oldWidth, newWidth in
                guard oldWidth != 0, abs(oldWidth - newWidth) > 100 else { return }
                // Handle device rotation-like width changes at the TabView level to stabilize selection
                let saved = currentPage
                UIView.setAnimationsEnabled(false)
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) {
                    viewModeIdentifier = UUID()
                    // Preserve current page, just clamp to valid bounds
                    currentPage = max(0, min(pageCount - 1, saved))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
    }

    private var backgroundColorView: some View {
        colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
    }

    // MARK: - Event Handlers

    private func handleInitialAppear() {
        if currentNoteId != note.id {
            currentNoteId = note.id
            loadDrawingData()
        }
        setupToolPicker()
        startAutoSaveTimer()
        // Prefetch adjacent PDF pages for smooth swiping
        prefetchAdjacentPDFPages(currentPage: currentPage)
    }

    private func handleNoteIdChange(oldValue: UUID, newValue: UUID) {
        if currentNoteId != newValue {
            if let currentId = currentNoteId {
                saveDrawingDataForNote(noteId: currentId)
            }
            currentNoteId = newValue
            loadDrawingData()
            startAutoSaveTimer()
        }
    }

    private func handleNoteDateModifiedChange(oldValue: Date, newValue: Date) {
        if currentNoteId == note.id {
            let newPageCount = calculatePageCountFromNote()
            if newPageCount != pageCount {
                loadDrawingData()
            }
        }
    }

    private func handlePaperOrientationChange(oldValue: PaperOrientation, newValue: PaperOrientation) {
        if currentNoteId == note.id {
            relativeZoomLevel = ZoomConstants.initialFitZoom
            unifiedContentOffset = .zero
            viewModeIdentifier = UUID()
            loadDrawingData()
        }
    }

    private func handleToolPickerVisibilityChange(oldValue: Bool, newValue: Bool) {
        updateToolPickerVisibility(newValue)
    }

    private func handleCurrentPageChange(oldValue: Int, newValue: Int) {
        // Track the outgoing page index for a short transition window
        transitioningPageIndex = oldValue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            transitioningPageIndex = nil
        }
        updateActiveCanvas()
        // Prefetch adjacent pages for smooth swiping
        prefetchAdjacentPDFPages(currentPage: newValue)
    }

    private func handleCurrentToolChange(oldValue: PenTool?, newValue: PenTool?) {
        updateCanvasTool()
        if newValue != .textbox {
            textBoxManager.deselectAllTextBoxes()
        }
        if newValue != .photo {
            imageManager.deselectImage()
        }
    }

    private func handleIsEditedChange(oldValue: Bool, newValue: Bool) {
        if newValue {
            saveCurrentDrawingDataDebounced()
        }
    }

    private func handleTextBoxManagerChange() {
        isEdited = true
    }

    private func handleImageManagerChange() {
        isEdited = true
    }

    private func exposeCallbacks() {
        onAddPageCallback? { placement in
            addPageAtPosition(placement)
        }
        onDeletePageCallback? { pageIndex in
            deletePage(at: pageIndex)
        }
        onSaveCallback? {
            saveCurrentDrawingData()
        }
    }

    private func handleDisappear() {
        textBoxManager.deselectAllTextBoxes()
        saveCurrentDrawingData()
        stopAutoSaveTimer()
        // Cancel pending PDF render tasks for this note
        PDFRenderCache.shared.cancelRendersForNote(noteId: note.id.uuidString)
    }

    // MARK: - PDF Prefetching

    /// Prefetch PDF pages before and after current page for smooth swiping
    private func prefetchAdjacentPDFPages(currentPage: Int) {
        // Prefetch pages immediately adjacent (±1 from current)
        let pagesToPrefetch = [currentPage - 1, currentPage + 1]
            .filter { $0 >= 0 && $0 < pageCount }

        // Collect PDF backgrounds that need prefetching
        var pdfPages: [(pdfPath: String, pageIndex: Int, size: CGSize)] = []

        for pageIndex in pagesToPrefetch {
            // Check if this page has a PDF background
            if let imageDataArray = note.imageDataByPage[String(pageIndex)],
               let firstData = imageDataArray.first,
               let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
                let size = perPageSize(pageIndex)
                pdfPages.append((pdfPath: pdfBg.relativePath, pageIndex: pdfBg.pageIndex, size: size))
            }
        }

        // Group by PDF path and prefetch
        let groupedByPDF = Dictionary(grouping: pdfPages, by: { $0.pdfPath })

        for (pdfPath, pages) in groupedByPDF {
            let pageIndices = pages.map { $0.pageIndex }
            let size = pages.first?.size ?? CGSize(width: 1000, height: 1000)

            PDFRenderCache.shared.prefetchPages(
                pdfPath: pdfPath,
                pageIndices: pageIndices,
                size: size,
                scale: UIScreen.main.scale,
                noteId: note.id.uuidString
            )
        }
    }

    private func handleDarkModePreferenceChange(oldValue: Bool, newValue: Bool) {
        updateCanvasInterfaceStyles()
    }

    // MARK: - Tool Picker & Canvas Setup

    // Update interface styles for all canvases based on current preference
    private func updateCanvasInterfaceStyles() {
        let shouldAllowDarkMode = preferencesManager.noteEditorDarkModeForWhitePaper && note.paperColor == .white
        let interfaceStyle: UIUserInterfaceStyle = shouldAllowDarkMode ? .unspecified : .light

        for canvas in canvasViews {
            canvas.overrideUserInterfaceStyle = interfaceStyle
        }
    }

    // MARK: - Centralized Canvas Creation
    // Creates a new canvas with consistent configuration
    func createCanvas() -> PKCanvasView {
        let canvas = PKCanvasView()

        // Conditionally override to light mode:
        // - If dark mode for white paper is enabled AND paper is white, allow dark mode
        // - Otherwise, force light mode (for colored papers)
        let shouldAllowDarkMode = preferencesManager.noteEditorDarkModeForWhitePaper && note.paperColor == .white
        canvas.overrideUserInterfaceStyle = shouldAllowDarkMode ? .unspecified : .light

        canvas.backgroundColor = .clear
        
        // Apply finger drawing preference from settings
        canvas.drawingPolicy = preferencesManager.noteEditorFingerDrawingEnabled ? .anyInput : .pencilOnly
        
        // Configure for high-resolution rendering
        // Use 1x scale - NativeScrollCanvasView will handle display scaling
        canvas.contentScaleFactor = 1.0 // Default high-resolution scale
        canvas.layer.contentsScale = 1.0
        canvas.layer.shouldRasterize = false

    

        // Scroll and zoom will be managed by NativeScrollCanvasView
        // Set initial tool
        canvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
        
        // Note: undoManager comes from responder chain automatically
        // when canvas becomes first responder
        
        // Add observer for tool picker
        toolPicker.addObserver(canvas)
        
        return canvas
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

        // Set the textbox manager's undo manager to match current canvas
        textBoxManager.setUndoManager(currentCanvas.undoManager)

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
    func updateActiveCanvas() {
        // Update tool picker for the current canvas
        guard let currentCanvas = getCurrentCanvas() else { return }

        // Update image manager's undo manager to match current canvas
        imageManager.setUndoManager(currentCanvas.undoManager)

        // Update textbox manager's undo manager to match current canvas
        textBoxManager.setUndoManager(currentCanvas.undoManager)

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

    // Update canvas tool when tool selection changes
    private func updateCanvasTool() {
        guard let currentCanvas = getCurrentCanvas() else { return }
        if let selectedTool = currentTool {
            currentCanvas.tool = selectedTool.toolInstance()
        } else {
            currentCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
        }
    }

    // MARK: - Page Content View

    // Extracted Page Content View Builder
    @ViewBuilder
    private func pageContent(pageIndex: Int) -> some View {
        GeometryReader { geometry in
            // Calculate fit scale for this page dynamically
            let contentSize = perPageSize(pageIndex)
            let viewportSize = geometry.size
            let fitScale = min(
                viewportSize.width / max(contentSize.width, 1),
                viewportSize.height / max(contentSize.height, 1)
            )

            // Define zoom limits relative to fit scale
            let absoluteMinScale = fitScale * ZoomConstants.minZoom
            let absoluteMaxScale = fitScale * ZoomConstants.maxZoom

            // Create binding that converts between relative and absolute scale
            let absoluteScaleBinding = Binding<CGFloat>(
                get: { relativeZoomLevel * fitScale },
                set: { newValue in
                    // Use transaction to suppress the warning while keeping synchronous behavior
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        relativeZoomLevel = newValue / fitScale
                    }
                }
            )

            // Calculate centering offset when content is smaller than viewport
            let currentScale = relativeZoomLevel * fitScale
            let scaledWidth = contentSize.width * currentScale
            let scaledHeight = contentSize.height * currentScale
            let centerOffsetX = max((viewportSize.width - scaledWidth) / 2, 0)
            let centerOffsetY = max((viewportSize.height - scaledHeight) / 2, 0)

            // Determine active/transitioning state for layering and offsets
            let isActive = (pageIndex == currentPage)

            if pageIndex < canvasViews.count {
                NativeScrollCanvasView(
                    canvasView: canvasViews[pageIndex],
                    contentSize: contentSize,
                    minScale: absoluteMinScale,
                    maxScale: absoluteMaxScale,
                    currentScale: absoluteScaleBinding,
                    contentOffset: $unifiedContentOffset,
                    currentTool: $currentTool,
                    showScrollIndicators: preferencesManager.noteEditorPageBoundaryIndicatorMode == .scrollBars,
                    isActivePage: isActive,
                    onDrawingChange: { isEdited = true }
                )
                .offset(x: centerOffsetX, y: centerOffsetY)
                // TAP GESTURE FOR TAP TO ADD
                .simultaneousGesture(
                    // Add tap gesture for textbox tool that works alongside pan gestures
                    // SpatialTapGesture allows panning to work simultaneously
                    currentTool == .textbox ?
                    SpatialTapGesture()
                        .onEnded { value in
                            addTextboxOnTap(
                                pageIndex: pageIndex,
                                viewTap: value.location,
                                centerOffsetX: centerOffsetX,
                                centerOffsetY: centerOffsetY,
                                scale: relativeZoomLevel * fitScale,
                                contentOffset: unifiedContentOffset
                            )
                        }
                    : nil
                )
                .background {
                    GeometryReader { _ in
                        ZStack(alignment: .topLeading) {
                            // Paper background
                            paperBackground(pageIndex: pageIndex)
                                .frame(width: contentSize.width, height: contentSize.height)

                            // Background image
                            backgroundImagesView(pageIndex: pageIndex)

                            // Canvas overlays (only in background when tools NOT active)
                            if currentTool != .textbox && currentTool != .photo {
                                CanvasImageOverlay(
                                    imageManager: imageManager,
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: false,
                                    isTextBoxToolActive: false
                                )
                            }
                        }
                        .frame(width: contentSize.width, height: contentSize.height)
                        .scaleEffect(relativeZoomLevel * fitScale, anchor: .topLeading)
                        .offset(x: -unifiedContentOffset.x + centerOffsetX, y: -unifiedContentOffset.y + centerOffsetY)

                        // TextBoxOverlay rendered separately without scaleEffect to maintain vector quality
                        if currentTool != .textbox && currentTool != .photo {
                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                imageManager: imageManager,
                                toolState: toolState,
                                pageIndex: pageIndex,
                                canvasSize: contentSize,
                                isTextBoxToolActive: false,
                                zoomScale: relativeZoomLevel * fitScale
                            )
                            .offset(x: -unifiedContentOffset.x + centerOffsetX, y: -unifiedContentOffset.y + centerOffsetY)
                        }
                    }
                }
                .overlay {
                    // Canvas overlays (on top when tools ARE active for gesture interception)
                    if currentTool == .textbox || currentTool == .photo {
                        GeometryReader { _ in
                            ZStack(alignment: .topLeading) {
                                CanvasImageOverlay(
                                    imageManager: imageManager,
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: currentTool == .photo,
                                    isTextBoxToolActive: currentTool == .textbox
                                )
                            }
                            .frame(width: contentSize.width, height: contentSize.height)
                            .scaleEffect(relativeZoomLevel * fitScale, anchor: .topLeading)
                            .offset(x: -unifiedContentOffset.x + centerOffsetX, y: -unifiedContentOffset.y + centerOffsetY)

                            // TextBoxOverlay rendered separately without scaleEffect to maintain vector quality
                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                imageManager: imageManager,
                                toolState: toolState,
                                pageIndex: pageIndex,
                                canvasSize: contentSize,
                                isTextBoxToolActive: currentTool == .textbox,
                                zoomScale: relativeZoomLevel * fitScale
                            )
                            .offset(x: -unifiedContentOffset.x + centerOffsetX, y: -unifiedContentOffset.y + centerOffsetY)
                        }
                    }
                    
                    // Page boundary indicators when zoomed in (only show blue border mode, not scroll bars)
                    if relativeZoomLevel > ZoomConstants.boundaryIndicatorThreshold && preferencesManager.noteEditorPageBoundaryIndicatorMode == .blueBorder {
                        GeometryReader { indicatorGeometry in
                            pageBoundaryIndicators(
                                contentSize: contentSize,
                                viewportSize: geometry.size,
                                safeAreaInsets: indicatorGeometry.safeAreaInsets,
                                currentScale: relativeZoomLevel * fitScale,
                                centerOffsetX: centerOffsetX,
                                centerOffsetY: centerOffsetY
                            )
                        }
                    }
                }
                // Only the active page should receive gestures/drops
                .allowsHitTesting(pageIndex == currentPage)
                .clipped()
                .onDrop(of: [.plainText], isTargeted: nil) { providers, location in
                    // Handle dropped text from AI assistant
                    guard let provider = providers.first else { return false }
                    
                    provider.loadObject(ofClass: NSString.self) { text, error in
                        guard let droppedText = text as? String, error == nil else { return }
                        
                        // Convert drop location from view coordinates to canvas coordinates
                        // Account for scale, offset, and centering transformations
                        let scale = relativeZoomLevel * fitScale
                        let canvasX = (location.x - centerOffsetX + unifiedContentOffset.x) / scale
                        let canvasY = (location.y - centerOffsetY + unifiedContentOffset.y) / scale
                        let canvasLocation = CGPoint(x: canvasX, y: canvasY)
                        
                        DispatchQueue.main.async {
                            // Activate textbox tool when text is dragged in
                            currentTool = .textbox

                            // Create a textbox at the drop location with the AI-generated text
                            textBoxManager.addTextBox(
                                to: pageIndex,
                                at: canvasLocation,
                                withText: droppedText,
                                fontSize: toolState.defaultTextBoxFontSize,
                                fontFamily: toolState.defaultTextBoxFontFamily,
                                textColor: toolState.defaultTextBoxTextColor,
                                textAlignment: toolState.defaultTextBoxTextAlignment
                            )
                            // Mark as edited so changes are saved
                            isEdited = true
                        }
                    }
                    
                    return true
                }
                .onAppear {
                    if !didApplyInitialFit {
                        relativeZoomLevel = ZoomConstants.initialFitZoom
                        unifiedContentOffset = .zero
                        didApplyInitialFit = true
                    }
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    // Light-touch handling: avoid rebuilding canvases here to prevent page shifts
                    if oldSize != .zero && abs(oldSize.width - newSize.width) > 100 && pageIndex == currentPage {
                        UIView.setAnimationsEnabled(false)
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            // Keep zoom level and offset; only clamp within new bounds
                            clampRelativeZoomIfNeeded()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            UIView.setAnimationsEnabled(true)
                        }
                    } else {
                        clampRelativeZoomIfNeeded()
                    }
                }
                .onChange(of: currentPage) { _, _ in
                    // Keep zoom within bounds
                    clampRelativeZoomIfNeeded()
                }
                .edgesIgnoringSafeArea(.bottom)
            } else {
                Text("Error: Canvas not available for page \(pageIndex + 1)")
                    .foregroundColor(.red)
            }
        }
    }

    // Ensure relative zoom stays within valid bounds when page or geometry changes
    private func clampRelativeZoomIfNeeded() {
        if relativeZoomLevel < ZoomConstants.minZoom {
            relativeZoomLevel = ZoomConstants.minZoom
        } else if relativeZoomLevel > ZoomConstants.maxZoom {
            relativeZoomLevel = ZoomConstants.maxZoom
        }
    }

    // MARK: - Textbox Tap Handling (shared between page and vertical modes)
    private func addTextboxOnTap(
        pageIndex: Int,
        viewTap: CGPoint,
        centerOffsetX: CGFloat,
        centerOffsetY: CGFloat,
        scale: CGFloat,
        contentOffset: CGPoint
    ) {
        // Only when textbox tool is active and nothing selected
        guard currentTool == .textbox, !textBoxManager.hasSelectedTextBox else { return }

        // Convert tap location to canvas coordinates
        let canvasX = (viewTap.x - centerOffsetX + contentOffset.x) / max(scale, 0.0001)
        let canvasY = (viewTap.y - centerOffsetY + contentOffset.y) / max(scale, 0.0001)
        let canvasLocation = CGPoint(x: canvasX, y: canvasY)

        textBoxManager.addTextBox(
            to: pageIndex,
            at: canvasLocation,
            withText: "",
            fontSize: toolState.defaultTextBoxFontSize,
            fontFamily: toolState.defaultTextBoxFontFamily,
            textColor: toolState.defaultTextBoxTextColor,
            textAlignment: toolState.defaultTextBoxTextAlignment
        )
    }
    
    // Page boundary indicators to show page edges when zoomed in
    @ViewBuilder
    private func pageBoundaryIndicators(
        contentSize: CGSize,
        viewportSize: CGSize,
        safeAreaInsets: EdgeInsets,
        currentScale: CGFloat,
        centerOffsetX: CGFloat,
        centerOffsetY: CGFloat
    ) -> some View {
        let scaledWidth = contentSize.width * currentScale
        let scaledHeight = contentSize.height * currentScale
        
        // Calculate effective viewport size excluding safe areas
        // This is important because contentOffset works with the actual scrollable area,
        // not including safe area insets
        let effectiveViewportHeight = viewportSize.height - safeAreaInsets.top - safeAreaInsets.bottom
        
        // Only show indicators if content is actually larger than viewport (i.e., scrollable)
        let isScrollableHorizontally = scaledWidth > viewportSize.width
        let isScrollableVertically = scaledHeight > effectiveViewportHeight
        
        // Calculate the visible portion of the canvas with proper bounds checking
        // Use larger tolerance for bottom edge due to safe area and rounding issues
        let edgeTolerance: CGFloat = 20
        let bottomEdgeTolerance: CGFloat = 50  // More forgiving for bottom edge
        
        let leftEdgeVisible = !isScrollableHorizontally || unifiedContentOffset.x <= edgeTolerance
        let rightEdgeVisible = !isScrollableHorizontally || unifiedContentOffset.x + viewportSize.width >= scaledWidth - edgeTolerance
        let topEdgeVisible = !isScrollableVertically || unifiedContentOffset.y <= edgeTolerance
        
        // For bottom edge: account for effective viewport height and use larger tolerance
        let maxScrollY = max(0, scaledHeight - effectiveViewportHeight)
        let bottomEdgeVisible = !isScrollableVertically || unifiedContentOffset.y >= maxScrollY - bottomEdgeTolerance
        
        ZStack {
            // Left edge indicator (show when at left edge and horizontally scrollable)
            if isScrollableHorizontally && leftEdgeVisible {
                HStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8)
                    Spacer()
                }
            }
            
            // Right edge indicator (show when at right edge and horizontally scrollable)
            if isScrollableHorizontally && rightEdgeVisible {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.0),
                                    Color.blue.opacity(0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8)
                }
            }
            
            // Top edge indicator (show when at top edge and vertically scrollable)
            if isScrollableVertically && topEdgeVisible {
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 8)
                    Spacer()
                }
            }
            
            // Bottom edge indicator (show when at bottom edge and vertically scrollable)
            if isScrollableVertically && bottomEdgeVisible {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.0),
                                    Color.blue.opacity(0.3)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 8)
                }
            }
            
         
        }
    }

    // MARK: - Controls Overlay

    // Page Control View
    @ViewBuilder
    private var controlsOverlay: some View {
        Button {
            // Add page after the current page using the consolidated logic
            addPageAtPosition(.after)
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
    
    // MARK: - Vertical Scroll Content
    
    // Vertical scroll view displaying all pages continuously
    @ViewBuilder
    private func verticalScrollContent() -> some View {
        GeometryReader { geometry in
            // Calculate a unified fit scale based on the first page (or current page)
            // This ensures all pages zoom consistently
            let referenceContentSize = perPageSize(0)
            let unifiedFitScale = min(
                geometry.size.width / max(referenceContentSize.width, 1),
                geometry.size.height / max(referenceContentSize.height, 1)
            )

            // Wrap content with zoom-enabled container
            VerticalScrollCanvasView(
                zoomLevel: $verticalZoomLevel,
                minZoom: ZoomConstants.minZoom,
                maxZoom: ZoomConstants.maxZoom,
                unifiedFitScale: unifiedFitScale
            ) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(pageIdentifiers.enumerated()), id: \.element) { index, _ in
                            if index < pageCount {
                                verticalPageContent(
                                    pageIndex: index,
                                    viewportSize: geometry.size,
                                    unifiedFitScale: unifiedFitScale
                                )
                                .id(index)
                                .background(
                                    // Track which page is in view
                                    GeometryReader { pageGeometry in
                                        Color.clear.preference(
                                            key: PageVisibilityPreferenceKey.self,
                                            value: [index: pageGeometry.frame(in: .named("scroll")).midY]
                                        )
                                    }
                                )
                            }
                        }
                    }

                }
                .scrollPosition(id: scrollPosition, anchor: .top)
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(PageVisibilityPreferenceKey.self) { positions in
                    // Skip automatic currentPage updates during programmatic scrolls
                    guard !isProgrammaticScroll else { return }

                    // Find the page closest to the center of the screen
                    let screenCenter = geometry.size.height / 2
                    if let closestPage = positions.min(by: { abs($0.value - screenCenter) < abs($1.value - screenCenter) }) {
                        if currentPage != closestPage.key {
                            currentPage = closestPage.key
                        }
                    }
                }
                .onChange(of: scrollPosition.wrappedValue) { _, newPosition in
                    // Sync scrollPosition back to currentPage when user scrolls
                    if let newPosition = newPosition, newPosition != currentPage {
                        isProgrammaticScroll = true
                        currentPage = newPosition
                        // Clear flag after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isProgrammaticScroll = false
                        }
                    }
                }
                .clipped()
                .ignoresSafeArea(.all, edges: .bottom)
                .onAppear {
                    // Set scroll position declaratively (like TabView selection)
                    scrollPosition.wrappedValue = currentPage
                }
                .onChange(of: preferencesManager.noteEditorVerticalScrollMode) { _, isVertical in
                    if isVertical {
                        // Set scroll position when switching to vertical mode
                        scrollPosition.wrappedValue = currentPage
                    } else {
                        // When switching back to page mode, force TabView recreation
                        // to ensure it displays the correct page
                        viewModeIdentifier = UUID()
                    }
                }
                .onChange(of: note.id) { _, _ in
                    // Set scroll position when note changes
                    guard preferencesManager.noteEditorVerticalScrollMode else { return }
                    isProgrammaticScroll = true
                    scrollPosition.wrappedValue = currentPage
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isProgrammaticScroll = false
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                controlsOverlay
            }
        }

    }
    
    // Individual page content for vertical scroll mode
    @ViewBuilder
    private func verticalPageContent(pageIndex: Int, viewportSize: CGSize, unifiedFitScale: CGFloat) -> some View {
        let contentSize = perPageSize(pageIndex)
        
        // Use the unified fit scale for consistent zoom across all pages
        let absoluteMinScale = unifiedFitScale * ZoomConstants.minZoom
        let absoluteMaxScale = unifiedFitScale * ZoomConstants.maxZoom
        
        // Create binding that converts between relative and absolute scale using unified fit scale
        // Use separate vertical zoom state for vertical scroll mode
        let absoluteScaleBinding = Binding<CGFloat>(
            get: { verticalZoomLevel * unifiedFitScale },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    verticalZoomLevel = newValue / unifiedFitScale
                }
            }
        )

        // Use unified offset binding shared across ALL pages
        // This makes all pages pan together when zoomed
        let pageOffsetBinding = Binding<CGPoint>(
            get: { verticalUnifiedContentOffset },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    verticalUnifiedContentOffset = newValue
                }
            }
        )

        // Calculate centering offset when content is smaller than viewport
        let currentScale = verticalZoomLevel * unifiedFitScale
        let scaledWidth = contentSize.width * currentScale
        let scaledHeight = contentSize.height * currentScale
        let centerOffsetX = max((viewportSize.width - scaledWidth) / 2, 0)

        // Use unified offset for all pages
        let pageOffset = verticalUnifiedContentOffset

        if pageIndex < canvasViews.count {
            // Page content - use VerticalModeCanvasView for vertical scroll mode
            VerticalModeCanvasView(
                    canvasView: canvasViews[pageIndex],
                    contentSize: contentSize,
                    minScale: absoluteMinScale,
                    maxScale: absoluteMaxScale,
                    currentScale: absoluteScaleBinding,
                    contentOffset: pageOffsetBinding,
                    currentTool: $currentTool,
                    showScrollIndicators: preferencesManager.noteEditorPageBoundaryIndicatorMode == .scrollBars,
                    onDrawingChange: { isEdited = true }
                )
                .frame(width: viewportSize.width, height: scaledHeight)
                .offset(x: centerOffsetX, y: 0)
                // TAP GESTURE FOR TAP TO ADD (same placement as page mode)
                .simultaneousGesture(
                    currentTool == .textbox ?
                    SpatialTapGesture()
                        .onEnded { value in
                            addTextboxOnTap(
                                pageIndex: pageIndex,
                                viewTap: value.location,
                                centerOffsetX: centerOffsetX,
                                centerOffsetY: 0,
                                scale: verticalZoomLevel * unifiedFitScale,
                                contentOffset: pageOffset
                            )
                        }
                    : nil
                )
                .background {
                    GeometryReader { _ in
                        ZStack(alignment: .topLeading) {
                            // Paper background
                            paperBackground(pageIndex: pageIndex)
                                .frame(width: contentSize.width, height: contentSize.height)
                            
                            // Background image
                            backgroundImagesView(pageIndex: pageIndex)
                            
                            // Canvas overlays (only in background when tools NOT active)
                            if currentTool != .textbox && currentTool != .photo {
                                CanvasImageOverlay(
                                    imageManager: imageManager,
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: false,
                                    isTextBoxToolActive: false
                                )
                            }
                        }
                        .frame(width: contentSize.width, height: contentSize.height)
                        .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
                        .offset(x: -pageOffset.x + centerOffsetX, y: -pageOffset.y)

                        // TextBoxOverlay rendered separately without scaleEffect to maintain vector quality
                        if currentTool != .textbox && currentTool != .photo {
                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                imageManager: imageManager,
                                toolState: toolState,
                                pageIndex: pageIndex,
                                canvasSize: contentSize,
                                isTextBoxToolActive: false,
                                zoomScale: verticalZoomLevel * unifiedFitScale
                            )
                            .offset(x: -pageOffset.x + centerOffsetX, y: -pageOffset.y)
                        }
                    }
                }
                .overlay {
                    // Canvas overlays (on top when tools ARE active for gesture interception)
                    if currentTool == .textbox || currentTool == .photo {
                        GeometryReader { _ in
                            ZStack(alignment: .topLeading) {
                                CanvasImageOverlay(
                                    imageManager: imageManager,
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: currentTool == .photo,
                                    isTextBoxToolActive: currentTool == .textbox
                                )
                            }
                            .frame(width: contentSize.width, height: contentSize.height)
                            .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
                            .offset(x: -pageOffset.x + centerOffsetX, y: -pageOffset.y)

                            // TextBoxOverlay rendered separately without scaleEffect to maintain vector quality
                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                imageManager: imageManager,
                                toolState: toolState,
                                pageIndex: pageIndex,
                                canvasSize: contentSize,
                                isTextBoxToolActive: currentTool == .textbox,
                                zoomScale: verticalZoomLevel * unifiedFitScale
                            )
                            .offset(x: -pageOffset.x + centerOffsetX, y: -pageOffset.y)
                        }
                    }
                }
                .onDrop(of: [.plainText], isTargeted: nil) { providers, location in
                    // Handle dropped text from AI assistant
                    guard let provider = providers.first else { return false }
                    
                    provider.loadObject(ofClass: NSString.self) { text, error in
                        guard let droppedText = text as? String, error == nil else { return }
                        
                        // Convert drop location from view coordinates to canvas coordinates
                        let scale = verticalZoomLevel * unifiedFitScale
                        let canvasX = (location.x - centerOffsetX + pageOffset.x) / scale
                        let canvasY = (location.y + pageOffset.y) / scale
                        let canvasLocation = CGPoint(x: canvasX, y: canvasY)
                        
                        DispatchQueue.main.async {
                            // Activate textbox tool when text is dragged in
                            currentTool = .textbox

                            // Create a textbox at the drop location with the AI-generated text
                            textBoxManager.addTextBox(
                                to: pageIndex,
                                at: canvasLocation,
                                withText: droppedText,
                                fontSize: toolState.defaultTextBoxFontSize,
                                fontFamily: toolState.defaultTextBoxFontFamily,
                                textColor: toolState.defaultTextBoxTextColor,
                                textAlignment: toolState.defaultTextBoxTextAlignment
                            )
                            // Mark as edited so changes are saved
                            isEdited = true
                        }
                    }
                    
                    return true
                }
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            Text("Error: Canvas not available for page \(pageIndex + 1)")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Page Visibility Preference Key

// PreferenceKey for tracking which page is currently visible in vertical scroll mode
struct PageVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { (_, new) in new }
    }
}
