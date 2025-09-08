//
//  NoteView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import PencilKit
import SwiftUI
import UIKit

enum AssistantOrientation {
  case right, left
}

// Canvas manager to track canvas views per note
class CanvasManager: ObservableObject {
  @Published var canvasViews: [PKCanvasView] = []
  
  init() {
    // Initialize with a single canvas
    let initialCanvas = PKCanvasView()
    initialCanvas.overrideUserInterfaceStyle = .light
    initialCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
    canvasViews = [initialCanvas]
  }
}

struct NoteView: View {
  var note: Note
  @Environment(\.dismiss) var dismiss
  @State public var isAssistantVisible = false
  @State private var assistantWidth: CGFloat = 300
  @State private var assistantHeight: CGFloat = 300
  @State private var assistantOrientation: AssistantOrientation = .right
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
            exportCurrentPageAction: { handleExport(pages: [currentPage]) },
            exportAllPagesAction: { handleExport(pages: Array(0..<totalPages)) },
            printCurrentPageAction: { handlePrint(pages: [currentPage]) },
            printAllPagesAction: { handlePrint(pages: Array(0..<totalPages)) }
          )

          if let activeTab = tabManager.getActiveTab() {
            // Showcase Contextual Toolbars
            switch activeTab.note.noteType {
            case .written:
              WrittenNoteToolbar(
                isAssistantVisible: $isAssistantVisible,
                note: activeTab.note,
                canvasViews: $canvasManager.canvasViews,
                currentPage: $currentPage,
                currentTool: $currentTool)
            case .text:
              TextNoteToolbar(
                isAssistantVisible: $isAssistantVisible,
                note: activeTab.note,
                canvasViews: $canvasManager.canvasViews,
                currentPage: $currentPage,
                currentTool: $currentTool)

            }
            Divider()
          } else if !tabManager.tabs.isEmpty {
            // Edge case for handling active tab + no tabs open
            Text("Error: No active tab found")
              .foregroundColor(.red)
          }

          // AI ASSISTANT PANEL
          HStack(spacing: 0) {
            // Left-side assistant
            if isAssistantVisible && assistantOrientation == .left {
              assistantPanelView()
                .transition(.move(edge: .leading).combined(with: .opacity))
                .animation(.spring(), value: isAssistantVisible)
                .animation(.spring(), value: assistantOrientation)
            }

            // Main content
            mainContentView()


            // Right-side assistant
            if isAssistantVisible && assistantOrientation == .right {
              assistantPanelView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(), value: isAssistantVisible)
                .animation(.spring(), value: assistantOrientation)
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
        openNoteInTab()
        cleanupOrphanedTabs()
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

  // NOTES MAIN CONTENT VIEW
  @ViewBuilder
  private func mainContentView() -> some View {
    VStack {
      if let activeTab = tabManager.getActiveTab() {
        // Check if the note still exists in storage
        if storageManager.notes.contains(where: { $0.id == activeTab.note.id }) {
          // Switch view based on note type
          switch activeTab.note.noteType {
          case .written:
            WrittenNoteView(
              note: activeTab.note,
              isEdited: $isEdited,
              toolPickerIsVisible: $toolPickerIsVisible,
              canvasViews: $canvasManager.canvasViews,
              currentPage: $currentPage,
              currentTool: $currentTool)
          case .text:
            TextNoteView(note: activeTab.note, isEdited: $isEdited)
          }
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
          // Switch view based on note type for fallback if we close a tab
          switch firstTab.note.noteType {
          case .written:
            WrittenNoteView(
              note: firstTab.note,
              isEdited: $isEdited,
              toolPickerIsVisible: $toolPickerIsVisible,
              canvasViews: $canvasManager.canvasViews,
              currentPage: $currentPage,
              currentTool: $currentTool)
          case .text:
            TextNoteView(note: firstTab.note, isEdited: $isEdited)
          }
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
        EmptyStateView()
          .onAppear {
            toolPickerIsVisible = false
          }
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

      // Position indicator
      Group {
        switch orientation {
        case .right:
          Rectangle()
            .fill(Color.green.opacity(0.2))
            .frame(width: assistantWidth, height: size.height)
            .overlay(
              Rectangle()
                .strokeBorder(Color.green.opacity(0.5), lineWidth: 2)
            )
            .position(x: size.width - assistantWidth / 2, y: size.height / 2)
        case .left:
          Rectangle()
            .fill(Color.green.opacity(0.2))
            .frame(width: assistantWidth, height: size.height)
            .overlay(
              Rectangle()
                .strokeBorder(Color.green.opacity(0.5), lineWidth: 2)
            )
            .position(x: assistantWidth / 2, y: size.height / 2)
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
    // Horizontal layout (left/right)
    HStack(spacing: 0) {

      AIAssistantView()
        .environmentObject(assistantState)
        .frame(width: assistantWidth)
        .contentShape(Rectangle())
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
            let edgeWidth: CGFloat = 5
            let startPoint: UnitPoint = assistantOrientation == .right ? .trailing : .leading
            let endPoint: UnitPoint = assistantOrientation == .right ? .leading : .trailing
            let noteBg = colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
            let shadowColor = colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)

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
    }
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
    let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
    let sanitizedTitle = activeNote.title.replacingOccurrences(of: "/", with: "-")
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Note_Export_\(sanitizedTitle)_\(UUID().uuidString).pdf")
    do {
      try renderer.writePDF(to: tempURL) { context in
        for page in pages {
          context.beginPage()
          UIColor(PaperUtilities.getPaperBackgroundColor(for: activeNote.paperColor)).setFill()
          UIRectFill(pageBounds)
          if let drawing = drawingForPage(page) {
            let image = drawing.image(from: pageBounds, scale: 2)
            image.draw(in: pageBounds)
          }
        }
      }
      return tempURL
    } catch {
      print("Failed to write PDF: \(error)")
      return nil
    }
  }

  private func handleExport(pages: [Int]) {
    guard let url = exportPDF(forPages: pages) else { return }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      // iPad support: anchor to the key window
      popover.sourceView = UIApplication.shared.windows.first { $0.isKeyWindow }
    }
    topViewController()?.present(controller, animated: true)
  }

  private func handlePrint(pages: [Int]) {
    guard let url = exportPDF(forPages: pages) else { return }
    let controller = UIPrintInteractionController.shared
    controller.printingItem = url
    controller.present(animated: true, completionHandler: nil)
  }

  private func topViewController() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          var top = window.rootViewController else { return nil }
    while let presented = top.presentedViewController { top = presented }
    return top
  }
}


