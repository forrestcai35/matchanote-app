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
      return eraserType == .object ? PKEraserTool(.vector) : PKEraserTool(.bitmap, width: width)
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
  
  // Use custom asset names instead of SF Symbols
  var icon: String {
    switch self {
    case .object: return "eraser_outline"
    case .area: return "eraser_fill"
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
  // MARK: - Persistence Keys
  private enum DefaultsKeys {
    static let penWidthPresets = "tool.penWidthPresets"
    static let selectedPenPresetIndex = "tool.selectedPenPresetIndex"
    static let markerWidthPresets = "tool.markerWidthPresets"
    static let selectedMarkerPresetIndex = "tool.selectedMarkerPresetIndex"
    static let eraserType = "tool.eraserType"
    static let eraserAreaWidthPresets = "tool.eraserAreaWidthPresets"
    static let selectedEraserAreaPresetIndex = "tool.selectedEraserAreaPresetIndex"
  }

  @Published var penColor: Color = .black
  @Published var markerColor: Color = .yellow

  // Dynamic palettes
  @Published var penPalette: [Color] = [.black, .blue, .red, .green, .purple, .orange, .brown, .pink]
  @Published var markerPalette: [Color] = [.yellow, .pink, .green, .blue, .orange, .purple, .red, .cyan]

  // Width presets (3 each) and selected index
  @Published var penWidthPresets: [CGFloat] = [1.0, 3.0, 6.0] {
    didSet { savePenPresets() }
  }
  @Published var selectedPenPresetIndex: Int = 1 {
    didSet { UserDefaults.standard.set(selectedPenPresetIndex, forKey: DefaultsKeys.selectedPenPresetIndex) }
  }

  @Published var markerWidthPresets: [CGFloat] = [3.0, 6.0, 12.0] {
    didSet { saveMarkerPresets() }
  }
  @Published var selectedMarkerPresetIndex: Int = 1 {
    didSet { UserDefaults.standard.set(selectedMarkerPresetIndex, forKey: DefaultsKeys.selectedMarkerPresetIndex) }
  }

  // Eraser configuration
  @Published var eraserType: EraserType = .object {
    didSet { UserDefaults.standard.set(eraserType == .object ? 0 : 1, forKey: DefaultsKeys.eraserType) }
  }
  // UI-only width presets for Area eraser (PencilKit does not expose eraser radius programmatically)
  @Published var eraserAreaWidthPresets: [CGFloat] = [8.0, 16.0, 28.0] {
    didSet { saveEraserAreaPresets() }
  }
  @Published var selectedEraserAreaPresetIndex: Int = 1 {
    didSet { UserDefaults.standard.set(selectedEraserAreaPresetIndex, forKey: DefaultsKeys.selectedEraserAreaPresetIndex) }
  }

  // Undo/Redo state
  @Published var canUndo: Bool = false
  @Published var canRedo: Bool = false

  init() {
    loadFromDefaults()
  }

  // MARK: - Persistence Helpers
  private func loadFromDefaults() {
    let defaults = UserDefaults.standard

    if let penArray = defaults.array(forKey: DefaultsKeys.penWidthPresets) as? [Double] {
      penWidthPresets = penArray.map { CGFloat($0) }
    }
    if let markerArray = defaults.array(forKey: DefaultsKeys.markerWidthPresets) as? [Double] {
      markerWidthPresets = markerArray.map { CGFloat($0) }
    }
    if let eraserAreaArray = defaults.array(forKey: DefaultsKeys.eraserAreaWidthPresets) as? [Double] {
      eraserAreaWidthPresets = eraserAreaArray.map { CGFloat($0) }
    }

    let penIndex = defaults.integer(forKey: DefaultsKeys.selectedPenPresetIndex)
    if penIndex >= 0 && penIndex < penWidthPresets.count { selectedPenPresetIndex = penIndex }

    let markerIndex = defaults.integer(forKey: DefaultsKeys.selectedMarkerPresetIndex)
    if markerIndex >= 0 && markerIndex < markerWidthPresets.count { selectedMarkerPresetIndex = markerIndex }

    let eraserTypeRaw = defaults.integer(forKey: DefaultsKeys.eraserType)
    if eraserTypeRaw == 0 { eraserType = .object } else if eraserTypeRaw == 1 { eraserType = .area }

    let eraserIndex = defaults.integer(forKey: DefaultsKeys.selectedEraserAreaPresetIndex)
    if eraserIndex >= 0 && eraserIndex < eraserAreaWidthPresets.count { selectedEraserAreaPresetIndex = eraserIndex }
  }

  private func savePenPresets() {
    UserDefaults.standard.set(penWidthPresets.map { Double($0) }, forKey: DefaultsKeys.penWidthPresets)
  }

  private func saveMarkerPresets() {
    UserDefaults.standard.set(markerWidthPresets.map { Double($0) }, forKey: DefaultsKeys.markerWidthPresets)
  }

  private func saveEraserAreaPresets() {
    UserDefaults.standard.set(eraserAreaWidthPresets.map { Double($0) }, forKey: DefaultsKeys.eraserAreaWidthPresets)
  }
}

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  var note: Note
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var toolState = ToolState()
  @EnvironmentObject private var storageManager: StorageManager
  @ObservedObject private var tabManager = TabManager.shared

  // Added to reference canvas array and current page
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?

  // Local state for ColorPickers
  @State private var newPenColor: Color = .black
  @State private var newMarkerColor: Color = .yellow
  @State private var showPenColorPicker: Bool = false
  @State private var showMarkerColorPicker: Bool = false

  // Dropdown slider visibility per tool
  @State private var expandedPenPresetIndex: Int? = nil
  @State private var expandedMarkerPresetIndex: Int? = nil
  @State private var expandedEraserPresetIndex: Int? = nil

  // Undo/Redo state
  @State private var canUndo: Bool = false
  @State private var canRedo: Bool = false
  @State private var undoRedoUpdateTimer: Timer?

  // Page overview state
  @State private var showPageOverview: Bool = false

  // Reserve fixed widths so icons do not shift - adjusted for better spacing
  private let toolIconBarWidth: CGFloat = 180 // Reduced to prevent overflow
  private let optionsPanelReservedWidth: CGFloat = 340 // Reduced to give more room

  var body: some View {
    HStack {
      // Left side buttons
      Button(action: {
        toggleBookmarkForCurrentPage()
      }) {
        Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
          .foregroundColor(isCurrentPageBookmarked ? .matchalight_dark : (colorScheme == .dark ? .matchadark_dark : .matchadark_light))
      }

      Button(action: {
        showPageOverview = true
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor((colorScheme == .dark ? .matchadark_dark : .matchadark_light))
      }

      // Fixed spacing to push tools to the right
      Spacer()
        .frame(minWidth: 60)
      
      // Tool buttons (icons only)
      HStack(spacing: 12) {
        Button(action: { selectTool(.pen) }) {
          Image("pen_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundColor(currentTool == .pen ? toolState.penColor : (colorScheme == .dark ? .gray : .black))
        }
        Button(action: { selectTool(.marker) }) {
          Image("highlighter_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundColor(currentTool == .marker ? toolState.markerColor : (colorScheme == .dark ? .gray : .black))
        }
        Button(action: { selectTool(.eraser) }) {
          if currentTool == .eraser {
            Image("eraser_fill")
              .renderingMode(.original)
              .resizable()
              .scaledToFit()
              .frame(width: 26, height: 26)
          } else {
            Image("eraser_outline")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 26, height: 26)
              .foregroundColor(colorScheme == .dark ? .gray : .black)
          }
        } 
        Button(action: {
          if currentTool == .lasso {
            selectTool(.pen)
          } else {
            selectTool(.lasso)
          }
        }) {
          Image("lasso_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundColor(currentTool == .lasso ? .matchalight_dark : (colorScheme == .dark ? .gray : .black))
        }
        Button(action: {
          // Image functionality
        }) {
          Image("photo_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundColor(colorScheme == .dark ? .gray : .black)
        }
        Button(action: {
          // Text functionality
        }) {
          Image("textbox_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .foregroundColor(colorScheme == .dark ? .gray : .black)
        }
      }
      .frame(width: toolIconBarWidth) // keep icon positions fixed

      Divider()
        .frame(height: 24)
        .padding(.horizontal, 8)
      // Options panel positioned to the right of all tool icons


      ZStack(alignment: .leading) {
        if let activeTool = currentTool {
          toolOptionsPanel(for: activeTool)
        }
      }
      .frame(width: optionsPanelReservedWidth, alignment: .leading)

      Spacer()
        .frame(maxWidth: 30) // Increased slightly for better balance
      
      // Right side buttons grouped together
      HStack(spacing: 12) {
        // Undo/Redo buttons
        HStack(spacing: 6) {
          Button(action: { performUndo() }) {
            Image(systemName: "arrow.uturn.backward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(canUndo ? (colorScheme == .dark ? .matchadark_dark : .matchadark_light) : .gray)
          }
          .disabled(!canUndo)
          
          Button(action: { performRedo() }) {
            Image(systemName: "arrow.uturn.forward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(canRedo ? (colorScheme == .dark ? .matchadark_dark : .matchadark_light) : .gray)
          }
          .disabled(!canRedo)
        }

        // AI assistant toggle
        Button(action: {
          isAssistantVisible.toggle()
        }) {
          Image(systemName: "wand.and.rays")
            .foregroundColor(isAssistantVisible ? (colorScheme == .dark ? .matchadark_dark : .matchadark_light) : .gray)
        }
      }
    }
    .padding(.horizontal, 12) // Reduced from 20 to prevent overflow
    .padding(.vertical, 8)
    .frame(height: 40)
    .buttonStyle(PlainButtonStyle())
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
    .onAppear {
      // Ensure we start with a known tool/color instead of any remembered system default
      if currentTool == nil { currentTool = .pen }
      updateCanvasTool()
      startUndoRedoTimer()
    }
    .onDisappear {
      stopUndoRedoTimer()
    }
    .onChange(of: currentPage) {
      updateCanvasTool()
      updateUndoRedoState()
    }
    .onChange(of: currentTool) {
      // Collapse dropdowns when switching tools and re-apply tool
      expandedPenPresetIndex = nil
      expandedMarkerPresetIndex = nil
      expandedEraserPresetIndex = nil
      updateCanvasTool()
    }
    .zIndex((expandedPenPresetIndex != nil || expandedMarkerPresetIndex != nil || expandedEraserPresetIndex != nil) ? 1000 : 0)
    .sheet(isPresented: $showPageOverview) {
      PageOverviewView(
        note: note,
        currentPage: $currentPage,
        canvasViews: $canvasViews,
        isPresented: $showPageOverview
      )
      .environmentObject(storageManager)
    }
  }
  
  @ViewBuilder
  private func toolOptionsPanel(for tool: PenTool) -> some View {
    switch tool {
    case .pen:
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
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
                        width: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 30),
                        height: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 30)
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
            Button {
              showPenColorPicker = true
            } label: {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(.matchalight_dark)
            }
            .popover(isPresented: $showPenColorPicker) {
              VStack(spacing: 12) {
                ColorPicker("Pick a color", selection: $newPenColor, supportsOpacity: true)
                  .padding(.horizontal)
                HStack {
                  Button("Cancel") { showPenColorPicker = false }
                  Spacer()
                  Button("Add") {
                    addPenColor(newPenColor)
                    showPenColorPicker = false
                  }
                }
                .padding(.horizontal)
              }
              .padding(.vertical, 12)
              .frame(minWidth: 260)
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
                        width: dotDiameter(for: toolState.markerWidthPresets[i], maxRange: 40),
                        height: dotDiameter(for: toolState.markerWidthPresets[i], maxRange: 40)
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
            Button {
              showMarkerColorPicker = true
            } label: {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(.matchalight_dark)
            }
            .popover(isPresented: $showMarkerColorPicker) {
              VStack(spacing: 12) {
                ColorPicker("Pick a color", selection: $newMarkerColor, supportsOpacity: true)
                  .padding(.horizontal)
                HStack {
                  Button("Cancel") { showMarkerColorPicker = false }
                  Spacer()
                  Button("Add") {
                    addMarkerColor(newMarkerColor)
                    showMarkerColorPicker = false
                  }
                }
                .padding(.horizontal)
              }
              .padding(.vertical, 12)
              .frame(minWidth: 260)
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
      HStack(spacing: 12) {
        // Eraser type select
        HStack(spacing: 6) {
          ForEach(EraserType.allCases, id: \.self) { type in
            Button(action: {
              toolState.eraserType = type
              updateCanvasTool()
            }) {
              Image(type.icon)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .opacity(toolState.eraserType == type ? 1.0 : 0.5)
            }
          }
        }

        // Area eraser width presets (UI only)
        if toolState.eraserType == .area {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              ForEach(0..<toolState.eraserAreaWidthPresets.count, id: \.self) { i in
                Button {
                  if toolState.selectedEraserAreaPresetIndex != i {
                    toolState.selectedEraserAreaPresetIndex = i
                    withAnimation { expandedEraserPresetIndex = nil }
                    // No direct eraser width API to update tool here
                  } else {
                    withAnimation { expandedEraserPresetIndex = (expandedEraserPresetIndex == i ? nil : i) }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(toolState.selectedEraserAreaPresetIndex == i ? Color.matchalight_dark : Color.gray.opacity(0.5))
                      .frame(
                        width: dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: 40),
                        height: dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: 40)
                      )
                    Image(systemName: expandedEraserPresetIndex == i ? "chevron.up" : "chevron.down")
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
        if toolState.eraserType == .area, let expanded = expandedEraserPresetIndex {
          let binding = Binding<CGFloat>(
            get: { toolState.eraserAreaWidthPresets[expanded] },
            set: { newValue in
              toolState.eraserAreaWidthPresets[expanded] = newValue
              // No direct eraser width API to update tool here
            }
          )
          VStack(spacing: 8) {
            HStack(spacing: 6) {
              Image("eraser_outline")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
              Slider(value: binding, in: 4...60, step: 1)
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
      let width = toolState.eraserType == .area ? toolState.eraserAreaWidthPresets[safe: toolState.selectedEraserAreaPresetIndex] ?? 16.0 : 1.0
      canvas.tool = tool.toolInstance(width: width, eraserType: toolState.eraserType)
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

  // Map a tool width to a visually distinct diameter for the preset dot
  private func dotDiameter(for width: CGFloat, maxRange: CGFloat) -> CGFloat {
    let minDiam: CGFloat = 12
    let maxDiam: CGFloat = 26
    let clamped = max(0.001, min(width, maxRange))
    let fraction = sqrt(clamped / maxRange) // emphasize separation at lower widths
    return minDiam + fraction * (maxDiam - minDiam)
  }
  
  // MARK: - Undo/Redo Methods
  
  private func performUndo() {
    guard currentPage < canvasViews.count else { return }
    let canvas = canvasViews[currentPage]
    canvas.undoManager?.undo()
    updateUndoRedoState()
  }
  
  private func performRedo() {
    guard currentPage < canvasViews.count else { return }
    let canvas = canvasViews[currentPage]
    canvas.undoManager?.redo()
    updateUndoRedoState()
  }
  
  private func updateUndoRedoState() {
    guard currentPage < canvasViews.count else { 
      canUndo = false
      canRedo = false
      return 
    }
    let canvas = canvasViews[currentPage]
    canUndo = canvas.undoManager?.canUndo ?? false
    canRedo = canvas.undoManager?.canRedo ?? false
  }
  
  private func startUndoRedoTimer() {
    undoRedoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      updateUndoRedoState()
    }
  }
  
  private func stopUndoRedoTimer() {
    undoRedoUpdateTimer?.invalidate()
    undoRedoUpdateTimer = nil
  }

  private func toggleBookmarkForCurrentPage() {
    var updatedNote = note
    if updatedNote.bookmarkedPages.contains(currentPage) {
      updatedNote.bookmarkedPages.remove(currentPage)
    } else {
      updatedNote.bookmarkedPages.insert(currentPage)
    }
    updatedNote.dateModified = Date()
    
    let savedNote = storageManager.saveNote(updatedNote)
    tabManager.updateNote(savedNote)
  }
  
  private var isCurrentPageBookmarked: Bool {
    return note.bookmarkedPages.contains(currentPage)
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
  var note: Note
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
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }

      //View Button
      Button(action: {
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
      Spacer()
      Button(action: {}) { 
        Image(systemName: "bold")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
      Button(action: {}) { 
        Image(systemName: "italic")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
      Button(action: {}) { 
        Image(systemName: "underline")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
      Button(action: {}) { 
        Image(systemName: "list.bullet")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
      
      Spacer()

      // Right side buttons grouped together  
      HStack(spacing: 12) {
        // Undo/Redo buttons (disabled for text mode)
        HStack(spacing: 6) {
          Button(action: {}) {
            Image(systemName: "arrow.uturn.backward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.gray)
          }
          .disabled(true)
          
          Button(action: {}) {
            Image(systemName: "arrow.uturn.forward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.gray)
          }
          .disabled(true)
        }

        // AI assistant toggle
        Button(action: {
          isAssistantVisible.toggle()
        }) {
          Image(systemName: "wand.and.rays")
            .foregroundColor(isAssistantVisible ? .green : (colorScheme == .dark ? .gray : .black))
        }
      }

    }
    .padding(.horizontal, 12) // Reduced from 20 for consistency
    .padding(.vertical, 8)
    .frame(height: 56)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))

  }
}
