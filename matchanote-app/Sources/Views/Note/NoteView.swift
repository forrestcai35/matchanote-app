

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
  @State private var pendingUploadPlacement: PagePlacement? = nil
  @ObservedObject private var tabManager = TabManager.shared
  @State private var isEdited = false
  @State private var toolPickerIsVisible = false
  @StateObject private var assistantState = AIAssistantState()
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager
  @AppStorage("preferences.noteEditor.statusBarHidden") private var noteEditorStatusBarHidden: Bool = false
  // Added for lasso tool functionality - now managed per note
  @State private var canvasManager = CanvasManager()
  @State private var currentPage: Int = 0
  @State private var currentTool: PenTool? = .pen
  @StateObject private var textBoxManager = TextBoxManager()
  // Shape recognition removed

  // Expose add page functionality
  @State private var addPageCallback: ((PagePlacement) -> Void)?
  @State private var deletePageCallback: ((Int) -> Void)?
  @State private var writtenNoteView: WrittenNoteView?
  @State private var showExportOptionsView: Bool = false

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
  
  // Save current canvas data to storage
  private func saveCurrentCanvasData() {
    print("🎨 saveCurrentCanvasData() called!")
    
    guard let activeTab = tabManager.getActiveTab() else { 
      print("❌ No active tab found!")
      return 
    }
    
    var updatedNote = activeTab.note
    print("📝 Saving canvas data for note: \(updatedNote.title)")
    print("🖼️ Canvas count: \(canvasManager.canvasViews.count)")
    
    // Collect drawing data from all canvases
    var drawingData: [String: Data] = [:]
    for (index, canvas) in canvasManager.canvasViews.enumerated() {
      let data = canvas.drawing.dataRepresentation()
      drawingData[String(index)] = data
      print("  📄 Page \(index): \(data.count) bytes")
    }
    updatedNote.drawingDataByPage = drawingData
    
    // Collect image data (canvas images)
    let canvasImageData = canvasManager.imageManager.getAllImagesData()
    // Merge with existing background images
    var finalImageData = updatedNote.imageDataByPage
    for (pageKey, images) in canvasImageData {
      if finalImageData[pageKey] == nil {
        finalImageData[pageKey] = []
      }
      finalImageData[pageKey]?.append(contentsOf: images)
    }
    updatedNote.imageDataByPage = finalImageData
    
    // Collect textbox data
    updatedNote.textBoxDataByPage = textBoxManager.getAllTextBoxesData()

    // Save current page position
    updatedNote.currentPage = currentPage

    updatedNote.dateModified = Date()

    // Save to storage
    print("💾 Calling storageManager.saveNote()...")
    let savedNote = storageManager.saveNote(updatedNote)
    tabManager.updateNote(savedNote)
    print("✅ Canvas data saved successfully!")
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
            quickExportAction: { handleQuickExport() },
            exportOptionsAction: { showExportOptionsView = true },
            printCurrentPageAction: { handlePrint(pages: [currentPage]) },
            printAllPagesAction: { handlePrint(pages: Array(0..<totalPages)) },
            onAddPage: { placement in
              addPageCallback?(placement)
            },
            onUpload: { placement in
              handleUpload(placement: placement)
            },
            onTabSwitch: {
              saveCurrentCanvasData()
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
        .ignoresSafeArea(.all, edges: noteEditorStatusBarHidden ? .top : [])


        // Hover indicator overlay
        if isDraggingAssistant, let hoveredPosition = draggedPosition {
          orientationIndicator(
            for: hoveredPosition,
            in: CGSize(width: geometry.size.width, height: geometry.size.height)
          )
        }
        
        // Chat history dropdown overlay (above all other overlays)
        if assistantState.showingChatHistory && isAssistantVisible {
          ZStack {
            // Backdrop
            Color.black.opacity(0.3)
              .edgesIgnoringSafeArea(.all)
              .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                  assistantState.showingChatHistory = false
                }
              }
            
            // Dropdown positioned at assistant side
            VStack {
              HStack {
                if assistantOrientation == .left {
                  ChatHistoryDropdown(assistantState: assistantState, chatStorage: assistantState.chatStorage)
                    .padding(.top, 16)
                    .padding(.leading, 16)
                  Spacer()
                } else {
                  Spacer()
                  ChatHistoryDropdown(assistantState: assistantState, chatStorage: assistantState.chatStorage)
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
              }
              Spacer()
            }
          }
          .transition(.opacity)
        }
      }
      .statusBar(hidden: noteEditorStatusBarHidden)
      .sheet(isPresented: $showExportOptionsView) {
        ExportOptionsView(
          note: activeNote,
          totalPages: totalPages,
          onExport: { exportType, pages in
            handleExportWithType(exportType: exportType, pages: pages)
          }
        )
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
        // Save current canvas data before disappearing
        saveCurrentCanvasData()

        // Clean up the callback
        tabManager.onAllTabsClosed = nil

        // Remove app lifecycle observers
        removeAppLifecycleObservers()
      }
      .onChange(of: tabManager.getActiveTab()?.note.id) { _, newNoteId in
        // When switching tabs, restore the current page for the new note
        if let activeTab = tabManager.getActiveTab() {
          let savedPage = activeTab.note.currentPage
          let pageCount = max(1, activeTab.note.drawingDataByPage.keys.compactMap { Int($0) }.max().map { $0 + 1 } ?? 1)
          // Ensure the saved page is within valid bounds
          currentPage = min(max(0, savedPage), pageCount - 1)
        }
      }
      .onChange(of: currentPage) { oldPage, newPage in
        // Save immediately when page changes so it persists even if app is force-closed
        guard let activeTab = tabManager.getActiveTab() else { return }

        // Skip save if currentPage in storage already matches (prevents conflicting saves during page add/delete)
        if activeTab.note.currentPage == newPage {
          return
        }

        var updatedNote = activeTab.note
        updatedNote.currentPage = newPage
        updatedNote.dateModified = Date()
        let savedNote = storageManager.saveNote(updatedNote)
        tabManager.updateNote(savedNote)
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
      // Save current canvas data when app becomes inactive
      self.saveCurrentCanvasData()
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { _ in
      // Save current canvas data when app enters background
      self.saveCurrentCanvasData()
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
    let hitWidth: CGFloat = 32
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
    AIAssistantView(assistantOrientation: assistantOrientation)
      .environmentObject(assistantState)
      .frame(width: assistantWidth)
      .contentShape(Rectangle())
      .onAppear {
        if let activeTab = tabManager.getActiveTab() {
          // Set current note for AI assistant
          assistantState.currentNote = activeTab.note
          print("🤖 AI Assistant: Set current note to '\(activeTab.note.title)'")
        }
        
        // Connect callback to save canvas data before AI analysis
        print("🔗 Connecting saveCanvasDataCallback for AI analysis...")
        assistantState.saveCanvasDataCallback = {
          print("📞 AI Analysis: saveCanvasDataCallback triggered!")
          self.saveCurrentCanvasData()
        }
        print("✅ AI Assistant callback connected")
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

  private func handleQuickExport() {
    // Quick export exports all pages as PDF
    saveCurrentCanvasData()
    
    guard let latestNote = storageManager.notes.first(where: { $0.id == activeNote.id }) else {
      print("Could not find note to export")
      return
    }
    
    guard let url = ExportManager.shared.exportNoteAsPDF(latestNote, selectedPages: nil) else {
      print("Failed to create PDF")
      return
    }
    
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = scene.windows.first(where: { $0.isKeyWindow }) {
        popover.sourceView = window
      }
    }
    topViewController()?.present(controller, animated: true)
  }
  
  private func handleExportWithType(exportType: ExportType, pages: [Int]) {
    // Save current canvas data to the note before exporting
    saveCurrentCanvasData()
    
    // Get the updated note from storage (it should have the latest data now)
    guard let latestNote = storageManager.notes.first(where: { $0.id == activeNote.id }) else {
      print("Could not find note to export")
      return
    }
    
    guard let url = ExportManager.shared.exportNote(latestNote, selectedPages: pages, exportType: exportType) else {
      print("Failed to create export file")
      return
    }
    
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
    // Save current canvas data before printing
    saveCurrentCanvasData()
    
    // Get the updated note from storage
    guard let latestNote = storageManager.notes.first(where: { $0.id == activeNote.id }) else {
      print("Could not find note to print")
      return
    }
    
    guard let url = ExportManager.shared.exportNoteAsPDF(latestNote, selectedPages: pages) else {
      print("Failed to create PDF for printing")
      return
    }
    
    let controller = UIPrintInteractionController.shared
    controller.printingItem = url
    controller.present(animated: true, completionHandler: nil)
  }
  
  private func exportMatchaNote(note: Note) -> URL? {
    do {
      // Create a JSON representation of the note
      let noteData = try JSONEncoder().encode(note)
      
      // Create a temporary file with .matcha extension
      let sanitizedTitle = ExportManager.sanitizeTitle(note.title)
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).matcha")
      
      try noteData.write(to: tempURL)
      return tempURL
    } catch {
      print("Failed to export Matcha note: \(error)")
      return nil
    }
  }
  
  private func handleExportMatcha() {
    // Save current canvas data before exporting
    saveCurrentCanvasData()
    
    // Get the updated note from storage
    guard let latestNote = storageManager.notes.first(where: { $0.id == activeNote.id }) else {
      print("Could not find note to export as .matcha")
      return
    }
    
    guard let url = exportMatchaNote(note: latestNote) else {
      print("Failed to create .matcha file")
      return
    }
    
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
    // Store the placement for use after file selection
    self.pendingUploadPlacement = placement
    
    // Present file picker directly - page will be added after file selection
    presentFilePicker()
  }
  
  private func presentFilePicker() {
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .matchaNote], asCopy: true)
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
    // Use ImportManager to create a note for import into current note
    ImportManager.shared.createNoteForImportIntoCurrent(
      url: url,
      storageManager: storageManager
    ) { importedNote in
      guard let importedNote = importedNote else {
        print("Failed to import file: \(url.lastPathComponent)")
        return
      }
      
      // Process the imported note content into the current note
      self.addImportedContentToCurrentNote(importedNote: importedNote)
    }
  }
  
  // MARK: - Import Content Integration
  
  private func addImportedContentToCurrentNote(importedNote: Note) {
    guard tabManager.getActiveTab() != nil else {
      print("No active tab found for importing content")
      return
    }
    
    // Get the placement for this upload
    let placement = pendingUploadPlacement ?? .after
    pendingUploadPlacement = nil // Clear the pending placement
    
    // Get the list of pages from the imported note (check all possible page data sources)
    let imagePages = importedNote.imageDataByPage.keys.compactMap { Int($0) }
    let drawingPages = importedNote.drawingDataByPage.keys.compactMap { Int($0) }
    let textBoxPages = importedNote.textBoxDataByPage.keys.compactMap { Int($0) }
    let allPageNumbers = Set(imagePages + drawingPages + textBoxPages)
    let importedPages = Array(allPageNumbers).sorted()
    

    
    if importedPages.isEmpty {
      // If no pages in the imported note, add a page at the specified placement first
      addPageCallback?(placement)
      
      // Small delay to ensure page is created, then add content
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // Get fresh note from tab manager after page creation
        guard let freshTab = self.tabManager.getActiveTab() else { return }
        var updatedNote = freshTab.note
        let targetPageKey = String(self.currentPage)
        
        
        // Add any images from the imported note's first page
        if let imageData = importedNote.imageDataByPage["0"] {

          if updatedNote.imageDataByPage[targetPageKey] == nil {
            updatedNote.imageDataByPage[targetPageKey] = []
          }
          updatedNote.imageDataByPage[targetPageKey]?.append(contentsOf: imageData)
        }
        
        // Add any drawing data
        if let drawingData = importedNote.drawingDataByPage["0"] {
          updatedNote.drawingDataByPage[targetPageKey] = drawingData
        }
        
        // Add any text box data
        if let textBoxData = importedNote.textBoxDataByPage["0"] {
          if updatedNote.textBoxDataByPage[targetPageKey] == nil {
            updatedNote.textBoxDataByPage[targetPageKey] = []
          }
          updatedNote.textBoxDataByPage[targetPageKey]?.append(contentsOf: textBoxData)
        }
        
        // Update the note
        updatedNote.dateModified = Date()
        let savedNote = self.storageManager.saveNote(updatedNote)
        self.tabManager.updateNote(savedNote)
        
        // Refresh canvas views to load the new drawing data (async to avoid state modification during view update)
        DispatchQueue.main.async {
          self.refreshCanvasViews()
        }
        
      }
    } else {
      // Import each page from the imported note
      for (index, pageIndex) in importedPages.enumerated() {
        let pageKey = String(pageIndex)
        
        if index == 0 {
          // Add first page at the specified placement
          addPageCallback?(placement)
          
          // Small delay to ensure page is created, then add content
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Get fresh note from tab manager after page creation
            guard let freshTab = self.tabManager.getActiveTab() else { return }
            var updatedNote = freshTab.note
            let targetPageKey = String(self.currentPage)
            
          
          // Merge drawing if exists
          if let drawingData = importedNote.drawingDataByPage[pageKey] {
              updatedNote.drawingDataByPage[targetPageKey] = drawingData
          }
          
          // Merge images if exist
          if let imageData = importedNote.imageDataByPage[pageKey] {
              if updatedNote.imageDataByPage[targetPageKey] == nil {
                updatedNote.imageDataByPage[targetPageKey] = []
            }
              updatedNote.imageDataByPage[targetPageKey]?.append(contentsOf: imageData)
          }
          
          // Merge text boxes if exist
          if let textBoxData = importedNote.textBoxDataByPage[pageKey] {
              if updatedNote.textBoxDataByPage[targetPageKey] == nil {
                updatedNote.textBoxDataByPage[targetPageKey] = []
              }
              updatedNote.textBoxDataByPage[targetPageKey]?.append(contentsOf: textBoxData)
            }
            
            // Update the note
            updatedNote.dateModified = Date()
            let savedNote = self.storageManager.saveNote(updatedNote)
            self.tabManager.updateNote(savedNote)
            
            // Refresh canvas views to load the new drawing data (async to avoid state modification during view update)
            DispatchQueue.main.async {
              self.refreshCanvasViews()
            }
          }
        } else {
          // Add subsequent pages as new pages at the end
          addPageCallback?(.end)
          
          // Wait for page creation then add content
          let delay = 0.2 * Double(index)
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Get fresh note from tab manager after page creation
            guard let freshTab = self.tabManager.getActiveTab() else { return }
            var currentNote = freshTab.note
            let newPageIndex = self.canvasManager.canvasViews.count - 1
            let newPageKey = String(newPageIndex)
            
            // Add drawing
            if let drawingData = importedNote.drawingDataByPage[pageKey] {
              currentNote.drawingDataByPage[newPageKey] = drawingData
            }
            
            // Add images
            if let imageData = importedNote.imageDataByPage[pageKey] {
              currentNote.imageDataByPage[newPageKey] = imageData
            }
            
            // Add text boxes
            if let textBoxData = importedNote.textBoxDataByPage[pageKey] {
              currentNote.textBoxDataByPage[newPageKey] = textBoxData
            }
            
            currentNote.dateModified = Date()
            let savedNote = self.storageManager.saveNote(currentNote)
            self.tabManager.updateNote(savedNote)
            
            // Refresh canvas views to load the new drawing data (async to avoid state modification during view update)
            DispatchQueue.main.async {
              self.refreshCanvasViews()
            }
          }
        }
      }
      
    }
  }
  
  // MARK: - Canvas Refresh Helper
  
  private func refreshCanvasViews() {
    guard let activeTab = tabManager.getActiveTab() else { return }
    
    // Get the current note with the latest data
    let currentNote = activeTab.note
    
    // Calculate required page count based on note data
    let maxDrawingPage = currentNote.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let maxImagePage = currentNote.imageDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let requiredPageCount = max(1, max(maxDrawingPage, maxImagePage) + 1)
    
    // Ensure we have enough canvas views
    while canvasManager.canvasViews.count < requiredPageCount {
      let canvas = PKCanvasView()
      canvas.overrideUserInterfaceStyle = .light
      canvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
      canvasManager.canvasViews.append(canvas)
    }
    
    // Load drawing data into existing canvas views
    for pageIndex in 0..<min(requiredPageCount, canvasManager.canvasViews.count) {
      let canvas = canvasManager.canvasViews[pageIndex]
      
      if let drawingData = currentNote.drawingDataByPage[String(pageIndex)] {
        do {
          let drawing = try PKDrawing(data: drawingData)
          canvas.drawing = drawing
        } catch {
          print("Error loading drawing for page \(pageIndex): \(error)")
        }
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


}
}