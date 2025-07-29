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
  // Added for lasso tool functionality
  @State private var canvasViews: [PKCanvasView] = [PKCanvasView()]
  @State private var currentPage: Int = 0
  @State private var currentTool: PenTool? = nil

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

                canvasViews: $canvasViews,
                currentPage: $currentPage,
                currentTool: $currentTool)
            case .text:
              TextNoteToolbar(
                isAssistantVisible: $isAssistantVisible,
                canvasViews: $canvasViews,
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
      }
    }
    .navigationBarHidden(true)

  }

  // NOTES MAIN CONTENT VIEW
  @ViewBuilder
  private func mainContentView() -> some View {
    VStack {
      if let activeTab = tabManager.getActiveTab() {
        // Switch view based on note type

        switch activeTab.note.noteType {
        case .written:
          WrittenNoteView(
            note: activeTab.note,
            isEdited: $isEdited,
            toolPickerIsVisible: $toolPickerIsVisible,
            canvasViews: $canvasViews,
            currentPage: $currentPage,
            currentTool: $currentTool)
        case .text:
          TextNoteView(note: activeTab.note, isEdited: $isEdited)

        }
      } else if !tabManager.tabs.isEmpty {
        let firstTab = tabManager.tabs[0]
        // Switch view based on note type for fallback if we close a tab
        switch firstTab.note.noteType {
        case .written:
          WrittenNoteView(
            note: firstTab.note,
            isEdited: $isEdited,
            toolPickerIsVisible: $toolPickerIsVisible,
            canvasViews: $canvasViews,
            currentPage: $currentPage,
            currentTool: $currentTool)
        case .text:
          TextNoteView(note: firstTab.note, isEdited: $isEdited)

        }
      } else {

        EmptyStateView()
          .onAppear {
            toolPickerIsVisible = false
          }
      }
    }
    .background(Color.white)
  }

  // Orientation hover indicator
  @ViewBuilder
  private func orientationIndicator(for orientation: AssistantOrientation, in size: CGSize)
    -> some View
  {
    ZStack {
      // Semi-transparent overlay covering the whole screen
      Color.black.opacity(0.1)
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

  // Resizable handle view
  @ViewBuilder
  private func resizeHandleView() -> some View {
    ZStack {
      VStack(spacing: 8) {
        ForEach(0..<5) { _ in
          Capsule()
            .fill(Color.gray.opacity(0.5))
            .frame(width: 8, height: 2)
        }
      }
      Rectangle()
        .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.07))
        .frame(width: 10)

    }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          let newWidth =
            assistantOrientation == .left
            ? max(250, min(500, assistantWidth + value.translation.width))
            : max(250, min(500, assistantWidth - value.translation.width))
          assistantWidth = newWidth
        }
    )
    .highPriorityGesture(

      DragGesture(minimumDistance: 2)
        .onChanged { value in

          let newWidth =
            assistantOrientation == .left
            ? max(250, min(500, assistantWidth + value.translation.width))
            : max(250, min(500, assistantWidth - value.translation.width))
          assistantWidth = newWidth
        }
    )
  }

  // Extracted assistant panel view
  @ViewBuilder
  private func assistantPanelView() -> some View {
    // Horizontal layout (left/right)
    HStack(spacing: 0) {

      if assistantOrientation == .right {
        resizeHandleView()
      }

      AIAssistantView()
        .environmentObject(assistantState)
        .frame(width: assistantWidth)
        .contentShape(Rectangle())
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

      if assistantOrientation == .left {
        resizeHandleView()
      }
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
