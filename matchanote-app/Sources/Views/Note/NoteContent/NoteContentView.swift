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
            .onChange(of: preferencesManager.noteEditorVerticalScrollMode) { oldValue, newValue in
                // Reload canvas when switching between page and vertical modes
                loadDrawingData(preserveZoom: true)
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
                let goingNarrower = newWidth < oldWidth
                // If going narrower (likely landscape -> portrait), UIPageViewController tends to keep the right page
                // Snap back to left page of the pair (even index) to preserve expected page
                let adjusted = goingNarrower && saved % 2 == 1 ? saved - 1 : saved
                UIView.setAnimationsEnabled(false)
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) {
                    viewModeIdentifier = UUID()
                    currentPage = max(0, min(pageCount - 1, adjusted))
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
            let isTransitioning = (pageIndex == transitioningPageIndex)

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

                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
                                    imageManager: imageManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isTextBoxToolActive: false
                                )
                            }
                        }
                        .frame(width: contentSize.width, height: contentSize.height)
                        .scaleEffect(relativeZoomLevel * fitScale, anchor: .topLeading)
                        .offset(x: -unifiedContentOffset.x + centerOffsetX, y: -unifiedContentOffset.y + centerOffsetY)
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

                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
                                    imageManager: imageManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isTextBoxToolActive: currentTool == .textbox
                                )
                            }
                            .frame(width: contentSize.width, height: contentSize.height)
                            .scaleEffect(relativeZoomLevel * fitScale, anchor: .topLeading)
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
                // Layering only: keep the active page above others
                .zIndex(isActive ? 2 : (isTransitioning ? 1 : 0))
                // Only the active page should receive gestures/drops
                .allowsHitTesting(pageIndex == currentPage)
      
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
                                withText: droppedText
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

        textBoxManager.addTextBox(to: pageIndex, at: canvasLocation)
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

    // Vertical scroll view displaying all pages continuously using a single unified canvas
    @ViewBuilder
    private func verticalScrollContent() -> some View {
        GeometryReader { geometry in
            if canvasViews.count == 1, let unifiedCanvas = canvasViews.first {
                verticalScrollContentBody(geometry: geometry, unifiedCanvas: unifiedCanvas)
            } else {
                Text("Loading...")
                    .foregroundColor(.gray)
            }
        }
    }

    // Helper to avoid ViewBuilder issues with guard/return
    @ViewBuilder
    private func verticalScrollContentBody(geometry: GeometryProxy, unifiedCanvas: PKCanvasView) -> some View {
        let _ = print("🔴 [VIEW] verticalScrollContentBody called")
        // BUG FIX: Don't read unifiedCanvas.contentSize - it changes on every render!
        // Instead, calculate it ourselves using the stable calculateTotalVerticalSize()
        let contentSize = calculateTotalVerticalSize()
        let _ = print("🔴 [VIEW] Got contentSize: \(contentSize)")
        let viewportSize = geometry.size
        let _ = print("🔴 [VIEW] Got viewportSize: \(viewportSize)")

        // Calculate unified fit scale based on a SINGLE page's dimensions, not total content
        // This ensures zoom levels make sense for individual pages
        let _ = print("🔴 [VIEW] About to call perPageSize(0)")
        let referencePageSize = perPageSize(0)
        let _ = print("🔴 [VIEW] Got referencePageSize: \(referencePageSize)")
        let unifiedFitScale = min(
            viewportSize.width / max(referencePageSize.width, 1),
            viewportSize.height / max(referencePageSize.height, 1)
        )

        // Define zoom limits relative to fit scale
        let absoluteMinScale = unifiedFitScale * ZoomConstants.minZoom
        let absoluteMaxScale = unifiedFitScale * ZoomConstants.maxZoom

        // Create binding that converts between relative and absolute scale
        let absoluteScaleBinding = Binding<CGFloat>(
            get: { verticalZoomLevel * unifiedFitScale },
            set: { newValue in
                // Use transaction to suppress the warning while keeping synchronous behavior
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    verticalZoomLevel = newValue / unifiedFitScale
                }
            }
        )

        // Calculate horizontal centering inset
        let scale = verticalZoomLevel * unifiedFitScale
        let scaledWidth = referencePageSize.width * scale
        let centeringInset = max(0, (viewportSize.width - scaledWidth) / 2)

        let _ = print("🔴 [VIEW] About to create NativeScrollCanvasView")
        // Use NativeScrollCanvasView with the unified canvas - gets us perfect zoom!
        NativeScrollCanvasView(
                canvasView: unifiedCanvas,
                contentSize: contentSize,
                minScale: absoluteMinScale,
                maxScale: absoluteMaxScale,
                currentScale: absoluteScaleBinding,
                contentOffset: $verticalUnifiedContentOffset,
                currentTool: $currentTool,
                showScrollIndicators: preferencesManager.noteEditorPageBoundaryIndicatorMode == .scrollBars,
                isActivePage: true,
                onDrawingChange: { isEdited = true }
        )
        .background {
            GeometryReader { _ in
                ZStack(alignment: .topLeading) {
                    // Render unified background with all pages
                    unifiedVerticalBackground()

                    // Render overlays only for current page (optimize performance)
                    if currentTool != .textbox && currentTool != .photo {
                        let pageSize = perPageSize(currentPage)
                        let yOffset = pageYOffset(for: currentPage)

                        ZStack(alignment: .topLeading) {
                            CanvasImageOverlay(
                                imageManager: imageManager,
                                textBoxManager: textBoxManager,
                                pageIndex: currentPage,
                                canvasSize: pageSize,
                                isPhotoToolActive: false,
                                isTextBoxToolActive: false
                            )

                            TextBoxOverlay(
                                textBoxManager: textBoxManager,
                                imageManager: imageManager,
                                pageIndex: currentPage,
                                canvasSize: pageSize,
                                isTextBoxToolActive: false
                            )
                        }
                        .frame(width: pageSize.width, height: pageSize.height)
                        .offset(x: 0, y: yOffset)
                    }
                }
                .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
                .offset(x: centeringInset - verticalUnifiedContentOffset.x, y: -verticalUnifiedContentOffset.y)
            }
        }
        .overlay {
            // Render overlays on top when tools ARE active (for gesture interception)
            // Only render current page for performance
            if currentTool == .textbox || currentTool == .photo {
                GeometryReader { _ in
                    let pageSize = perPageSize(currentPage)
                    let yOffset = pageYOffset(for: currentPage)

                    ZStack(alignment: .topLeading) {
                        CanvasImageOverlay(
                            imageManager: imageManager,
                            textBoxManager: textBoxManager,
                            pageIndex: currentPage,
                            canvasSize: pageSize,
                            isPhotoToolActive: currentTool == .photo,
                            isTextBoxToolActive: currentTool == .textbox
                        )

                        TextBoxOverlay(
                            textBoxManager: textBoxManager,
                            imageManager: imageManager,
                            pageIndex: currentPage,
                            canvasSize: pageSize,
                            isTextBoxToolActive: currentTool == .textbox
                        )
                    }
                    .frame(width: pageSize.width, height: pageSize.height)
                    .offset(x: 0, y: yOffset)
                    .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
                    .offset(x: centeringInset - verticalUnifiedContentOffset.x, y: -verticalUnifiedContentOffset.y)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            controlsOverlay
        }
        // Add tap gesture for textbox tool
        .simultaneousGesture(
            currentTool == .textbox ?
            SpatialTapGesture()
                .onEnded { value in
                    // Only add textbox if nothing is selected
                    guard !textBoxManager.hasSelectedTextBox else { return }

                    // Convert tap location to unified canvas coordinates
                    let scale = verticalZoomLevel * unifiedFitScale
                    let canvasX = (value.location.x - centeringInset + verticalUnifiedContentOffset.x) / scale
                    let canvasY = (value.location.y + verticalUnifiedContentOffset.y) / scale

                    // Determine which page was tapped
                    let tappedPage = detectCurrentPage(from: CGPoint(x: canvasX, y: canvasY))

                    // Convert to page-local coordinates
                    let pageYStart = pageYOffset(for: tappedPage)
                    let pageLocalY = canvasY - pageYStart
                    let canvasLocation = CGPoint(x: canvasX, y: pageLocalY)

                    textBoxManager.addTextBox(to: tappedPage, at: canvasLocation)
                }
            : nil
        )
        // Add drop gesture for AI assistant text
        .onDrop(of: [.plainText], isTargeted: nil) { providers, location in
            guard let provider = providers.first else { return false }

            provider.loadObject(ofClass: NSString.self) { text, error in
                guard let droppedText = text as? String, error == nil else { return }

                // Convert drop location to unified canvas coordinates
                let scale = verticalZoomLevel * unifiedFitScale
                let canvasX = (location.x - centeringInset + verticalUnifiedContentOffset.x) / scale
                let canvasY = (location.y + verticalUnifiedContentOffset.y) / scale

                // Determine which page was dropped on
                let droppedPage = detectCurrentPage(from: CGPoint(x: canvasX, y: canvasY))

                // Convert to page-local coordinates
                let pageYStart = pageYOffset(for: droppedPage)
                let pageLocalY = canvasY - pageYStart
                let canvasLocation = CGPoint(x: canvasX, y: pageLocalY)

                DispatchQueue.main.async {
                    // Activate textbox tool when text is dragged in
                    currentTool = .textbox

                    // Create a textbox at the drop location with the AI-generated text
                    textBoxManager.addTextBox(
                        to: droppedPage,
                        at: canvasLocation,
                        withText: droppedText
                    )
                    // Mark as edited so changes are saved
                    isEdited = true
                }
            }

            return true
        }
        .clipped()
        .ignoresSafeArea(.all, edges: .bottom)
        .onChange(of: verticalUnifiedContentOffset) { oldOffset, newOffset in
            print("🟡 [VIEW] onChange(verticalUnifiedContentOffset) fired: \(oldOffset) -> \(newOffset)")
            let detectedPage = detectCurrentPage(from: newOffset)
            if detectedPage != currentPage {
                print("🟡 [VIEW] Updating currentPage from \(currentPage) to \(detectedPage)")
                currentPage = detectedPage
            }
        }
        .onChange(of: preferencesManager.noteEditorVerticalScrollMode) { _, isVertical in
            if !isVertical {
                // When switching back to page mode, force TabView recreation
                viewModeIdentifier = UUID()
            }
        }
        .onAppear {
            print("🟢 [VIEW] onAppear fired, didApplyInitialFit: \(didApplyInitialFit)")
            if !didApplyInitialFit {
                verticalZoomLevel = ZoomConstants.initialFitZoom
                verticalUnifiedContentOffset = .zero
                didApplyInitialFit = true
                print("🟢 [VIEW] Set initial zoom and offset")
            }
        }
    }
}
