//
//  NoteView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import PencilKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PDFKit



// Per-note undo history storage
struct NoteUndoHistory {
  var pageUndoStates: [Int: [PKDrawing]] = [:] // Page index -> undo stack
  var pageRedoStates: [Int: [PKDrawing]] = [:] // Page index -> redo stack
  var maxHistorySize: Int = 50 // Limit memory usage
}

// Canvas manager to track canvas views per note with isolated undo/redo
class CanvasManager: ObservableObject {
  @Published var canvasViews: [PKCanvasView] = []
  @Published var imageManager = CanvasImageManager()

  // Per-note undo history - NOT cleared when switching notes
  private var undoHistories: [UUID: NoteUndoHistory] = [:]
  private var currentNoteId: UUID?

  init() {
    // PERFORMANCE FIX: Defer canvas creation until actually needed
    canvasViews = []
  }
  
  // PERFORMANCE FIX: Lazy canvas creation
  func ensureCanvasExists(for pageIndex: Int) {
    while canvasViews.count <= pageIndex {
      let canvas = PKCanvasView()
      canvas.overrideUserInterfaceStyle = .light
      canvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
      canvasViews.append(canvas)
    }
  }

  // Set current note and load its undo history
  func setCurrentNote(_ noteId: UUID) {
    // Save current note's undo state before switching
    if let currentId = currentNoteId {
      saveUndoStateForNote(currentId)
    }

    currentNoteId = noteId

    // Initialize undo history for new note if needed
    if undoHistories[noteId] == nil {
      undoHistories[noteId] = NoteUndoHistory()
    }

    // Load undo state for new note
    loadUndoStateForNote(noteId)
  }

  // PERFORMANCE FIX: Only save undo state for canvases that actually exist
  private func saveUndoStateForNote(_ noteId: UUID) {
    guard var history = undoHistories[noteId] else { return }
    guard !canvasViews.isEmpty else { return }

    // Save current drawing states for each page
    for (pageIndex, canvas) in canvasViews.enumerated() {
      let currentDrawing = canvas.drawing

      // Initialize page history if needed
      if history.pageUndoStates[pageIndex] == nil {
        history.pageUndoStates[pageIndex] = []
      }

      // Add current state to undo stack (limit size)
      history.pageUndoStates[pageIndex]?.append(currentDrawing)
      if let count = history.pageUndoStates[pageIndex]?.count, count > history.maxHistorySize {
        history.pageUndoStates[pageIndex]?.removeFirst()
      }
    }

    undoHistories[noteId] = history
  }

  // Load undo state for a specific note
  private func loadUndoStateForNote(_ noteId: UUID) {
    // Clear current undo managers without removing actions
    for _ in canvasViews {
      // Don't clear - let the system handle it naturally
      // We'll track our own undo state
    }
  }

  // Perform undo for current note and page
  func performUndo(for pageIndex: Int) -> Bool {
    guard let noteId = currentNoteId,
          var history = undoHistories[noteId],
          let undoStack = history.pageUndoStates[pageIndex],
          undoStack.count > 1 else { return false }

    // PERFORMANCE FIX: Ensure canvas exists before accessing
    ensureCanvasExists(for: pageIndex)
    guard pageIndex < canvasViews.count else { return false }
    
    let canvas = canvasViews[pageIndex]
    let currentDrawing = canvas.drawing

    // Move current state to redo stack
    if history.pageRedoStates[pageIndex] == nil {
      history.pageRedoStates[pageIndex] = []
    }
    history.pageRedoStates[pageIndex]?.append(currentDrawing)

    // Limit redo stack size
    if let redoCount = history.pageRedoStates[pageIndex]?.count, redoCount > history.maxHistorySize {
      history.pageRedoStates[pageIndex]?.removeFirst()
    }

    // Remove current state from undo stack and apply previous
    var newUndoStack = undoStack
    newUndoStack.removeLast()

    if let previousDrawing = newUndoStack.last {
      canvas.drawing = previousDrawing
    }

    history.pageUndoStates[pageIndex] = newUndoStack
    undoHistories[noteId] = history

    return true
  }

