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

// Color palette management
class ColorPaletteManager: ObservableObject {
  @Published var penColors: [Color] = []
  @Published var markerColors: [Color] = []
  @Published var showingColorPicker = false
  @Published var editingPenColors = false
  @Published var colorToEdit: Color = .black
  @Published var editingColorIndex: Int = 0
  
  // Default color options for selection
  let availableColors: [Color] = [
    .black, .white, .gray, .red, .orange, .yellow, .green, .blue, 
    .purple, .pink, .brown, .cyan, .indigo, .mint, .teal,
    .matchalight_dark, .matchalight_light, .matchadark_light, .matchadark_dark
  ]
  
  private let penColorsKey = "PenColors"
  private let markerColorsKey = "MarkerColors"
  
  init() {
    loadColors()
  }
  
  private func loadColors() {
    // Load pen colors
    if let penData = UserDefaults.standard.array(forKey: penColorsKey) as? [String] {
      penColors = penData.compactMap { stringToColor($0) }
    }
    
    // Load marker colors
    if let markerData = UserDefaults.standard.array(forKey: markerColorsKey) as? [String] {
      markerColors = markerData.compactMap { stringToColor($0) }
    }
    
    // Set defaults if empty
    if penColors.isEmpty {
      penColors = [.black, .blue, .red, .green]
    }
    
    if markerColors.isEmpty {
      markerColors = [.yellow, .pink, .green, .blue]
    }
  }
  
  private func saveColors() {
    // Save pen colors
    let penData = penColors.map { colorToString($0) }
    UserDefaults.standard.set(penData, forKey: penColorsKey)
    
    // Save marker colors
    let markerData = markerColors.map { colorToString($0) }
    UserDefaults.standard.set(markerData, forKey: markerColorsKey)
  }
  
  func updatePenColor(at index: Int, with color: Color) {
    if index < penColors.count {
      penColors[index] = color
      saveColors()
    }
  }
  
  func updateMarkerColor(at index: Int, with color: Color) {
    if index < markerColors.count {
      markerColors[index] = color
      saveColors()
    }
  }
  
  func addPenColor(_ color: Color) {
    if penColors.count < 8 {
      penColors.append(color)
      saveColors()
    }
  }
  
  func addMarkerColor(_ color: Color) {
    if markerColors.count < 8 {
      markerColors.append(color)
      saveColors()
    }
  }
  
  func removePenColor(at index: Int) {
    if index < penColors.count && penColors.count > 1 {
      penColors.remove(at: index)
      saveColors()
    }
  }
  
  func removeMarkerColor(at index: Int) {
    if index < markerColors.count && markerColors.count > 1 {
      markerColors.remove(at: index)
      saveColors()
    }
  }
  
  func startEditingColor(_ color: Color, at index: Int, forPen: Bool) {
    colorToEdit = color
    editingColorIndex = index
    editingPenColors = forPen
    showingColorPicker = true
  }
  
  func finishEditingColor(with newColor: Color) {
    if editingPenColors {
      updatePenColor(at: editingColorIndex, with: newColor)
    } else {
      updateMarkerColor(at: editingColorIndex, with: newColor)
    }
    showingColorPicker = false
  }
}

// Tool state management
class ToolState: ObservableObject {
  @Published var penColor: Color = ColorPaletteManager.penColors[0]
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
  @StateObject private var colorPalette = ColorPaletteManager()

  // Added to reference canvas array and current page
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?

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
      
      // Tool buttons with inline customization
      HStack(spacing: 12) {
        // Pen Tool with options
        if currentTool == .pen {
          penToolWithOptions
        } else {
          Button(action: { selectTool(.pen) }) {
        Image(systemName: "pencil")
              .foregroundColor(.gray)
          }
        }
        
        // Marker Tool with options
        if currentTool == .marker {
          markerToolWithOptions
        } else {
          Button(action: { selectTool(.marker) }) {
        Image(systemName: "highlighter")
              .foregroundColor(.gray)
          }
      }
      
        // Eraser Tool with options
        if currentTool == .eraser {
          eraserToolWithOptions
        } else {
          Button(action: { selectTool(.eraser) }) {
            Image(systemName: "eraser")
              .foregroundColor(.gray)
          }
        }

        // Lasso Tool (no customization)
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
    .sheet(isPresented: $colorPalette.showingColorPicker) {
      ColorCustomizationSheet(colorPalette: colorPalette)
    }
  }
  
  @ViewBuilder
  private var penToolWithOptions: some View {
    HStack(spacing: 6) {
      // Pen icon
      Button(action: { selectTool(.pen) }) {
        Image(systemName: "pencil")
          .foregroundColor(.matchalight_dark)
      }
      
      // Color options
      HStack(spacing: 3) {
        ForEach(Array(colorPalette.penColors.enumerated()), id: \.offset) { index, color in
          Button(action: {
            toolState.penColor = color
            updateCanvasTool()
          }) {
            Circle()
              .fill(color)
              .frame(width: 16, height: 16)
              .overlay(
                Circle()
                  .stroke(
                    toolState.penColor == color ? Color.matchalight_dark : Color.clear,
                    lineWidth: 1.5
                  )
              )
              .overlay(
                // Special indicator for black/white
                (color == .black || color == .white) ?
                Circle()
                  .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                : nil
              )
          }
          .onLongPressGesture {
            colorPalette.startEditingColor(color, at: index, forPen: true)
          }
        }
        
        // Add color button
        if colorPalette.penColors.count < 8 {
          Button(action: {
            colorPalette.startEditingColor(.black, at: colorPalette.penColors.count, forPen: true)
          }) {
            Circle()
              .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [2]))
              .frame(width: 16, height: 16)
              .overlay(
                Image(systemName: "plus")
                  .font(.caption2)
                  .foregroundColor(.gray)
              )
          }
        }
      }
      
