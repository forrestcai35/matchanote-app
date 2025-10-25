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
    @State var pageCount = 1
    @State var toolPicker = PKToolPicker()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var storageManager: StorageManager
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @State var currentNoteId: UUID?

    // Persist a relative zoom level across pages (1.0 = fit to screen, 2.0 = 2x fit size)
    @State var relativeZoomLevel: CGFloat = 1.0
    // Persist content offset across pages
    @State var unifiedContentOffset: CGPoint = .zero

    // Separate state for vertical scroll mode
    @State var verticalZoomLevel: CGFloat = 1.0
    @State var verticalContentOffsets: [Int: CGPoint] = [:]  // Per-page offsets

    // Stable page identifiers to prevent view recreation
    @State var pageIdentifiers: [UUID] = [UUID()]

    // Debounce timer for saving operations
    @State var saveTimer: Timer?
    // Ensure we only auto-fit once per note load
    @State var didApplyInitialFit: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if preferencesManager.noteEditorVerticalScrollMode {
                // Vertical scroll mode - all pages in a continuous scroll view
                verticalScrollContent
            } else {
                // Page mode - horizontal tabbed pages
                TabView(selection: $currentPage) {
                    ForEach(Array(pageIdentifiers.enumerated()), id: \.element) { index, pageId in
                        if index < pageCount {
                            pageContent(pageIndex: index, isInfinite: false)
                                .tag(index)
                                .id(pageId)
                        }
                    }
                }
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .clipped()
                .ignoresSafeArea(.all, edges: .bottom)
                .overlay(alignment: .bottomTrailing) {
                    controlsOverlay
                }
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
        .onChange(of: note.dateModified) { _, _ in
            // Note was modified (e.g., pages deleted from PageOverviewView)
            // Only reload if the page count has changed to avoid interfering with normal drawing changes
            if currentNoteId == note.id {
                let newPageCount = calculatePageCountFromNote()
                if newPageCount != pageCount {
                    loadDrawingData()
                }
            }
        }
        .onChange(of: toolPickerIsVisible) { _, newValue in
            updateToolPickerVisibility(newValue)
        }
        .onChange(of: currentPage) { oldPage, newPage in
            // Maintain zoom level but reset content offset to center the new page
            // This provides continuity while preventing confusing scroll positions
            unifiedContentOffset = .zero
            
            updateActiveCanvas()
        }
        .onChange(of: currentTool) { _, newTool in
            updateCanvasTool()
            // Deselect textboxes when switching away from textbox tool
            if newTool != .textbox {
                textBoxManager.deselectAllTextBoxes()
            }
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
        .onReceive(imageManager.objectWillChange) { _ in
            // Save when images change
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

    // MARK: - Tool Picker & Canvas Setup

    // MARK: - Centralized Canvas Creation
    // Creates a new canvas with consistent configuration
    func createCanvas() -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .clear
        
        // Apply finger drawing preference from settings
        canvas.drawingPolicy = preferencesManager.noteEditorFingerDrawingEnabled ? .anyInput : .pencilOnly
        
        // Configure for high-resolution rendering
        // Use 1x scale - NativeScrollCanvasView will handle display scaling
        canvas.contentScaleFactor = 2.0 // Default high-resolution scale
        canvas.layer.contentsScale = 2.0
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
    private func pageContent(pageIndex: Int, isInfinite: Bool) -> some View {
        GeometryReader { geometry in
            // Calculate fit scale for this page dynamically
            let contentSize = perPageSize(pageIndex)
            let viewportSize = geometry.size
            let fitScale = min(
                viewportSize.width / max(contentSize.width, 1),
                viewportSize.height / max(contentSize.height, 1)
            )

            // Define zoom limits relative to fit scale
            let relativeMinZoom: CGFloat = 0.75
            let relativeMaxZoom: CGFloat = 5.0
            let absoluteMinScale = fitScale * relativeMinZoom
            let absoluteMaxScale = fitScale * relativeMaxZoom

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

            if pageIndex < canvasViews.count {
                NativeScrollCanvasView(
                    canvasView: canvasViews[pageIndex],
                    contentSize: contentSize,
                    minScale: absoluteMinScale,
                    maxScale: absoluteMaxScale,
                    currentScale: absoluteScaleBinding,
                    contentOffset: $unifiedContentOffset,
                    currentTool: $currentTool,
                    onDrawingChange: { isEdited = true }
                )
                .offset(x: centerOffsetX, y: centerOffsetY)
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
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: false,
                                    isTextBoxToolActive: false
                                )

                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
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
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: currentTool == .photo,
                                    isTextBoxToolActive: currentTool == .textbox
                                )

                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
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
                    
                    // Page boundary indicators when zoomed in
                    if relativeZoomLevel > 1.5 {
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
                        relativeZoomLevel = 0.95
                        unifiedContentOffset = .zero
                        didApplyInitialFit = true
                    }
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    clampRelativeZoomIfNeeded()
                    if oldSize != .zero && abs(oldSize.width - newSize.width) > 100 {
                        unifiedContentOffset = .zero
                    }
                }
                .onChange(of: currentPage) { _, _ in
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
        let relativeMinZoom: CGFloat = 0.75
        let relativeMaxZoom: CGFloat = 5.0

        if relativeZoomLevel < relativeMinZoom {
            relativeZoomLevel = relativeMinZoom
        } else if relativeZoomLevel > relativeMaxZoom {
            relativeZoomLevel = relativeMaxZoom
        }
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
            // Left edge indicator
            if !leftEdgeVisible {
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
            
            // Right edge indicator
            if !rightEdgeVisible {
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
            
            // Top edge indicator
            if !topEdgeVisible {
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
            
            // Bottom edge indicator
            if !bottomEdgeVisible {
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
            
            // Page navigation buttons when at edges
            // Only show buttons when content is scrollable and user is at the edge
            if isScrollableHorizontally && leftEdgeVisible && currentPage > 0 {
                HStack {
                    VStack {
                        Spacer()
                        Button(action: {
                            currentPage -= 1
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
            }
            
            if isScrollableHorizontally && rightEdgeVisible && currentPage < pageCount - 1 {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Button(action: {
                            currentPage += 1
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.trailing, 16)
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
    private var verticalScrollContent: some View {
        GeometryReader { geometry in
            // Calculate a unified fit scale based on the first page (or current page)
            // This ensures all pages zoom consistently
            let referenceContentSize = perPageSize(0)
            let unifiedFitScale = min(
                geometry.size.width / max(referenceContentSize.width, 1),
                geometry.size.height / max(referenceContentSize.height, 1)
            )

            // Wrap content with zoom-enabled container
            VerticalScrollViewWithZoom(
                zoomLevel: $verticalZoomLevel,
                minZoom: 0.75,
                maxZoom: 5.0,
                unifiedFitScale: unifiedFitScale
            ) {
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(pageIdentifiers.enumerated()), id: \.element) { index, pageId in
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
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(PageVisibilityPreferenceKey.self) { positions in
                        // Find the page closest to the center of the screen
                        let screenCenter = geometry.size.height / 2
                        if let closestPage = positions.min(by: { abs($0.value - screenCenter) < abs($1.value - screenCenter) }) {
                            if currentPage != closestPage.key {
                                currentPage = closestPage.key
                            }
                        }
                    }
                    .clipped()
                    .ignoresSafeArea(.all, edges: .bottom)
                    .overlay(alignment: .bottomTrailing) {
                        verticalScrollControlsOverlay
                    }
                    .onAppear {
                        // Scroll to current page when switching to vertical mode
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if currentPage > 0 {
                                scrollProxy.scrollTo(currentPage, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: preferencesManager.noteEditorVerticalScrollMode) { _, isVertical in
                        // Scroll to current page when switching modes
                        if isVertical {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollProxy.scrollTo(currentPage, anchor: .top)
                            }
                        }
                    }
                }
            }
        }

    }
    
    // Individual page content for vertical scroll mode
    @ViewBuilder
    private func verticalPageContent(pageIndex: Int, viewportSize: CGSize, unifiedFitScale: CGFloat) -> some View {
        let contentSize = perPageSize(pageIndex)
        
        // Use the unified fit scale for consistent zoom across all pages
        let relativeMinZoom: CGFloat = 0.75
        let relativeMaxZoom: CGFloat = 5.0
        let absoluteMinScale = unifiedFitScale * relativeMinZoom
        let absoluteMaxScale = unifiedFitScale * relativeMaxZoom
        
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

        // Create per-page offset binding
        let pageOffsetBinding = Binding<CGPoint>(
            get: { verticalContentOffsets[pageIndex] ?? .zero },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    verticalContentOffsets[pageIndex] = newValue
                }
            }
        )

        // Calculate centering offset when content is smaller than viewport
        let currentScale = verticalZoomLevel * unifiedFitScale
        let scaledWidth = contentSize.width * currentScale
        let scaledHeight = contentSize.height * currentScale
        let centerOffsetX = max((viewportSize.width - scaledWidth) / 2, 0)

        // Get the current page's offset
        let pageOffset = verticalContentOffsets[pageIndex] ?? .zero

        if pageIndex < canvasViews.count {
            // Page content
            // All canvases active so any visible page can handle zoom
            NativeScrollCanvasView(
                    canvasView: canvasViews[pageIndex],
                    contentSize: contentSize,
                    minScale: absoluteMinScale,
                    maxScale: absoluteMaxScale,
                    currentScale: absoluteScaleBinding,
                    contentOffset: pageOffsetBinding,
                    currentTool: $currentTool,
                    onDrawingChange: { isEdited = true }
                )
                .frame(width: viewportSize.width, height: scaledHeight)
                .offset(x: centerOffsetX, y: 0)
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
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: false,
                                    isTextBoxToolActive: false
                                )
                                
                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isTextBoxToolActive: false
                                )
                            }
                        }
                        .frame(width: contentSize.width, height: contentSize.height)
                        .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
                        .offset(x: -pageOffset.x + centerOffsetX, y: -pageOffset.y)
                    }
                }
                .overlay {
                    // Canvas overlays (on top when tools ARE active for gesture interception)
                    if currentTool == .textbox || currentTool == .photo {
                        GeometryReader { _ in
                            ZStack(alignment: .topLeading) {
                                CanvasImageOverlay(
                                    imageManager: imageManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isPhotoToolActive: currentTool == .photo,
                                    isTextBoxToolActive: currentTool == .textbox
                                )

                                TextBoxOverlay(
                                    textBoxManager: textBoxManager,
                                    pageIndex: pageIndex,
                                    canvasSize: contentSize,
                                    isTextBoxToolActive: currentTool == .textbox
                                )
                            }
                            .frame(width: contentSize.width, height: contentSize.height)
                        .scaleEffect(verticalZoomLevel * unifiedFitScale, anchor: .topLeading)
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
                                withText: droppedText
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
    
    // Controls overlay for vertical scroll mode
    @ViewBuilder
    private var verticalScrollControlsOverlay: some View {
        Button {
            // Add page after the current page in vertical mode
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
}

// MARK: - Page Visibility Preference Key

// PreferenceKey for tracking which page is currently visible in vertical scroll mode
struct PageVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { (_, new) in new }
    }
}