  // Perform redo for current note and page
  func performRedo(for pageIndex: Int) -> Bool {
    guard let noteId = currentNoteId,
          var history = undoHistories[noteId],
          let redoStack = history.pageRedoStates[pageIndex],
          !redoStack.isEmpty else { return false }

    // PERFORMANCE FIX: Ensure canvas exists before accessing
    ensureCanvasExists(for: pageIndex)
    guard pageIndex < canvasViews.count else { return false }
    
    let canvas = canvasViews[pageIndex]
    let currentDrawing = canvas.drawing

    // Move current state to undo stack
    if history.pageUndoStates[pageIndex] == nil {
      history.pageUndoStates[pageIndex] = []
    }
    history.pageUndoStates[pageIndex]?.append(currentDrawing)

    // Get next state from redo stack
    var newRedoStack = redoStack
    let nextDrawing = newRedoStack.removeLast()
    canvas.drawing = nextDrawing

    history.pageRedoStates[pageIndex] = newRedoStack
    undoHistories[noteId] = history

    return true
  }

  // Add new undo state when user makes changes
  func addUndoState(for pageIndex: Int, drawing: PKDrawing) {
    guard let noteId = currentNoteId else { return }

    if undoHistories[noteId] == nil {
      undoHistories[noteId] = NoteUndoHistory()
    }

    var history = undoHistories[noteId]!

    // Clear redo stack when new action is made
    history.pageRedoStates[pageIndex] = []

    // Add to undo stack
    if history.pageUndoStates[pageIndex] == nil {
      history.pageUndoStates[pageIndex] = []
    }

    history.pageUndoStates[pageIndex]?.append(drawing)

    // Limit stack size
    if let count = history.pageUndoStates[pageIndex]?.count, count > history.maxHistorySize {
      history.pageUndoStates[pageIndex]?.removeFirst()
    }

    undoHistories[noteId] = history
  }


  // REMOVED: No longer clear undo managers - maintain per-note history
}

struct NoteView: View {
  var note: Note
  @Environment(\.dismiss) var dismiss
  @State public var isAssistantVisible = false
  @State private var assistantWidth: CGFloat = 300
  @State private var assistantHeight: CGFloat = 300
  @State private var assistantOrientation: AssistantOrientation = PreferencesManager.shared.assistantDefaultOrientation
  @State private var isDraggingAssistant = false
  @State private var draggedPosition: AssistantOrientation? = nil
  @State private var dragLocation: CGPoint = .zero
  @ObservedObject private var tabManager = TabManager.shared
  @State private var isEdited = false
  @State private var toolPickerIsVisible = false
  @StateObject private var assistantState = AIAssistantState()
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager
  // Added for lasso tool functionality - now managed per note
  @State private var canvasManager = CanvasManager()
  @State private var currentPage: Int = 0
  @State private var currentTool: PenTool? = .pen
  @StateObject private var textBoxManager = TextBoxManager()
  // Shape recognition removed

  // Expose add page functionality
  @State private var addPageCallback: ((PagePlacement) -> Void)?
  @State private var deletePageCallback: ((Int) -> Void)?

  init(note: Note) {
    self.note = note
  }

  // Opens note in tab
  private func openNoteInTab() {
    tabManager.openTab(note: note)
  }

