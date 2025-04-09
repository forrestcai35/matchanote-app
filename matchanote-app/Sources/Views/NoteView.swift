//
//  NoteView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import PencilKit
import SwiftUI
import matchanote_app

enum AssistantOrientation {
  case right, left
}

// DEFAULT NOTE VIEW CONTAINER
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
              WrittenNoteToolbar(isAssistantVisible: $isAssistantVisible)
            case .text:
              TextNoteToolbar(isAssistantVisible: $isAssistantVisible)
            case .markdown:
              MarkdownToolbar(isAssistantVisible: $isAssistantVisible)
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
        .edgesIgnoringSafeArea(.all)
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
    .navigationViewStyle(StackNavigationViewStyle())
  }

  // NOTES MAIN CONTENT VIEW
  @ViewBuilder
  private func mainContentView() -> some View {
    VStack {
      if let activeTab = tabManager.getActiveTab() {
        // Switch view based on note type

        switch activeTab.note.noteType {
        case .written:
          WrittenNoteView(note: activeTab.note, isEdited: $isEdited)
        case .text:
          TextNoteView(note: activeTab.note, isEdited: $isEdited)
        case .markdown:
          MarkdownNoteView(note: activeTab.note, isEdited: $isEdited)
        }
      } else if !tabManager.tabs.isEmpty {
        let firstTab = tabManager.tabs[0]
        // Switch view based on note type for fallback if we close a tab
        switch firstTab.note.noteType {
        case .written:
          WrittenNoteView(note: firstTab.note, isEdited: $isEdited)
        case .text:
          TextNoteView(note: firstTab.note, isEdited: $isEdited)
        case .markdown:
          MarkdownNoteView(note: firstTab.note, isEdited: $isEdited)
        }
      } else {
        // Show empty state when no tabs exist
        EmptyStateView()
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
      Color.black.opacity(0.05)
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

      // Direction arrow indicator
      Image(
        systemName: orientation == .right
          ? "arrow.right.circle.fill"
          : "arrow.left.circle.fill"
      )
      .resizable()
      .frame(width: 40, height: 40)
      .foregroundColor(.green)
      .position(dragLocation)
    }
  }

  // Extracted assistant panel view
  @ViewBuilder
  private func assistantPanelView() -> some View {
    // Horizontal layout (left/right)
    HStack(spacing: 0) {
      // Resize handle with visual indicator (flipped for left orientation)
      if assistantOrientation == .right {
        resizeHandleView()
      }

      AIAssistantView()
        .frame(width: assistantWidth)
        .contentShape(Rectangle())  // Make entire area draggable
        .gesture(
          DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged { value in
              // Update dragging state and position
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

              // Determine direction based on significant horizontal movement
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

  // Resizable handle view
  @ViewBuilder
  private func resizeHandleView() -> some View {
    ZStack {
      Rectangle()
        .fill(Color.gray.opacity(0.07))
        .frame(width: 6)

      // Grip indicator
      VStack(spacing: 6) {
        ForEach(0..<3) { _ in
          Circle()
            .fill(Color.gray.opacity(0.5))
            .frame(width: 5, height: 5)
        }
      }
    }
    .gesture(
      DragGesture()
        .onChanged { value in
          // Horizontal resizing (left/right)
          let newWidth =
            assistantOrientation == .left
            ? max(250, min(500, assistantWidth + value.translation.width))
            : max(250, min(500, assistantWidth - value.translation.width))
          assistantWidth = newWidth
        }
    )
  }
}

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  @State private var selectedColor: Color = .black
  @State private var lineWidth: CGFloat = 2
  @State private var showColorPicker: Bool = false
  @State private var showThicknessPicker: Bool = false

  // Simplified color selection
  private let colors: [Color] = [.black, .blue, .red]
  // Simplified thickness options
  private let lineWidths: [CGFloat] = [1, 3, 5]

  var body: some View {
    HStack {
      // Bookmark button
      Button(action: {
        // Bookmark functionality
      }) {
        Image(systemName: "bookmark")
          .foregroundColor(.gray)
      }

      //View Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(.gray)
      }
      Spacer()
      Button(action: {}) { Image(systemName: "arrow.uturn.backward") }
      Button(action: {}) { Image(systemName: "arrow.uturn.forward") }
      Divider()
        .frame(height: 20)

      Button(action: {}) { Image(systemName: "pencil.tip.crop.circle") }
      Button(action: {}) { Image(systemName: "eraser") }
      Button(action: {}) { Image(systemName: "highlighter") }
      Button(action: {}) { Image(systemName: "lasso") }
      Button(action: {}) { Image(systemName: "photo]") }
      Divider()
        .frame(height: 20)

      //Color picker
      ZStack(alignment: .topTrailing) {
        HStack(spacing: 12) {
          ForEach(colors, id: \.self) { color in
            ZStack {

              Circle()
                .fill(color == selectedColor ? Color.gray.opacity(0.2) : Color.clear)
                .frame(width: 28, height: 28)

              Circle()
                .fill(color)
                .frame(width: 20, height: 20)

              if color == selectedColor {
                ColorPicker("", selection: $selectedColor)
                  .labelsHidden()
                  .frame(width: 20, height: 20)
                  .scaleEffect(0.8)
              }
            }
            .onTapGesture {
              if color == selectedColor {
                showThicknessPicker = false
              } else {
                selectedColor = color
                showColorPicker = false
              }
            }
          }
        }

      }

      Divider()
        .frame(height: 20)

      // Thickness picker
      ZStack(alignment: .bottom) {
        HStack(spacing: 12) {
          ForEach(lineWidths, id: \.self) { width in
            ZStack {
              // Background for selected thickness
              RoundedRectangle(cornerRadius: 6)
                .fill(width == lineWidth ? Color.gray.opacity(0.2) : Color.clear)
                .frame(width: 28, height: 28)

              // Thickness indicator
              RoundedRectangle(cornerRadius: 2)
                .fill(Color.black)
                .frame(width: 20, height: width)

            }

          }
        }
      }
      Spacer()

      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
    .animation(.easeInOut(duration: 0.2), value: showColorPicker)
    .animation(.easeInOut(duration: 0.2), value: showThicknessPicker)
  }
}

// Toolbar for Text Notes
struct TextNoteToolbar: View {
  @Binding var isAssistantVisible: Bool

  var body: some View {
    HStack {

      // Bookmark button
      Button(action: {
        // Bookmark functionality
      }) {
        Image(systemName: "bookmark")
          .foregroundColor(.gray)
      }

      //View Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(.gray)
      }
      Spacer()
      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Spacer()
      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)

  }
}

// Toolbar for Text Notes
struct MarkdownToolbar: View {
  @Binding var isAssistantVisible: Bool

  var body: some View {
    HStack {

      Spacer()
      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Spacer()
      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)

  }
}

struct NoteView_Previews: PreviewProvider {
  static var previews: some View {
    NoteView(note: Note.samples[0])
    NoteView(note: Note.samples[1])
    NoteView(note: Note.samples[2])  // Text
  }
}
