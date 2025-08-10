//
//  NoteView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import PencilKit
import SwiftUI

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

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack(spacing: 0) {
          // Tab bar
          TabBarView(dismiss: dismiss)

          if let activeTab = tabManager.getActiveTab() {
            // Showcase Contextual Toolbars
            switch activeTab.note.noteType {
            case .written:
              WrittenNoteToolbar(
                isAssistantVisible: $isAssistantVisible,

                canvasViews: $canvasManager.canvasViews,
                currentPage: $currentPage,
                currentTool: $currentTool)
            case .text:
              TextNoteToolbar(
                isAssistantVisible: $isAssistantVisible,
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
            }

            // Main content
            mainContentView()
              .frame(maxWidth: .infinity)

            // Right-side assistant
            if isAssistantVisible && assistantOrientation == .right {
              assistantPanelView()
            }
          }
          .animation(.spring(), value: isAssistantVisible)
          .animation(.spring(), value: assistantOrientation)
        }
        .edgesIgnoringSafeArea(.bottom)
        .edgesIgnoringSafeArea(.leading)
        .edgesIgnoringSafeArea(.trailing)
        .frame(width: geometry.size.width, height: geometry.size.height)

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

            // Background strip matching the note area to create a seamless overlap
            Rectangle()
              .fill(noteBg)
              .frame(width: edgeWidth)
              .allowsHitTesting(false)

            LinearGradient(
              colors: [Color.black.opacity(0.12), Color.black.opacity(0.0)],
              startPoint: startPoint,
              endPoint: endPoint
            )
            .frame(width: edgeWidth)
            .allowsHitTesting(false)

            // Clear, wide hit-target for resizing
            resizeHandleOverlay(for: assistantOrientation)
          }
        }
        .background()
    }
    .transition(assistantOrientation == .right ? .move(edge: .trailing) : .move(edge: .leading))
  }
}

struct NoteView_Previews: PreviewProvider {
  static var previews: some View {
    NoteView(note: Note.samples[0])
    NoteView(note: Note.samples[1])
    NoteView(note: Note.samples[2])
  }
}