  // Clear the current page
  private func clearCurrentPage() {
    guard currentPage < canvasManager.canvasViews.count else { return }
    
    let canvas = canvasManager.canvasViews[currentPage]
    
    // Store the current drawing for undo functionality
    let currentDrawing = canvas.drawing
    
    // Register undo action before clearing
    canvas.undoManager?.registerUndo(withTarget: canvas) { targetCanvas in
      targetCanvas.drawing = currentDrawing
    }
    
    // Set undo action name for better UX
    canvas.undoManager?.setActionName("Clear Page")
    
    // Clear the drawing
    canvas.drawing = PKDrawing()
    
    // Clear all images from the current page
    canvasManager.imageManager.clearAllImagesFromPage(currentPage)
    
    // Clear all textboxes from the current page
    textBoxManager.clearAllTextBoxesFromPage(currentPage)
    
    // Mark as edited to trigger save
    isEdited = true
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack(spacing: 0) {
          // Tab bar
          TabBarView(
            dismiss: dismiss,
            clearPageAction: clearCurrentPage,
            deletePageAction: { deletePageCallback?(currentPage) },
            exportCurrentPageAction: { handleExport(pages: [currentPage]) },
            exportAllPagesAction: { handleExport(pages: Array(0..<totalPages)) },
            printCurrentPageAction: { handlePrint(pages: [currentPage]) },
            printAllPagesAction: { handlePrint(pages: Array(0..<totalPages)) },
            onAddPage: { placement in
              addPageCallback?(placement)
            },
            onUpload: { placement in
              handleUpload(placement: placement)
            }
          )

          if let activeTab = tabManager.getActiveTab() {
            // Showcase Contextual Toolbars
            WrittenNoteToolbar(
              isAssistantVisible: $isAssistantVisible,
              note: activeTab.note,
              canvasViews: $canvasManager.canvasViews,
              currentPage: $currentPage,
              currentTool: $currentTool,
              imageManager: canvasManager.imageManager,
              textBoxManager: textBoxManager)
            Divider()
          } else if !tabManager.tabs.isEmpty {
            // Edge case for handling active tab + no tabs open
            Text("Error: No active tab found")
              .foregroundColor(.red)
          }

          // Main content with AI assistant overlay
          ZStack {
            // Main content
            mainContentView()
            
            // AI ASSISTANT OVERLAY - constrained to main content area
            if isAssistantVisible {
              HStack(spacing: 0) {
                // Left-side assistant
                if assistantOrientation == .left {
                  assistantPanelView()
                }
                
                Spacer()
                
                // Right-side assistant
                if assistantOrientation == .right {
                  assistantPanelView()
                }
              }
            }
          }
        }


        // Hover indicator overlay
        if isDraggingAssistant, let hoveredPosition = draggedPosition {
          orientationIndicator(
            for: hoveredPosition,
            in: CGSize(width: geometry.size.width, height: geometry.size.height)
          )
        }
      }
      .onAppear {
        // PERFORMANCE OPTIMIZED: Immediate essential operations only
        openNoteInTab()
        canvasManager.setCurrentNote(note.id)
        tabManager.onAllTabsClosed = { dismiss() }

        // PERFORMANCE OPTIMIZED: Defer all heavy operations with lower priority
        Task(priority: .background) {
          // Group all background tasks to reduce task creation overhead
          var updated = note
          updated.lastOpenedAt = Date()

          await MainActor.run {
            let saved = storageManager.saveNote(updated)
            tabManager.updateNote(saved)
          }

          // Defer cleanup and observer setup to avoid blocking UI
          await Task.yield() // Let other tasks run

          await MainActor.run {
            cleanupOrphanedTabs()
            setupAppLifecycleObservers()
          }
        }
      }
      .onDisappear {
        // Clean up the callback
        tabManager.onAllTabsClosed = nil
        
        // Remove app lifecycle observers
        removeAppLifecycleObservers()
      }
    }
  }
  
  // Clean up tabs for notes that no longer exist
  private func cleanupOrphanedTabs() {
    let existingNoteIds = Set(storageManager.notes.map { $0.id })
    let tabsToClose = tabManager.tabs.filter { !existingNoteIds.contains($0.note.id) }
    
    for tab in tabsToClose {
      tabManager.closeTab(id: tab.id)
    }
  }
  
  // Set up app lifecycle observers (no longer clear undo managers)
  private func setupAppLifecycleObservers() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { _ in
      // Per-note undo history is now preserved - no clearing needed
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { _ in
      // Per-note undo history is now preserved - no clearing needed
    }
  }
  
  // Remove app lifecycle observers
  private func removeAppLifecycleObservers() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }

  // NOTES MAIN CONTENT VIEW
  @ViewBuilder
  private func mainContentView() -> some View {
    VStack {
      if let activeTab = tabManager.getActiveTab() {
        // Check if the note still exists in storage
        if storageManager.notes.contains(where: { $0.id == activeTab.note.id }) {
          // Written note view
          WrittenNoteView(
            note: activeTab.note,
            isEdited: $isEdited,
            toolPickerIsVisible: $toolPickerIsVisible,
            canvasViews: $canvasManager.canvasViews,
            currentPage: $currentPage,
            currentTool: $currentTool,
            imageManager: canvasManager.imageManager,
            textBoxManager: textBoxManager,
            onAddPageCallback: { callback in
              addPageCallback = callback
            },
            onDeletePageCallback: { callback in
              deletePageCallback = callback
            })
        } else {
          // Note has been deleted, show message and close tab
          VStack {
            Text("This note has been deleted")
              .foregroundColor(.red)
              .font(.headline)
            Button("Close Tab") {
              tabManager.closeTab(id: activeTab.id)
            }
            .padding()
          }
        }
      } else if !tabManager.tabs.isEmpty {
        let firstTab = tabManager.tabs[0]
        // Check if the note still exists in storage
        if storageManager.notes.contains(where: { $0.id == firstTab.note.id }) {
          // Written note view for fallback if we close a tab
          WrittenNoteView(
            note: firstTab.note,
            isEdited: $isEdited,
            toolPickerIsVisible: $toolPickerIsVisible,
            canvasViews: $canvasManager.canvasViews,
            currentPage: $currentPage,
            currentTool: $currentTool,
            imageManager: canvasManager.imageManager,
            textBoxManager: textBoxManager,
            onAddPageCallback: { callback in
              addPageCallback = callback
            },
            onDeletePageCallback: { callback in
              deletePageCallback = callback
            })
        } else {
          // Note has been deleted, show message and close tab
          VStack {
            Text("This note has been deleted")
              .foregroundColor(.red)
              .font(.headline)
            Button("Close Tab") {
              tabManager.closeTab(id: firstTab.id)
            }
            .padding()
          }
        }
      } else {
        // This case should never be reached since we auto-dismiss when no tabs remain
        EmptyView()
      }
    }
    .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
  }

  // Orientation hover indicator
  @ViewBuilder
  private func orientationIndicator(for orientation: AssistantOrientation, in size: CGSize)
