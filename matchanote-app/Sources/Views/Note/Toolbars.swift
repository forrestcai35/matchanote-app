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
    case .thin: return 6.0
    case .medium: return 10.0
    case .thick: return 14.0
    }
  }
}

// Tool state management
class ToolState: ObservableObject {
  @Published var penColor: Color = .black
  @Published var markerColor: Color = .yellow

  // Dynamic palettes
  @Published var penPalette: [Color] = [.black, .blue, .red, .green, .purple, .orange, .brown, .pink]
  @Published var markerPalette: [Color] = [.yellow, .pink, .green, .blue, .orange, .purple, .red, .cyan]

  // Width presets (3 each) and selected index
  @Published var penWidthPresets: [CGFloat] = [1.0, 3.0, 6.0]
  @Published var selectedPenPresetIndex: Int = 1

  @Published var markerWidthPresets: [CGFloat] = [3.0, 6.0, 12.0]
  @Published var selectedMarkerPresetIndex: Int = 1

  // Eraser configuration
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

  // Local state for ColorPickers
  @State private var newPenColor: Color = .black
  @State private var newMarkerColor: Color = .yellow

  // Dropdown slider visibility per tool
  @State private var expandedPenPresetIndex: Int? = nil
  @State private var expandedMarkerPresetIndex: Int? = nil

  var body: some View {
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
      
      // Tool buttons (icons only)
      HStack(spacing: 12) {
        Button(action: { selectTool(.pen) }) {
          Image(systemName: "pencil")
            .foregroundColor(currentTool == .pen ? .matchalight_dark : .gray)
        }
        Button(action: { selectTool(.marker) }) {
          Image(systemName: "highlighter")
            .foregroundColor(currentTool == .marker ? .matchalight_dark : .gray)
        }
        Button(action: { selectTool(.eraser) }) {
          Image(systemName: "eraser")
            .foregroundColor(currentTool == .eraser ? .matchalight_dark : .gray)
        }
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
        Button(action: {
          // Text functionality
        }) {
          Image(systemName: "character.textbox")
            .foregroundColor(.gray)
        }
      }

      // Options panel positioned to the right of all tool icons
      if let activeTool = currentTool {
        toolOptionsPanel(for: activeTool)
      }
      
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
    .buttonStyle(PlainButtonStyle())
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
    .onAppear {
      // Ensure we start with a known tool/color instead of any remembered system default
      if currentTool == nil { currentTool = .pen }
      updateCanvasTool()
    }
    .onChange(of: currentPage) { _ in
      updateCanvasTool()
    }
    .onChange(of: currentTool) { _ in
      // Collapse dropdowns when switching tools and re-apply tool
      expandedPenPresetIndex = nil
      expandedMarkerPresetIndex = nil
      updateCanvasTool()
    }
    .zIndex((expandedPenPresetIndex != nil || expandedMarkerPresetIndex != nil) ? 1000 : 0)
  }
  
