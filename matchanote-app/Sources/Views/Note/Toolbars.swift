import PencilKit
import SwiftUI

enum PenTool {
  case pen
  case marker
  case eraser
  case lasso

  func toolInstance(color: Color = .black, width: CGFloat = 1.0, eraserType: EraserType = .object) -> PKTool {
    switch self {
    case .pen:
      return PKInkingTool(.pen, color: UIColor(color), width: width)
    case .marker:
      return PKInkingTool(.marker, color: UIColor(color), width: width)
    case .eraser:
      return eraserType == .object ? PKEraserTool(.vector) : PKEraserTool(.bitmap)
    case .lasso:
      return PKLassoTool()
    }
  }
}

enum EraserType: CaseIterable {
  case object
  case area
  
  var displayName: String {
    switch self {
    case .object: return "Object"
    case .area: return "Area"
    }
  }
  
  var icon: String {
    switch self {
    case .object: return "eraser.line.dashed"
    case .area: return "eraser.fill"
    }
  }
}

enum ToolWidth: CGFloat, CaseIterable {
  case thin = 1.0
  case medium = 3.0
  case thick = 6.0
  
  var displayName: String {
    switch self {
    case .thin: return "Thin"
    case .medium: return "Medium" 
    case .thick: return "Thick"
    }
  }
  
  var visualSize: CGFloat {
    switch self {
    case .thin: return 4.0
    case .medium: return 8.0
    case .thick: return 12.0
    }
  }
}