-> some View
  {
    ZStack {
      // Transparent overlay to avoid darkening content
      Color.clear
        .edgesIgnoringSafeArea(.all)

      // Position indicator - covers entire side
      Group {
        switch orientation {
        case .right:
          // Cover right side with reasonable width
          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  Color.matchalight_light.opacity(0.15),
                  Color.matchalight_light.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: min(300, size.width * 0.25), height: size.height)
            .overlay(
              Rectangle()
                .strokeBorder(
                  LinearGradient(
                    colors: [
                      Color.matchalight_light.opacity(0.6),
                      Color.matchalight_light.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                  ),
                  lineWidth: 3
                )
            )
            .position(x: size.width - min(300, size.width * 0.25) / 2, y: size.height / 2)
        case .left:
          // Cover left side with reasonable width
          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  Color.matchalight_light.opacity(0.15),
                  Color.matchalight_light.opacity(0.05)
                ],
                startPoint: .trailing,
                endPoint: .leading
              )
            )
            .frame(width: min(300, size.width * 0.25), height: size.height)
            .overlay(
              Rectangle()
                .strokeBorder(
                  LinearGradient(
                    colors: [
                      Color.matchalight_light.opacity(0.6),
                      Color.matchalight_light.opacity(0.3)
                    ],
                    startPoint: .trailing,
                    endPoint: .leading
                  ),
                  lineWidth: 3
                )
            )
            .position(x: min(300, size.width * 0.25) / 2, y: size.height / 2)
        }
      }

    }
  }

  // Resizable handle overlay (transparent, does not consume width)
  @ViewBuilder
  private func resizeHandleOverlay(for orientation: AssistantOrientation) -> some View {
    let hitWidth: CGFloat = 28
    // Use a clear overlay for large hit target; optionally add a 1pt separator if desired
    ZStack(alignment: orientation == .right ? .trailing : .leading) {
      Color.clear

    }
    .frame(width: hitWidth)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          let newWidth: CGFloat
          switch orientation {
          case .left:
            newWidth = max(250, min(700, assistantWidth + value.translation.width))
          case .right:
            newWidth = max(250, min(700, assistantWidth - value.translation.width))
          }
          assistantWidth = newWidth
        }
    )
  }

  // Extracted assistant panel view
  @ViewBuilder
  private func assistantPanelView() -> some View {
    AIAssistantView()
      .environmentObject(assistantState)
      .frame(width: assistantWidth)
      .contentShape(Rectangle())
      .onAppear {
        if let activeTab = tabManager.getActiveTab() {
          // Set current note for AI assistant
          assistantState.currentNote = activeTab.note
        }
      }
      // Drag to flip orientation
      .gesture(
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
          .onChanged { value in
            isDraggingAssistant = true
            dragLocation = value.location

            // Determine direction based on horizontal movement
            if value.translation.width > 0 {
              // Dragged right
              draggedPosition = .right
            } else {
              // Dragged left
              draggedPosition = .left
            }
          }
          .onEnded { value in
            // Reset dragging state
            isDraggingAssistant = false
            if abs(value.translation.width) > 50 {
              if value.translation.width > 0 {
                // Dragged right
                assistantOrientation = .right
              } else {
                // Dragged left
                assistantOrientation = .left
              }
            }

            // Clear the dragged position
            draggedPosition = nil
          }
      )
      // Transparent resize handle overlaid so it does not consume width
      .overlay(alignment: assistantOrientation == .right ? .leading : .trailing) {
        ZStack(alignment: assistantOrientation == .right ? .leading : .trailing) {
          // Subtle edge shadow to separate from note area (under the handle)
          let edgeWidth: CGFloat = 3
          let startPoint: UnitPoint = assistantOrientation == .right ? .trailing : .leading
          let endPoint: UnitPoint = assistantOrientation == .right ? .leading : .trailing
          let noteBg = colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
            let shadowColor = colorScheme == .dark ? Color.matchabackground_light.opacity(0.18) : Color.matchabackground_dark.opacity(0.12)

          Rectangle()
            .fill(noteBg)
            .frame(width: edgeWidth)
            .allowsHitTesting(false)

          LinearGradient(
            colors: [shadowColor, shadowColor.opacity(0.0)],
            startPoint: startPoint,
            endPoint: endPoint
          )
          .frame(width: edgeWidth)
          .allowsHitTesting(false)
          resizeHandleOverlay(for: assistantOrientation)
        }
      }
      .background()
      .ignoresSafeArea(.all, edges: .bottom)
      .transition(assistantOrientation == .right ? .move(edge: .trailing) : .move(edge: .leading))
  }
}