  @ViewBuilder
  private func toolOptionsPanel(for tool: PenTool) -> some View {
    switch tool {
    case .pen:
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          // Colors (with delete and add)
          HStack(spacing: 6) {
            ForEach(Array(toolState.penPalette.enumerated()), id: \.offset) { index, color in
              Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                  Circle()
                    .stroke(toolState.penColor == color ? Color.matchalight_dark : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Circle())
                .onTapGesture {
                  toolState.penColor = color
                  updateCanvasTool()
                }
                .contextMenu {
                  Button(role: .destructive) {
                    deletePenColor(at: index)
                  } label: {
                    Label("Delete Color", systemImage: "trash")
                  }
                }
            }

            // Add new color
            HStack(spacing: 4) {
              ColorPicker("", selection: $newPenColor, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 22, height: 22)
              Button {
                addPenColor(newPenColor)
              } label: {
                Image(systemName: "plus.circle.fill")
                  .foregroundColor(.matchalight_dark)
              }
            }
          }

          // Width presets with dropdown slider
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              ForEach(0..<toolState.penWidthPresets.count, id: \.self) { i in
                Button {
                  if toolState.selectedPenPresetIndex != i {
                    toolState.selectedPenPresetIndex = i
                    withAnimation { expandedPenPresetIndex = nil }
                    updateCanvasTool()
                  } else {
                    withAnimation { expandedPenPresetIndex = (expandedPenPresetIndex == i ? nil : i) }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(toolState.selectedPenPresetIndex == i ? Color.matchalight_dark : Color.gray.opacity(0.5))
                      .frame(
                        width: max(12, min(20, toolState.penWidthPresets[i])),
                        height: max(12, min(20, toolState.penWidthPresets[i]))
                      )
                    Image(systemName: expandedPenPresetIndex == i ? "chevron.up" : "chevron.down")
                      .font(.system(size: 8, weight: .bold))
                      .foregroundColor(.white.opacity(0.9))
                  }
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)
      .overlay(alignment: .topTrailing) {
        if let expanded = expandedPenPresetIndex {
          let binding = Binding<CGFloat>(
            get: { toolState.penWidthPresets[expanded] },
            set: { newValue in
              toolState.penWidthPresets[expanded] = newValue
              if toolState.selectedPenPresetIndex == expanded { updateCanvasTool() }
            }
          )
          VStack(spacing: 8) {
            HStack(spacing: 6) {
              Image(systemName: "scribble.variable")
                .font(.caption)
                .foregroundColor(.gray)
              Slider(value: binding, in: 0.5...30, step: 0.5)
                .frame(width: 200)
            }
          }
          .padding(10)
          .background(.ultraThinMaterial)
          .cornerRadius(10)
          .shadow(radius: 8)
          .offset(y: 30)
          .zIndex(2000)
          .allowsHitTesting(true)
        }
      }

    case .marker:
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          // Colors (with delete and add)
          HStack(spacing: 6) {
            ForEach(Array(toolState.markerPalette.enumerated()), id: \.offset) { index, color in
              Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                  Circle()
                    .stroke(toolState.markerColor == color ? Color.matchalight_dark : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Circle())
                .onTapGesture {
                  toolState.markerColor = color
                  updateCanvasTool()
                }
                .contextMenu {
                  Button(role: .destructive) {
                    deleteMarkerColor(at: index)
                  } label: {
                    Label("Delete Color", systemImage: "trash")
                  }
                }
            }

            // Add new color
            HStack(spacing: 4) {
              ColorPicker("", selection: $newMarkerColor, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 22, height: 22)
              Button {
                addMarkerColor(newMarkerColor)
              } label: {
                Image(systemName: "plus.circle.fill")
                  .foregroundColor(.matchalight_dark)
              }
            }
          }

          // Width presets with dropdown slider
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              ForEach(0..<toolState.markerWidthPresets.count, id: \.self) { i in
                Button {
                  if toolState.selectedMarkerPresetIndex != i {
                    toolState.selectedMarkerPresetIndex = i
                    withAnimation { expandedMarkerPresetIndex = nil }
                    updateCanvasTool()
                  } else {
                    withAnimation { expandedMarkerPresetIndex = (expandedMarkerPresetIndex == i ? nil : i) }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(toolState.selectedMarkerPresetIndex == i ? Color.matchalight_dark : Color.gray.opacity(0.5))
                      .frame(
                        width: max(12, min(20, toolState.markerWidthPresets[i])),
                        height: max(12, min(20, toolState.markerWidthPresets[i]))
                      )
                    Image(systemName: expandedMarkerPresetIndex == i ? "chevron.up" : "chevron.down")
                      .font(.system(size: 8, weight: .bold))
                      .foregroundColor(.white.opacity(0.9))
                  }
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)
      .overlay(alignment: .topTrailing) {
        if let expanded = expandedMarkerPresetIndex {
          let binding = Binding<CGFloat>(
            get: { toolState.markerWidthPresets[expanded] },
            set: { newValue in
              toolState.markerWidthPresets[expanded] = newValue
              if toolState.selectedMarkerPresetIndex == expanded { updateCanvasTool() }
            }
          )
          VStack(spacing: 8) {
            HStack(spacing: 6) {
              Image(systemName: "scribble")
                .font(.caption)
                .foregroundColor(.gray)
              Slider(value: binding, in: 0.5...40, step: 0.5)
                .frame(width: 200)
            }
          }
          .padding(10)
          .background(.ultraThinMaterial)
          .cornerRadius(10)
          .shadow(radius: 8)
          .offset(y: 30)
          .zIndex(2000)
          .allowsHitTesting(true)
        }
      }

    case .eraser:
      HStack(spacing: 10) {
        // Eraser type select
        HStack(spacing: 6) {
          ForEach(EraserType.allCases, id: \.self) { type in
            Button(action: {
              toolState.eraserType = type
              updateCanvasTool()
            }) {
              Image(systemName: type.icon)
                .font(.caption)
                .foregroundColor(toolState.eraserType == type ? .matchalight_dark : .gray)
                .frame(width: 24, height: 18)
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)

    case .lasso:
      EmptyView()
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
      let width = toolState.penWidthPresets[safe: toolState.selectedPenPresetIndex] ?? 3.0
      canvas.tool = tool.toolInstance(color: toolState.penColor, width: width)
    case .marker:
      let width = toolState.markerWidthPresets[safe: toolState.selectedMarkerPresetIndex] ?? 6.0
      canvas.tool = tool.toolInstance(color: toolState.markerColor, width: width)
    case .eraser:
      canvas.tool = tool.toolInstance(eraserType: toolState.eraserType)
    case .lasso:
      canvas.tool = tool.toolInstance()
    }
  }

  private func deletePenColor(at index: Int) {
    guard toolState.penPalette.indices.contains(index) else { return }
    let colorToRemove = toolState.penPalette[index]
    toolState.penPalette.remove(at: index)
    if toolState.penColor == colorToRemove {
      toolState.penColor = toolState.penPalette.first ?? .black
      updateCanvasTool()
    }
  }

  private func addPenColor(_ color: Color) {
    toolState.penPalette.append(color)
    toolState.penColor = color
    updateCanvasTool()
  }

  private func deleteMarkerColor(at index: Int) {
    guard toolState.markerPalette.indices.contains(index) else { return }
    let colorToRemove = toolState.markerPalette[index]
    toolState.markerPalette.remove(at: index)
    if toolState.markerColor == colorToRemove {
      toolState.markerColor = toolState.markerPalette.first ?? .yellow
      updateCanvasTool()
    }
  }

  private func addMarkerColor(_ color: Color) {
    toolState.markerPalette.append(color)
    toolState.markerColor = color
    updateCanvasTool()
  }
}

// Safe index extension
private extension Array {
  subscript(safe index: Int) -> Element? {
    guard indices.contains(index) else { return nil }
    return self[index]
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
