import PencilKit
import SwiftUI
import matchanote_app

enum PenTool {
  case pen
  case lasso

  var toolInstance: PKTool {
    switch self {
    case .pen:
      return PKInkingTool(.pen)
    case .lasso:
      return PKLassoTool()
    }
  }
}

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  @Environment(\.colorScheme) private var colorScheme

  // Reference to the PKToolPicker visibility
  @Binding var toolPickerIsVisible: Bool

  // Added to reference canvas array and current page
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?

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
        // View functionality
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(.gray)
      }

      Spacer()
      // PLACE TOOLS HERE
      // Toggle ToolPicker visibility
      Button(action: {
        toolPickerIsVisible.toggle()
      }) {
        Image(systemName: "pencil.tip.crop.circle")
          .foregroundColor(toolPickerIsVisible ? .green : .gray)
      }

      // Lasso Tool
      Button(action: {
        if currentTool == .lasso {
          // If lasso is already selected, deselect it and revert to pen
          currentTool = .pen
          if currentPage < canvasViews.count {
            canvasViews[currentPage].tool = PenTool.pen.toolInstance
          }
        } else {
          // Select lasso tool
          currentTool = .lasso
          if currentPage < canvasViews.count {
            canvasViews[currentPage].tool = PenTool.lasso.toolInstance
          }
        }
      }) {
        Image(systemName: "lasso")
          .foregroundColor(currentTool == .lasso ? .green : .gray)
      }
      // Add text
      Button(action: {

      }) {
        Image(systemName: "character.textbox")
          .foregroundColor(.gray)
      }

      Spacer()
      Button(action: {
        // Add functionality
      }) {
        Image(systemName: "plus.circle")
          .foregroundColor(.gray)
      }
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
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
  }
}

// Toolbar for Text Notes
struct TextNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  @Environment(\.colorScheme) private var colorScheme

  // Add the properties for compatibility, even if not used in text mode
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?
  @Binding var toolPickerIsVisible: Bool

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
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))

  }
}