      // Width options
      HStack(spacing: 3) {
        ForEach(ToolWidth.allCases, id: \.self) { width in
          Button(action: {
            toolState.penWidth = width
            updateCanvasTool()
          }) {
            Circle()
              .fill(toolState.penWidth == width ? Color.matchalight_dark : Color.gray.opacity(0.5))
              .frame(width: width.visualSize, height: width.visualSize)
          }
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.matchalight_dark.opacity(0.1))
    .cornerRadius(8)
  }
  
  @ViewBuilder
  private var markerToolWithOptions: some View {
    HStack(spacing: 6) {
      // Marker icon
      Button(action: { selectTool(.marker) }) {
        Image(systemName: "highlighter")
          .foregroundColor(.matchalight_dark)
      }
      
      // Color options
      HStack(spacing: 3) {
        ForEach(Array(colorPalette.markerColors.enumerated()), id: \.offset) { index, color in
          Button(action: {
            toolState.markerColor = color
            updateCanvasTool()
          }) {
            Circle()
              .fill(color)
              .frame(width: 16, height: 16)
              .overlay(
                Circle()
                  .stroke(
                    toolState.markerColor == color ? Color.matchalight_dark : Color.clear,
                    lineWidth: 1.5
                  )
              )
          }
          .onLongPressGesture {
            colorPalette.startEditingColor(color, at: index, forPen: false)
          }
        }
        
        // Add color button
        if colorPalette.markerColors.count < 8 {
          Button(action: {
            colorPalette.startEditingColor(.yellow, at: colorPalette.markerColors.count, forPen: false)
          }) {
            Circle()
              .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [2]))
              .frame(width: 16, height: 16)
              .overlay(
                Image(systemName: "plus")
                  .font(.caption2)
                  .foregroundColor(.gray)
              )
          }
        }
      }
      
      // Width options
      HStack(spacing: 3) {
        ForEach(ToolWidth.allCases, id: \.self) { width in
          Button(action: {
            toolState.markerWidth = width
            updateCanvasTool()
          }) {
            Circle()
              .fill(toolState.markerWidth == width ? Color.matchalight_dark : Color.gray.opacity(0.5))
              .frame(width: width.visualSize, height: width.visualSize)
          }
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.matchalight_dark.opacity(0.1))
    .cornerRadius(8)
  }
  
  @ViewBuilder
  private var eraserToolWithOptions: some View {
    HStack(spacing: 6) {
      // Eraser icon
      Button(action: { selectTool(.eraser) }) {
        Image(systemName: "eraser")
          .foregroundColor(.matchalight_dark)
      }
      
      // Eraser type options
      HStack(spacing: 3) {
        ForEach(EraserType.allCases, id: \.self) { type in
          Button(action: {
            toolState.eraserType = type
            updateCanvasTool()
          }) {
            Image(systemName: type.icon)
              .font(.caption)
              .foregroundColor(
                toolState.eraserType == type 
                  ? .matchalight_dark 
                  : .gray
              )
              .frame(width: 20, height: 16)
          }
        }
      }
      
      // Width options (only for area eraser)
      if toolState.eraserType == .area {
        HStack(spacing: 3) {
          ForEach(ToolWidth.allCases, id: \.self) { width in
            Button(action: {
              toolState.eraserWidth = width
              updateCanvasTool()
            }) {
              Circle()
                .fill(toolState.eraserWidth == width ? Color.matchalight_dark : Color.gray.opacity(0.5))
                .frame(width: width.visualSize, height: width.visualSize)
            }
          }
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.matchalight_dark.opacity(0.1))
    .cornerRadius(8)
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

// Color customization sheet
struct ColorCustomizationSheet: View {
  @ObservedObject var colorPalette: ColorPaletteManager
  @Environment(\.dismiss) private var dismiss
  @State private var selectedColor: Color = .black
  
  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        Text("Customize Color")
          .font(.title2)
          .fontWeight(.semibold)
        
        // Color preview
        Circle()
          .fill(selectedColor)
          .frame(width: 60, height: 60)
          .overlay(
            Circle()
              .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          )
        
        // Available colors grid
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
          ForEach(colorPalette.availableColors, id: \.self) { color in
            Button(action: {
              selectedColor = color
            }) {
              Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                  Circle()
                    .stroke(
                      selectedColor == color ? Color.blue : Color.gray.opacity(0.3),
                      lineWidth: selectedColor == color ? 2 : 1
                    )
                )
            }
          }
        }
        .padding(.horizontal)
        
        Spacer()
      }
      .padding()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            colorPalette.finishEditingColor(with: selectedColor)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
    .onAppear {
      selectedColor = colorPalette.colorToEdit
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