// MARK: - Export / Share helpers in NoteView
extension NoteView {
  private var pageBounds: CGRect {
    CGRect(origin: .zero, size: PaperUtilities.paperSize(for: activeNote.paperSize))
  }

  // Resolve currently active note (from active tab) to align with toolbar
  private var activeNote: Note {
    tabManager.getActiveTab()?.note ?? note
  }

  private var totalPages: Int {
    let maxDrawingPage = activeNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let canvasPageCount = canvasManager.canvasViews.count
    return max(1, max(maxDrawingPage + 1, canvasPageCount))
  }

  private func drawingForPage(_ index: Int) -> PKDrawing? {
    if index < canvasManager.canvasViews.count {
      return canvasManager.canvasViews[index].drawing
    }
    if let data = activeNote.drawingDataByPage[String(index)], let drawing = try? PKDrawing(data: data) {
      return drawing
    }
    return nil
  }

  private func exportPDF(forPages pages: [Int]) -> URL? {
    // Use the centralized export manager instead of duplicating logic
    return ExportManager.shared.exportNoteAsPDF(activeNote, selectedPages: pages)
  }

  private func handleExport(pages: [Int]) {
    guard let url = exportPDF(forPages: pages) else { return }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = scene.windows.first(where: { $0.isKeyWindow }) {
        popover.sourceView = window
      }
    }
    topViewController()?.present(controller, animated: true)
  }

  private func handlePrint(pages: [Int]) {
    guard let url = exportPDF(forPages: pages) else { return }
    let controller = UIPrintInteractionController.shared
    controller.printingItem = url
    controller.present(animated: true, completionHandler: nil)
  }
  
  private func exportMatchaNote() -> URL? {
    do {
      // Create a JSON representation of the note
      let noteData = try JSONEncoder().encode(activeNote)
      
      // Create a temporary file with .matcha extension
      let sanitizedTitle = ExportManager.sanitizeTitle(activeNote.title)
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).matcha")
      
      try noteData.write(to: tempURL)
      return tempURL
    } catch {
      print("Failed to export Matcha note: \(error)")
      return nil
    }
  }
  
  private func handleExportMatcha() {
    guard let url = exportMatchaNote() else { return }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = scene.windows.first(where: { $0.isKeyWindow }) {
        popover.sourceView = window
      }
    }
    topViewController()?.present(controller, animated: true)
  }

  private func topViewController() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          var top = window.rootViewController else { return nil }
    while let presented = top.presentedViewController { top = presented }
    return top
  }
  
  // MARK: - Page Management Functions
  
  private func handleUpload(placement: PagePlacement) {
    // First add a page at the specified placement
    addPageCallback?(placement)

    // Small delay to ensure page is created before presenting picker
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.presentFilePicker()
    }
  }
  
  private func presentFilePicker() {
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
    documentPicker.delegate = DocumentPickerCoordinator.shared
    documentPicker.allowsMultipleSelection = false

    // Set callback for when file is picked
    DocumentPickerCoordinator.shared.onFilePicked = { url in
      self.processImportedFile(url: url)
    }

    // Present the document picker
    if let topViewController = topViewController() {
      topViewController.present(documentPicker, animated: true)
    }
  }
  
  private func processImportedFile(url: URL) {
    do {
      // Determine file type and handle accordingly
      let fileExtension = url.pathExtension.lowercased()

      switch fileExtension {
      case "pdf":
        try handlePDFImport(url: url)
      case "jpg", "jpeg", "png", "heic", "heif":
        try handleImageImport(url: url)
      default:
        print("Unsupported file type: \(fileExtension)")
      }
    } catch {
      print("Error processing imported file: \(error)")
    }
  }
  
  private func handlePDFImport(url: URL) throws {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }

    let pdfData = try Data(contentsOf: url)
    guard let pdfDocument = PDFDocument(data: pdfData) else {
      throw ImportError.invalidPDFFormat
    }

    let pageCount = pdfDocument.pageCount
    guard pageCount > 0 else {
      throw ImportError.emptyPDFDocument
    }

    // Process each page of the PDF
    for pageIndex in 0..<pageCount {
      guard let pdfPage = pdfDocument.page(at: pageIndex) else { continue }

      // Convert PDF page to image
      let pageImage = renderPDFPageToImage(pdfPage: pdfPage)

      if pageIndex == 0 {
        // Add first page image to the current (newly created) page
        addImageToCurrentPage(imageData: pageImage.pngData() ?? Data())
      } else {
        // Add subsequent pages as new pages
        addPageCallback?(.end)

        // Wait for page creation then add image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          // Navigate to the newly created page first
          self.currentPage = self.canvasManager.canvasViews.count - 1
          if let imageData = pageImage.pngData() {
            self.addImageToCurrentPage(imageData: imageData)
          }
        }
      }
    }

    print("PDF imported successfully: \(url.lastPathComponent) with \(pageCount) pages")
  }

  private func renderPDFPageToImage(pdfPage: PDFPage) -> UIImage {
    // Get the bounds of the PDF page and render to its native size
    let pageRect = pdfPage.bounds(for: .mediaBox)

    // Create the image context at the PDF page size
    let renderer = UIGraphicsImageRenderer(size: pageRect.size)
    let image = renderer.image { context in
      // Fill with white background
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: pageRect.size))

      // Map PDF page coordinates to the full image rect, accounting for coordinate flip
      context.cgContext.saveGState()
      context.cgContext.translateBy(x: 0, y: pageRect.size.height)
      context.cgContext.scaleBy(x: 1.0, y: -1.0)

      // Draw the PDF page (PDFKit handles page rotation internally for PDFPage)
      pdfPage.draw(with: .mediaBox, to: context.cgContext)
      context.cgContext.restoreGState()
    }

    return image
  }
  
  private func handleImageImport(url: URL) throws {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }

    let imageData = try Data(contentsOf: url)
    guard let image = UIImage(data: imageData) else {
      throw ImportError.invalidImageFormat
    }

    // Resize image if it's too large for the canvas
    let resizedImageData = resizeImageForCanvas(image: image)

    // Add image to current page (which was just created)
    addImageToCurrentPage(imageData: resizedImageData)
    print("Image imported successfully: \(url.lastPathComponent)")
  }

  private func resizeImageForCanvas(image: UIImage) -> Data {
    let paperSize = PaperUtilities.paperSize(for: activeNote.paperSize)
    let maxDimension = min(paperSize.width * 0.8, paperSize.height * 0.8) // 80% of paper size

    // Calculate new size maintaining aspect ratio
    let imageSize = image.size
    let scale = min(maxDimension / imageSize.width, maxDimension / imageSize.height, 1.0)

    if scale < 1.0 {
      let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
      let renderer = UIGraphicsImageRenderer(size: newSize)
      let resizedImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
      }
      return resizedImage.jpegData(compressionQuality: 0.8) ?? image.jpegData(compressionQuality: 0.8) ?? Data()
    } else {
      return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
  }
  
  private func handleTextImport(url: URL) throws {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }
    
    let textContent = try String(contentsOf: url, encoding: .utf8)
    
    // Add text content to note (this could be enhanced to create text annotations)
    print("Text imported successfully: \(url.lastPathComponent)")
    print("Content preview: \(String(textContent.prefix(100)))")
  }
  
  
  private func addImageToCurrentPage(imageData: Data) {
    guard let activeTab = tabManager.getActiveTab() else {
      return
    }

    // CRITICAL FIX: In-note uploads should create canvas overlay images, not background images
    // This is different from home page uploads which create background images

    // CRITICAL FIX: Use the same logic as home page uploads for consistency and reliability
    // Store uploaded images as background images in note.imageDataByPage

    var updatedNote = activeTab.note

    // Add image data to current page as background image (same as home page uploads)
    let pageKey = String(currentPage)
    if updatedNote.imageDataByPage[pageKey] == nil {
      updatedNote.imageDataByPage[pageKey] = []
    }
    updatedNote.imageDataByPage[pageKey]?.append(imageData)
    updatedNote.dateModified = Date()


    // Update storage and tab manager
    let savedNote = storageManager.saveNote(updatedNote)
    tabManager.updateNote(savedNote)


    // Force a UI refresh to show the new background image
    DispatchQueue.main.async {
      // The backgroundImagesView will automatically show the new image
      // since it reads directly from note.imageDataByPage
    }
  }
  
  
}

// MARK: - Document Picker Coordinator
class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
  static let shared = DocumentPickerCoordinator()
  var onFilePicked: ((URL) -> Void)?

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      return
    }
    onFilePicked?(url)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    // File picker was cancelled
  }
}

// MARK: - Import Errors
enum ImportError: Error {
  case accessDenied
  case invalidImageFormat
  case invalidPDFFormat
  case emptyPDFDocument
  case unsupportedFileType

  var localizedDescription: String {
    switch self {
    case .accessDenied:
      return "Access to file was denied"
    case .invalidImageFormat:
      return "Invalid image format"
    case .invalidPDFFormat:
      return "Invalid PDF format"
    case .emptyPDFDocument:
      return "PDF document contains no pages"
    case .unsupportedFileType:
      return "Unsupported file type"
    }
  }

}


