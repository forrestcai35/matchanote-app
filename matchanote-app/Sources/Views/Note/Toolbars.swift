import PencilKit
import SwiftUI
import UIKit

enum PenTool {
  case pen
  case marker
  case eraser
  case lasso
  case photo
  case textbox

  func toolInstance(color: Color = .black, width: CGFloat = 1.0, eraserType: EraserType = .object)
    -> PKTool
  {
    switch self {
    case .pen:
      return PKInkingTool(.pen, color: UIColor(color), width: width)
    case .marker:
      return PKInkingTool(.marker, color: UIColor(color), width: width)
    case .eraser:
      return eraserType == .object ? PKEraserTool(.vector) : PKEraserTool(.bitmap, width: width)
    case .lasso:
      return PKLassoTool()
    case .photo:
      // Keep canvas in non-inking mode while photo tool is active
      return PKLassoTool()
    case .textbox:
      // Keep canvas in non-inking mode while textbox tool is active
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
  @Published var penPalette: [Color] = [
    .black, .blue, .red, .green, .purple, .orange, .brown, .pink,
  ]
  @Published var markerPalette: [Color] = [
    .yellow, .pink, .green, .blue, .orange, .purple, .red, .cyan,
  ]

  // Width presets (3 each) and selected index
  @Published var penWidthPresets: [CGFloat] = [1.0, 3.0, 6.0] {
    didSet { savePenPresets() }
  }
  @Published var selectedPenPresetIndex: Int = 1 {
    didSet {
      UserDefaults.standard.set(selectedPenPresetIndex, forKey: DefaultsKeys.selectedPenPresetIndex)
    }
  }

  @Published var markerWidthPresets: [CGFloat] = [3.0, 6.0, 12.0] {
    didSet { saveMarkerPresets() }
  }
  @Published var selectedMarkerPresetIndex: Int = 1 {
    didSet {
      UserDefaults.standard.set(
        selectedMarkerPresetIndex, forKey: DefaultsKeys.selectedMarkerPresetIndex)
    }
  }

  // Eraser configuration
  @Published var eraserType: EraserType = .object {
    didSet {
      UserDefaults.standard.set(eraserType == .object ? 0 : 1, forKey: DefaultsKeys.eraserType)
    }
  }
  // UI-only width presets for Area eraser (PencilKit does not expose eraser radius programmatically)
  @Published var eraserAreaWidthPresets: [CGFloat] = [8.0, 16.0, 28.0] {
    didSet { saveEraserAreaPresets() }
  }
  @Published var selectedEraserAreaPresetIndex: Int = 1 {
    didSet {
      UserDefaults.standard.set(
        selectedEraserAreaPresetIndex, forKey: DefaultsKeys.selectedEraserAreaPresetIndex)
    }
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
    if let eraserAreaArray = defaults.array(forKey: DefaultsKeys.eraserAreaWidthPresets)
      as? [Double]
    {
      eraserAreaWidthPresets = eraserAreaArray.map { CGFloat($0) }
    }

    let penIndex = defaults.integer(forKey: DefaultsKeys.selectedPenPresetIndex)
    if penIndex >= 0 && penIndex < penWidthPresets.count { selectedPenPresetIndex = penIndex }

    let markerIndex = defaults.integer(forKey: DefaultsKeys.selectedMarkerPresetIndex)
    if markerIndex >= 0 && markerIndex < markerWidthPresets.count {
      selectedMarkerPresetIndex = markerIndex
    }

    let eraserTypeRaw = defaults.integer(forKey: DefaultsKeys.eraserType)
    if eraserTypeRaw == 0 { eraserType = .object } else if eraserTypeRaw == 1 { eraserType = .area }

    let eraserIndex = defaults.integer(forKey: DefaultsKeys.selectedEraserAreaPresetIndex)
    if eraserIndex >= 0 && eraserIndex < eraserAreaWidthPresets.count {
      selectedEraserAreaPresetIndex = eraserIndex
    }
  }

  private func savePenPresets() {
    UserDefaults.standard.set(
      penWidthPresets.map { Double($0) }, forKey: DefaultsKeys.penWidthPresets)
  }

  private func saveMarkerPresets() {
    UserDefaults.standard.set(
      markerWidthPresets.map { Double($0) }, forKey: DefaultsKeys.markerWidthPresets)
  }

  private func saveEraserAreaPresets() {
    UserDefaults.standard.set(
      eraserAreaWidthPresets.map { Double($0) }, forKey: DefaultsKeys.eraserAreaWidthPresets)
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

  // Image manager for handling images on canvas
  @ObservedObject var imageManager: CanvasImageManager

  // TextBox manager for handling textboxes on canvas
  @ObservedObject var textBoxManager: TextBoxManager

  // Local state for ColorPickers
  @State private var newPenColor: Color = .black
  @State private var newMarkerColor: Color = .yellow
  @State private var showPenColorPicker: Bool = false
  @State private var showMarkerColorPicker: Bool = false

  // Image picker state
  @State private var showImagePicker: Bool = false
  @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
  @State private var previousToolBeforePhoto: PenTool? = nil
  @State private var pickerID = UUID()  // Force picker recreation

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

  // Shape recognition removed

  var body: some View {
    HStack {
      // Left side buttons
      Button(action: {
        toggleBookmarkForCurrentPage()
      }) {
        Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
          .foregroundColor(
            isCurrentPageBookmarked
              ? .matchalight_dark : (colorScheme == .dark ? .matchadark_dark : .matchadark_light))
      }

      Button(action: {
        showPageOverview = true
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor((colorScheme == .dark ? .matchadark_dark : .matchadark_light))
      }

      // Flexible spacer to center the main toolbar content
      Spacer()

      // Centered toolbar content
      HStack(spacing: 12) {
        // Tool buttons (icons only)
        HStack(spacing: 12) {
          Button(action: { selectTool(.pen) }) {
            if currentTool == .pen {
              ZStack {
                if let fillImage = UIImage(named: "pen_fill") {
                  Image(uiImage: fillImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(toolState.penColor)
                }
                Image("pen_outline")
                  .renderingMode(.template)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 26, height: 26)
                  .foregroundColor(colorScheme == .dark ? .white : .black)
              }
            } else {
              Image("pen_outline")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundColor(colorScheme == .dark ? .gray : .black)
            }
          }
          Button(action: { selectTool(.marker) }) {
            if currentTool == .marker {
              ZStack {
                if let fillImage = UIImage(named: "highlighter_fill") {
                  Image(uiImage: fillImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(toolState.markerColor)
                } else {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(toolState.markerColor)
                    .frame(width: 22, height: 14)
                }
                Image("highlighter_outline")
                  .renderingMode(.template)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 26, height: 26)
                  .foregroundColor(colorScheme == .dark ? .white : .black)
              }
            } else {
              Image("highlighter_outline")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundColor(colorScheme == .dark ? .gray : .black)
            }
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
              .foregroundColor(
                currentTool == .lasso ? .matchalight_dark : (colorScheme == .dark ? .gray : .black))
          }
          Button(action: {
            previousToolBeforePhoto = currentTool
            selectTool(.photo)
          }) {
            Image("photo_outline")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 26, height: 26)
              .foregroundColor(
                currentTool == .photo ? .matchalight_dark : (colorScheme == .dark ? .gray : .black))
          }
          Button(action: {
            selectTool(.textbox)
          }) {
            Image("textbox_outline")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 26, height: 26)
              .foregroundColor(
                currentTool == .textbox
                  ? .matchalight_dark : (colorScheme == .dark ? .gray : .black))
          }
        }

        Divider()
          .frame(height: 24)
          .padding(.horizontal, 8)

        // Shape recognition toggle removed

        // Options panel for the current tool
        if let activeTool = currentTool {
          toolOptionsPanel(for: activeTool)
        }
      }

      // Flexible spacer to balance the left side
      Spacer()

      // Right side buttons grouped together
      HStack(spacing: 12) {
        // Undo/Redo buttons
        HStack(spacing: 6) {
          Button(action: { performUndo() }) {
            Image(systemName: "arrow.uturn.backward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(
                canUndo ? (colorScheme == .dark ? .matchadark_dark : .matchadark_light) : .gray)
          }
          .disabled(!canUndo)

          Button(action: { performRedo() }) {
            Image(systemName: "arrow.uturn.forward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(
                canRedo ? (colorScheme == .dark ? .matchadark_dark : .matchadark_light) : .gray)
          }
          .disabled(!canRedo)
        }

        // AI assistant toggle
        Button(action: {
          isAssistantVisible.toggle()
        }) {
          Image(isAssistantVisible ? "logo_icon" : "logo_small_gray")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .opacity(1.0)
        }
      }
    }
    .padding(.horizontal, 12)  // Reduced from 20 to prevent overflow
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
    .onChange(of: showImagePicker) { oldValue, newValue in
      // Keep the photo tool selected when picker opens/closes
      // User can manually select another tool if they want
    }
    .zIndex(
      (expandedPenPresetIndex != nil || expandedMarkerPresetIndex != nil
        || expandedEraserPresetIndex != nil) ? 1000 : 0
    )
    .sheet(isPresented: $showPageOverview) {
      PageOverviewView(
        note: note,
        currentPage: $currentPage,
        canvasViews: $canvasViews,
        isPresented: $showPageOverview
      )
      .environmentObject(storageManager)
    }
    .sheet(isPresented: $showImagePicker) {
      ImagePickerView(
        isPresented: $showImagePicker,
        sourceType: imagePickerSourceType
      ) { selectedImage in
        addImageToCurrentPage(selectedImage)
      }
      .id(pickerID)  // Force recreation with new ID
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
                    withAnimation {
                      expandedPenPresetIndex = (expandedPenPresetIndex == i ? nil : i)
                    }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(
                        toolState.selectedPenPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
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
                .popover(
                  isPresented: Binding<Bool>(
                    get: { expandedPenPresetIndex == i },
                    set: { newValue in expandedPenPresetIndex = newValue ? i : nil }
                  )
                ) {
                  VStack(spacing: 12) {
                    HStack(spacing: 6) {
                      Image(systemName: "scribble.variable")
                        .font(.caption)
                        .foregroundColor(.gray)
                      let binding = Binding<CGFloat>(
                        get: { toolState.penWidthPresets[i] },
                        set: { newValue in
                          toolState.penWidthPresets[i] = newValue
                          if toolState.selectedPenPresetIndex == i { updateCanvasTool() }
                        }
                      )
                      Slider(value: binding, in: 0.5...30, step: 0.5)
                        .frame(width: 200)
                    }
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
              }
            }
          }

          // Colors (with delete and add) - Scrollable with max width
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(Array(toolState.penPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                  .fill(color)
                  .frame(width: 18, height: 18)
                  .overlay(
                    Circle()
                      .stroke(
                        toolState.penColor == color ? Color.matchalight_dark : Color.clear,
                        lineWidth: 1.5)
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
                  Divider()
                  HStack {
                    Button("Cancel") { showPenColorPicker = false }
                      .foregroundColor(.red)
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
            .padding(.horizontal, 4)
          }
          .frame(maxWidth: 200)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)

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
                    withAnimation {
                      expandedMarkerPresetIndex = (expandedMarkerPresetIndex == i ? nil : i)
                    }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(
                        toolState.selectedMarkerPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: dotDiameter(for: toolState.markerWidthPresets[i], maxRange: 40),
                        height: dotDiameter(for: toolState.markerWidthPresets[i], maxRange: 40)
                      )
                    Image(
                      systemName: expandedMarkerPresetIndex == i ? "chevron.up" : "chevron.down"
                    )
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                  }
                }
                .buttonStyle(PlainButtonStyle())
                .popover(
                  isPresented: Binding<Bool>(
                    get: { expandedMarkerPresetIndex == i },
                    set: { newValue in expandedMarkerPresetIndex = newValue ? i : nil }
                  )
                ) {
                  VStack(spacing: 12) {
                    HStack(spacing: 6) {
                      Image(systemName: "scribble")
                        .font(.caption)
                        .foregroundColor(.gray)
                      let binding = Binding<CGFloat>(
                        get: { toolState.markerWidthPresets[i] },
                        set: { newValue in
                          toolState.markerWidthPresets[i] = newValue
                          if toolState.selectedMarkerPresetIndex == i { updateCanvasTool() }
                        }
                      )
                      Slider(value: binding, in: 0.5...40, step: 0.5)
                        .frame(width: 200)
                    }
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
              }
            }
          }

          // Colors (with delete and add) - Scrollable with max width
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(Array(toolState.markerPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                  .fill(color)
                  .frame(width: 18, height: 18)
                  .overlay(
                    Circle()
                      .stroke(
                        toolState.markerColor == color ? Color.matchalight_dark : Color.clear,
                        lineWidth: 1.5)
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
                  Divider()
                  HStack {
                    Button("Cancel") { showMarkerColorPicker = false }
                      .foregroundColor(.red)
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
            .padding(.horizontal, 4)
          }
          .frame(maxWidth: 200)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)

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
                    withAnimation {
                      expandedEraserPresetIndex = (expandedEraserPresetIndex == i ? nil : i)
                    }
                  }
                } label: {
                  ZStack {
                    Circle()
                      .fill(
                        toolState.selectedEraserAreaPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: 40),
                        height: dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: 40)
                      )
                    Image(
                      systemName: expandedEraserPresetIndex == i ? "chevron.up" : "chevron.down"
                    )
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                  }
                }
                .buttonStyle(PlainButtonStyle())
                .popover(
                  isPresented: Binding<Bool>(
                    get: { expandedEraserPresetIndex == i },
                    set: { newValue in expandedEraserPresetIndex = newValue ? i : nil }
                  )
                ) {
                  VStack(spacing: 12) {
                    HStack(spacing: 6) {
                      Image("eraser_outline")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                      let binding = Binding<CGFloat>(
                        get: { toolState.eraserAreaWidthPresets[i] },
                        set: { newValue in
                          toolState.eraserAreaWidthPresets[i] = newValue
                        }
                      )
                      Slider(value: binding, in: 4...60, step: 1)
                        .frame(width: 200)
                    }
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
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

    case .photo:
      HStack(spacing: 10) {
        // Camera icon
        Button(action: {
          imagePickerSourceType = .camera
          pickerID = UUID()
          showImagePicker = true
        }) {
          Image(systemName: "camera")
            .font(.system(size: 18))
            .foregroundColor(colorScheme == .dark ? .matchadark_dark : .matchadark_light)
        }

        // Gallery icon
        Button(action: {
          imagePickerSourceType = .photoLibrary
          pickerID = UUID()
          showImagePicker = true
        }) {
          Image(systemName: "photo.on.rectangle")
            .font(.system(size: 18))
            .foregroundColor(colorScheme == .dark ? .matchadark_dark : .matchadark_light)
        }

        // Recent images - inline horizontal layout
        HStack(spacing: 6) {
          ForEach(0..<4, id: \.self) { index in
            Button(action: {
              imagePickerSourceType = .photoLibrary
              pickerID = UUID()
              showImagePicker = true
            }) {
              RoundedRectangle(cornerRadius: 3)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                .frame(width: 20, height: 20)
                .overlay(
                  Image(systemName: "photo")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 8))
                )
            }
          }
        }
      }

    case .textbox:
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          // Add textbox button
          Button(action: {
            addTextBoxToCurrentPage()
          }) {
            HStack(spacing: 4) {
              Image(systemName: "plus")
                .font(.system(size: 14))
              Text("Add Text")
                .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.matchalight_dark)
            .foregroundColor(.white)
            .cornerRadius(6)
          }

          // Always show formatting controls when textbox tool is active
          TextBoxFormattingControls(textBoxManager: textBoxManager)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)
    }
  }

  private func selectTool(_ tool: PenTool) {
    currentTool = tool
    updateCanvasTool()
  }

  private func updateCanvasTool() {
    guard currentPage < canvasViews.count, let tool = currentTool else { return }
    let canvas = canvasViews[currentPage]

    // Ensure image manager has the correct undo manager
    imageManager.setUndoManager(canvas.undoManager)

    switch tool {
    case .pen:
      let width = toolState.penWidthPresets[safe: toolState.selectedPenPresetIndex] ?? 3.0
      canvas.tool = tool.toolInstance(color: toolState.penColor, width: width)
    case .marker:
      let width = toolState.markerWidthPresets[safe: toolState.selectedMarkerPresetIndex] ?? 6.0
      canvas.tool = tool.toolInstance(color: toolState.markerColor, width: width)
    case .eraser:
      let width =
        toolState.eraserType == .area
        ? toolState.eraserAreaWidthPresets[safe: toolState.selectedEraserAreaPresetIndex] ?? 16.0
        : 1.0
      canvas.tool = tool.toolInstance(width: width, eraserType: toolState.eraserType)
    case .lasso:
      canvas.tool = tool.toolInstance()
    case .photo:
      canvas.tool = tool.toolInstance()
    case .textbox:
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
    let fraction = sqrt(clamped / maxRange)  // emphasize separation at lower widths
    return minDiam + fraction * (maxDiam - minDiam)
  }

  // MARK: - Undo/Redo Methods (now using per-note system)

  private func performUndo() {
    // Note: We need access to the CanvasManager to use the per-note undo system
    // For now, fall back to PencilKit's undo system until we refactor the architecture
    guard currentPage < canvasViews.count else { return }
    let canvas = canvasViews[currentPage]
    canvas.undoManager?.undo()
    updateUndoRedoState()
  }

  private func performRedo() {
    // Note: We need access to the CanvasManager to use the per-note undo system
    // For now, fall back to PencilKit's undo system until we refactor the architecture
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

  // MARK: - Image Handling Methods

  private func addImageToCurrentPage(_ image: UIImage) {
    // Calculate center position for the image on the current page
    let paperSize = CGSize(
      width: PaperUtilities.getPaperWidth(for: note.paperSize),
      height: PaperUtilities.getPaperHeight(for: note.paperSize)
    )

    let centerPosition = CGPoint(
      x: paperSize.width / 2 - 150,  // Offset by half of initial width
      y: paperSize.height / 2 - 150  // Offset by half of initial height
    )

    // Add image to the current page
    imageManager.addImageToPage(image, at: centerPosition, pageIndex: currentPage)
  }

  // MARK: - TextBox Handling Methods

  private func addTextBoxToCurrentPage() {
    // Calculate center position for the textbox on the current page
    let paperSize = CGSize(
      width: PaperUtilities.getPaperWidth(for: note.paperSize),
      height: PaperUtilities.getPaperHeight(for: note.paperSize)
    )

    let centerPosition = CGPoint(
      x: paperSize.width / 2 - 100,  // Offset by half of textbox width
      y: paperSize.height / 2 - 30  // Offset by half of textbox height
    )

    // Add textbox to the current page
    textBoxManager.addTextBox(to: currentPage, at: centerPosition)
  }

}

// Safe index extension
extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
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
  @ObservedObject var imageManager: CanvasImageManager
  @ObservedObject var textBoxManager: TextBoxManager

  var body: some View {
    HStack {
      // Left side buttons
      Button(action: {
        // Bookmark functionality
      }) {
        Image(systemName: "bookmark")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }

      Button(action: {
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }

      // Flexible spacer to center the main content
      Spacer()

      // Centered text formatting tools
      HStack(spacing: 12) {
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
      }

      // Flexible spacer to balance the left side
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
          Image(isAssistantVisible ? "logo_icon" : "logo_small_gray")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .opacity(1.0)
        }
      }

    }
    .padding(.horizontal, 12)  // Reduced from 20 for consistency
    .padding(.vertical, 8)
    .frame(height: 40)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))

  }
}

// ShareSheet was removed; direct presentation is done in NoteView