// Tool state management
class ToolState: ObservableObject {
  @Published var penColor: Color = .black
  @Published var penWidth: ToolWidth = .medium
  @Published var markerColor: Color = .yellow
  @Published var markerWidth: ToolWidth = .medium
  @Published var eraserWidth: ToolWidth = .medium
  @Published var eraserType: EraserType = .object
}

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var toolState = ToolState()

  // Added to reference canvas array and current page
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?

  // Color palettes
  private let penColors: [Color] = [
    .black, .blue, .red, .green, .purple, .orange, .brown, .pink,
    .matchalight_dark, .matchadark_light
  ]
  
  private let markerColors: [Color] = [
    .yellow, .pink, .green, .blue, .orange, .purple, .red, .cyan,
    .matchalight_light, .matchadark_dark
  ]

  var body: some View {
    VStack(spacing: 0) {
      // Main toolbar
      HStack {
        // Left side buttons
        Button(action: {
          // Bookmark functionality
        }) {
          Image(systemName: "bookmark")
            .foregroundColor(.gray)
        }

        Button(action: {
          // View functionality
        }) {
          Image(systemName: "square.grid.2x2")
            .foregroundColor(.gray)
        }

        Spacer()
        
        // Tool buttons
        toolButtons
        
        Spacer()
        
        // Right side buttons
        Button(action: {
          // Add functionality
        }) {
          Image(systemName: "plus.circle")
            .foregroundColor(.gray)
        }
        
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
      
      // Expandable customization area
      if let tool = currentTool {
        customizationArea(for: tool)
      }
    }
    .buttonStyle(PlainButtonStyle())
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
  }
  
  @ViewBuilder
  private var toolButtons: some View {
    HStack(spacing: 16) {
      // Pen Tool
      Button(action: {
        selectTool(.pen)
      }) {
        Image(systemName: "pencil")
          .foregroundColor(currentTool == .pen ? .matchalight_dark : .gray)
      }
      
      // Marker Tool
      Button(action: {
        selectTool(.marker)
      }) {
        Image(systemName: "highlighter")
          .foregroundColor(currentTool == .marker ? .matchalight_dark : .gray)
      }
      
      // Eraser Tool
      Button(action: {
        selectTool(.eraser)
      }) {
        Image(systemName: "eraser")
          .foregroundColor(currentTool == .eraser ? .matchalight_dark : .gray)
      }

      // Lasso Tool
      Button(action: {
        if currentTool == .lasso {
          selectTool(.pen)
        } else {
          selectTool(.lasso)
        }
      }) {
        Image(systemName: "lasso")
          .foregroundColor(currentTool == .lasso ? .matchalight_dark : .gray)
      }
      
      // Add text
      Button(action: {
        // Text functionality
      }) {
        Image(systemName: "character.textbox")
          .foregroundColor(.gray)
      }
    }
  }
  
  @ViewBuilder
  private func customizationArea(for tool: PenTool) -> some View {
    VStack(spacing: 8) {
      switch tool {
      case .pen:
        penCustomization
      case .marker:
        markerCustomization
      case .eraser:
        eraserCustomization
      case .lasso:
        EmptyView() // No customization for lasso
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
  }
  
  @ViewBuilder
  private var penCustomization: some View {
    VStack(spacing: 8) {
      // Color palette
      HStack(spacing: 8) {
        Text("Color:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(penColors, id: \.self) { color in
              colorSwatch(color: color, isSelected: toolState.penColor == color) {
                toolState.penColor = color
                updateCanvasTool()
              }
            }
          }
          .padding(.horizontal, 4)
        }
      }
      
      // Width selector
      HStack(spacing: 8) {
        Text("Width:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack(spacing: 12) {
          ForEach(ToolWidth.allCases, id: \.self) { width in
            widthSelector(width: width, isSelected: toolState.penWidth == width) {
              toolState.penWidth = width
              updateCanvasTool()
            }
          }
        }
        
        Spacer()
      }
    }
  }
  
  @ViewBuilder
  private var markerCustomization: some View {
    VStack(spacing: 8) {
      // Color palette
      HStack(spacing: 8) {
        Text("Color:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(markerColors, id: \.self) { color in
              colorSwatch(color: color, isSelected: toolState.markerColor == color) {
                toolState.markerColor = color
                updateCanvasTool()
              }
            }
          }
          .padding(.horizontal, 4)
        }
      }
      
      // Width selector
      HStack(spacing: 8) {
        Text("Width:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack(spacing: 12) {
          ForEach(ToolWidth.allCases, id: \.self) { width in
            widthSelector(width: width, isSelected: toolState.markerWidth == width) {
              toolState.markerWidth = width
              updateCanvasTool()
            }
          }
        }
        
        Spacer()
      }
    }
  }
  
  @ViewBuilder
  private var eraserCustomization: some View {
    VStack(spacing: 8) {
      // Eraser type selector
      HStack(spacing: 8) {
        Text("Type:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack(spacing: 12) {
          ForEach(EraserType.allCases, id: \.self) { type in
            Button(action: {
              toolState.eraserType = type
              updateCanvasTool()
            }) {
              HStack(spacing: 4) {
                Image(systemName: type.icon)
                  .font(.caption)
                Text(type.displayName)
                  .font(.caption)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                toolState.eraserType == type 
                  ? Color.matchalight_dark.opacity(0.3)
                  : Color.clear
              )
              .cornerRadius(6)
            }
            .foregroundColor(
              toolState.eraserType == type 
                ? .matchalight_dark 
                : .secondary
            )
          }
        }
        
        Spacer()
      }
      
      // Width selector (for area eraser)
      if toolState.eraserType == .area {
        HStack(spacing: 8) {
          Text("Size:")
            .font(.caption)
            .foregroundColor(.secondary)
          
          HStack(spacing: 12) {
            ForEach(ToolWidth.allCases, id: \.self) { width in
              widthSelector(width: width, isSelected: toolState.eraserWidth == width) {
                toolState.eraserWidth = width
                updateCanvasTool()
              }
            }
          }
          
          Spacer()
        }
      }
    }
  }
  
  @ViewBuilder
  private func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Circle()
        .fill(color)
        .frame(width: 24, height: 24)
        .overlay(
          Circle()
            .stroke(
              isSelected ? Color.matchalight_dark : Color.clear,
              lineWidth: 2
            )
        )
        .overlay(
          // Special indicator for white/light colors
          color == .white || color == .matchalight_light || color == .matchadark_dark ?
          Circle()
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          : nil
        )
    }
  }
  
  @ViewBuilder
  private func widthSelector(width: ToolWidth, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Circle()
        .fill(isSelected ? Color.matchalight_dark : Color.gray.opacity(0.5))
        .frame(width: width.visualSize, height: width.visualSize)
    }
  }
  
  private func selectTool(_ tool: PenTool) {
    currentTool = tool
    updateCanvasTool()
  }
  
  private func updateCanvasTool() {
    guard currentPage < canvasViews.count, let tool = currentTool else { return }
    
    let canvas = canvasViews[currentPage]
    
    switch tool {
    case .pen:
      canvas.tool = tool.toolInstance(color: toolState.penColor, width: toolState.penWidth.rawValue)
    case .marker:
      canvas.tool = tool.toolInstance(color: toolState.markerColor, width: toolState.markerWidth.rawValue)
    case .eraser:
      canvas.tool = tool.toolInstance(eraserType: toolState.eraserType)
    case .lasso:
      canvas.tool = tool.toolInstance()
    }
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
