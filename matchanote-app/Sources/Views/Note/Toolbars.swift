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
  case shape

  func toolInstance(color: Color = .black, width: CGFloat = 1.0, eraserType: EraserType = .object)
    -> PKTool
  {
    switch self {
    case .pen:
      return PKInkingTool(.monoline, color: UIColor(color), width: width)
    case .marker:
      // Increase opacity for the highlighter by boosting the alpha channel
      return PKInkingTool(
        .marker,
        color: UIColor(color).withAlphaComponent(0.6),
        width: width
      )
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
    case .shape:
      // Shape tool works exactly like pen but with recognition enabled
      return PKInkingTool(.monoline, color: UIColor(color), width: width)
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
  // Flag to prevent saving during initial load
  private var isLoadingFromDefaults = false
  
  // MARK: - Persistence Keys
  private enum DefaultsKeys {
    static let penWidthPresets = "tool.penWidthPresets"
    static let selectedPenPresetIndex = "tool.selectedPenPresetIndex"
    static let markerWidthPresets = "tool.markerWidthPresets"
    static let selectedMarkerPresetIndex = "tool.selectedMarkerPresetIndex"
    static let eraserType = "tool.eraserType"
    static let eraserAreaWidthPresets = "tool.eraserAreaWidthPresets"
    static let selectedEraserAreaPresetIndex = "tool.selectedEraserAreaPresetIndex"
    static let autoStrokeRecognitionEnabled = "tool.autoStrokeRecognitionEnabled"
    static let autoStrokeRecognitionLongPressThreshold = "tool.autoStrokeRecognitionLongPressThreshold"
    static let autoStrokeRecognitionSensitivity = "tool.autoStrokeRecognitionSensitivity"
    static let penPalette = "tool.penPalette"
    static let penColor = "tool.penColor"
    static let markerPalette = "tool.markerPalette"
    static let markerColor = "tool.markerColor"
    static let penDropdownCustomColors = "tool.penDropdownCustomColors"
    static let markerDropdownCustomColors = "tool.markerDropdownCustomColors"
  }

  @Published var penColor: Color = .black {
    didSet { savePenColor() }
  }
  @Published var markerColor: Color = .yellow {
    didSet { saveMarkerColor() }
  }

  // Dynamic palettes
  @Published var penPalette: [Color] = [
    .black, .blue, .red, .green, .purple, .orange, .brown, .pink,
  ] {
    didSet { savePenPalette() }
  }
  @Published var markerPalette: [Color] = [
    .yellow, .pink, .green, .blue, .orange, .purple, .red, .cyan,
  ] {
    didSet { saveMarkerPalette() }
  }

  // Dropdown custom colors (stored as flat arrays)
  @Published var penDropdownCustomColors: [Color] = [] {
    didSet { savePenDropdownCustomColors() }
  }
  @Published var markerDropdownCustomColors: [Color] = [] {
    didSet { saveMarkerDropdownCustomColors() }
  }

  // Width presets (3 each) and selected index
  @Published var penWidthPresets: [CGFloat] = [1.0, 3.0, 6.0] {
    didSet { savePenPresets() }
  }
  @Published var selectedPenPresetIndex: Int = 1 {
    didSet {
      UserDefaults.standard.set(selectedPenPresetIndex, forKey: DefaultsKeys.selectedPenPresetIndex)
    }
  }

  @Published var markerWidthPresets: [CGFloat] = [8.0, 16.0, 24.0] {
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
  @Published var eraserAreaWidthPresets: [CGFloat] = [8.0, 60.0, 120] {
    didSet { saveEraserAreaPresets() }
  }
  @Published var selectedEraserAreaPresetIndex: Int = 1 {
    didSet {
      UserDefaults.standard.set(
        selectedEraserAreaPresetIndex, forKey: DefaultsKeys.selectedEraserAreaPresetIndex)
    }
  }

  // UI-only: Dot sizes for the three area eraser width selectors (customizable per preset)
  @Published var eraserAreaDotSizes: [CGFloat] = [26, 50, 90]

  // Undo/Redo state
  @Published var canUndo: Bool = false
  @Published var canRedo: Bool = false

  // Auto stroke recognition settings
  @Published var isAutoStrokeRecognitionEnabled: Bool = true {
    didSet {
      UserDefaults.standard.set(isAutoStrokeRecognitionEnabled, forKey: DefaultsKeys.autoStrokeRecognitionEnabled)
    }
  }
  @Published var longPressThreshold: Double = 1.5 {
    didSet {
      UserDefaults.standard.set(longPressThreshold, forKey: DefaultsKeys.autoStrokeRecognitionLongPressThreshold)
    }
  }
  @Published var strokeRecognitionSensitivity: Float = 0.7 {
    didSet {
      UserDefaults.standard.set(strokeRecognitionSensitivity, forKey: DefaultsKeys.autoStrokeRecognitionSensitivity)
    }
  }

  init() {
    loadFromDefaults()
  }

  // MARK: - Persistence Helpers
  private func loadFromDefaults() {
    isLoadingFromDefaults = true
    defer { isLoadingFromDefaults = false }
    
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

    // Load auto stroke recognition settings
    isAutoStrokeRecognitionEnabled = defaults.object(forKey: DefaultsKeys.autoStrokeRecognitionEnabled) as? Bool ?? true
    longPressThreshold = defaults.object(forKey: DefaultsKeys.autoStrokeRecognitionLongPressThreshold) as? Double ?? 1.5
    strokeRecognitionSensitivity = defaults.object(forKey: DefaultsKeys.autoStrokeRecognitionSensitivity) as? Float ?? 0.7

    // Load pen palette and color
    if let loadedPalette = ColorPersistence.loadColorPalette(forKey: DefaultsKeys.penPalette) {
      penPalette = loadedPalette
    }
    if let loadedColor = ColorPersistence.loadColor(forKey: DefaultsKeys.penColor) {
      penColor = loadedColor
    }

    // Load marker palette and color
    if let loadedPalette = ColorPersistence.loadColorPalette(forKey: DefaultsKeys.markerPalette) {
      markerPalette = loadedPalette
    }
    if let loadedColor = ColorPersistence.loadColor(forKey: DefaultsKeys.markerColor) {
      markerColor = loadedColor
    }

    // Load dropdown custom colors
    if let loadedColors = ColorPersistence.loadColorPalette(forKey: DefaultsKeys.penDropdownCustomColors) {
      penDropdownCustomColors = loadedColors
    }
    if let loadedColors = ColorPersistence.loadColorPalette(forKey: DefaultsKeys.markerDropdownCustomColors) {
      markerDropdownCustomColors = loadedColors
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

  private func savePenPalette() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColorPalette(penPalette, forKey: DefaultsKeys.penPalette)
  }

  private func savePenColor() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColor(penColor, forKey: DefaultsKeys.penColor)
  }

  private func saveMarkerPalette() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColorPalette(markerPalette, forKey: DefaultsKeys.markerPalette)
  }

  private func saveMarkerColor() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColor(markerColor, forKey: DefaultsKeys.markerColor)
  }

  private func savePenDropdownCustomColors() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColorPalette(penDropdownCustomColors, forKey: DefaultsKeys.penDropdownCustomColors)
  }

  private func saveMarkerDropdownCustomColors() {
    guard !isLoadingFromDefaults else { return }
    ColorPersistence.saveColorPalette(markerDropdownCustomColors, forKey: DefaultsKeys.markerDropdownCustomColors)
  }
}

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool
  var note: Note
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var toolState = ToolState()
  @StateObject private var autoStrokeManager = AutoStrokeRecognitionManager_v2()
  @ObservedObject private var preferencesManager = PreferencesManager.shared
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

  // Applied cap for PencilKit bitmap eraser radius to match UI expectations
  private let eraserBitmapMaxWidth: CGFloat = 120.0

  var body: some View {
    HStack {
      // Left side buttons (swap based on left-hand mode)
      if preferencesManager.noteEditorLeftHandMode {
        rightSideButtons
      } else {
        leftSideButtons
      }

      // Flexible spacer to center the main toolbar content
      Spacer()

      // Centered toolbar content - two equal-width sections
      HStack(spacing: 12) {
        // Tool buttons (icons only) - ordered by settings
        toolButtonsView
        Divider()
          .frame(height: 24)

        // Shape recognition toggle removed

        // Options panel for the current tool - fixed width to prevent movement
        if let activeTool = currentTool {
          toolOptionsPanel(for: activeTool)
            .frame(width: 320) // Fixed width to match tool buttons section
            .clipped()
        }
      }

      // Flexible spacer to balance the left side
      Spacer()

      // Right side buttons (swap based on left-hand mode)
      if preferencesManager.noteEditorLeftHandMode {
        leftSideButtons
      } else {
        rightSideButtons
      }
    }
    .padding(.horizontal, 12)  // Reduced from 20 to prevent overflow
    .padding(.vertical, 8)
    .frame(height: 40)
    .buttonStyle(PlainButtonStyle())
    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
    .clipped()
    .onAppear {
      // Ensure we start with a known tool/color instead of any remembered system default
      if currentTool == nil || !(isToolEnabled(currentTool!)) {
        currentTool = firstEnabledTool() ?? .pen
      }
      updateCanvasTool()
      startUndoRedoTimer()
      // Sync auto stroke recognition settings with tool state
      syncAutoStrokeSettings()
      // Attach auto stroke manager to current canvas
      if currentPage < canvasViews.count {
        autoStrokeManager.attachToCanvas(canvasViews[currentPage])
      }
      // Sync auto stroke settings (includes shape tool enabling)
      syncAutoStrokeSettings()
    }
    .onDisappear {
      stopUndoRedoTimer()
    }
    .onChange(of: currentPage) { _, _ in
      updateCanvasTool()
      updateUndoRedoState()
      // Attach auto stroke manager to new canvas
      if currentPage < canvasViews.count {
        autoStrokeManager.attachToCanvas(canvasViews[currentPage])
      }
    }
    .onChange(of: currentTool) { _, _ in
      // Collapse dropdowns when switching tools and re-apply tool
      expandedPenPresetIndex = nil
      expandedMarkerPresetIndex = nil
      expandedEraserPresetIndex = nil
      updateCanvasTool()

      // Sync auto stroke settings (includes shape tool enabling)
      syncAutoStrokeSettings()

      // Re-attach to canvas when switching to shape tool to ensure fresh state
      if currentTool == .shape && currentPage < canvasViews.count {
        autoStrokeManager.attachToCanvas(canvasViews[currentPage])
      }
    }
    .onChange(of: showImagePicker) { oldValue, newValue in
      // Keep the photo tool selected when picker opens/closes
      // User can manually select another tool if they want
    }
    .onChange(of: toolState.isAutoStrokeRecognitionEnabled) { _, _ in
      syncAutoStrokeSettings()
    }
    .onChange(of: toolState.longPressThreshold) { _, _ in
      syncAutoStrokeSettings()
    }
    .onChange(of: toolState.strokeRecognitionSensitivity) { _, _ in
      syncAutoStrokeSettings()
    }
    .onChange(of: currentPage < canvasViews.count ? canvasViews[currentPage].drawing : PKDrawing()) { _, _ in
      // Notify auto stroke manager when drawing changes
      autoStrokeManager.onDrawingChanged()
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

  // MARK: - Left/Right Side Button Groups
  @ViewBuilder
  private var leftSideButtons: some View {
    HStack(spacing: 12) {
      Button(action: {
        toggleBookmarkForCurrentPage()
      }) {
        Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
          .foregroundColor(
            colorScheme == .dark ? .matchadark_dark : .matchadark_light)
      }

      Button(action: {
        showPageOverview = true
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor((colorScheme == .dark ? .matchadark_dark : .matchadark_light))
      }
    }
  }
  
  @ViewBuilder
  private var rightSideButtons: some View {
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

  @ViewBuilder
  private func toolOptionsPanel(for tool: PenTool) -> some View {
    switch tool {
    case .pen:
      HStack(spacing: 12) {
        // Width presets with dropdown segmented control
        HStack(spacing: 12) {
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
                    // Fixed outer circle frame to prevent layout shifts
                    Circle()
                      .fill(Color.gray.opacity(0.1))
                      .frame(width: 32, height: 32)
                    
                    // Inner circle that changes size based on tool width
                    Circle()
                      .fill(
                        toolState.selectedPenPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 10),
                        height: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 10)
                      )
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
                      Text("Width: \(String(format: "%.1f", toolState.penWidthPresets[i]))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    
                    let binding = Binding<CGFloat>(
                      get: { toolState.penWidthPresets[i] },
                      set: { newValue in
                        toolState.penWidthPresets[i] = newValue
                        if toolState.selectedPenPresetIndex == i { updateCanvasTool() }
                      }
                    )
                    Slider(value: binding, in: 0.5...10, step: 0.25)
                      .frame(width: 200)
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
          }
        }
        
        Divider()
          .frame(height: 20)
        
        // Colors (with delete and add) - Scrollable with max width
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(Array(toolState.penPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                  .fill(color)
                  .frame(width: 20, height: 20)
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
                                    .font(.system(size: 20))
              }
              .popover(isPresented: $showPenColorPicker) {
                ColorPickerDropdown(
                  selectedColor: $newPenColor,
                  customColors: $toolState.penDropdownCustomColors,
                  onColorSelected: { color in
                    addPenColor(color)
                    showPenColorPicker = false
                  }
                )
              }
            }
            .padding(.horizontal, 4)
          }
          .frame(maxWidth: 240)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
            }
          )
      }

    case .marker:
      HStack(spacing: 12) {
        // Width presets with dropdown segmented control
        HStack(spacing: 12) {
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
                    // Fixed outer circle frame to prevent layout shifts
                    Circle()
                      .fill(Color.gray.opacity(0.1))
                      .frame(width: 32, height: 32)
                    
                    // Inner circle that changes size based on tool width
                    Circle()
                      .fill(
                        toolState.selectedMarkerPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: highlighterDotDiameter(for: toolState.markerWidthPresets[i], maxRange: 30),
                        height: highlighterDotDiameter(for: toolState.markerWidthPresets[i], maxRange: 30)
                      )
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
                      Text("Width: \(String(format: "%.1f", toolState.markerWidthPresets[i]))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    
                    let binding = Binding<CGFloat>(
                      get: { toolState.markerWidthPresets[i] },
                      set: { newValue in
                        toolState.markerWidthPresets[i] = newValue
                        if toolState.selectedMarkerPresetIndex == i { updateCanvasTool() }
                      }
                    )
                    Slider(value: binding, in: 0.5...20, step: 0.5)
                      .frame(width: 200)
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
          }
        }
        
        Divider()
          .frame(height: 20)
        
        // Colors (with delete and add) - Scrollable with max width
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(Array(toolState.markerPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                  .fill(color)
                  .frame(width: 20, height: 20)
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
                                .font(.system(size: 20))
              }
              .popover(isPresented: $showMarkerColorPicker) {
                ColorPickerDropdown(
                  selectedColor: $newMarkerColor,
                  customColors: $toolState.markerDropdownCustomColors,
     
                  onColorSelected: { color in
                    addMarkerColor(color)
                    showMarkerColorPicker = false
                  }
                )
              }
            }
            .padding(.horizontal, 4)
          }
          .frame(maxWidth: 220)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
            }
          )
      }

    case .eraser:
      HStack(spacing: 12) {
        // Eraser type select
        HStack(spacing: 6) {
          ForEach(EraserType.allCases, id: \.self) { type in
            Button(action: {
              toolState.eraserType = type
              withAnimation { expandedEraserPresetIndex = nil }
              updateCanvasTool()
            }) {
              Image(type.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .opacity(toolState.eraserType == type ? 1.0 : 0.5)
                .foregroundColor(toolState.eraserType == type ? (colorScheme == .dark ? .white : .black) : (colorScheme == .dark ? .gray : .gray))
            }
          }
        }

        // Fixed width container to prevent toolbar movement
        HStack(spacing: 12) {
          if toolState.eraserType == .area {
            // Area eraser: three quick presets with dropdown slider (capped)
            HStack(spacing: 12) {
              ForEach(0..<toolState.eraserAreaWidthPresets.count, id: \.self) { i in
                Button {
                  if toolState.selectedEraserAreaPresetIndex != i {
                    toolState.selectedEraserAreaPresetIndex = i
                    withAnimation { expandedEraserPresetIndex = nil }
                    updateCanvasTool()
                  } else {
                    withAnimation {
                      expandedEraserPresetIndex = (expandedEraserPresetIndex == i ? nil : i)
                    }
                  }
                } label: {
                  ZStack {
    
                    // Inner circle that changes size based on tool width
                    Circle()
                      .fill(
                        toolState.selectedEraserAreaPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: toolState.eraserAreaDotSizes[safe: i]
                          ?? dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: eraserBitmapMaxWidth),
                        height: toolState.eraserAreaDotSizes[safe: i]
                          ?? dotDiameter(for: toolState.eraserAreaWidthPresets[i], maxRange: eraserBitmapMaxWidth)
                      )
                  }
                }
                .buttonStyle(PlainButtonStyle())
                .overlay(alignment: .bottom) {
                  if expandedEraserPresetIndex == i {
                    VStack(spacing: 12) {
                      HStack(spacing: 6) {
                        Image(systemName: "circle.lefthalf.filled")
                          .font(.caption)
                          .foregroundColor(.gray)
                        let binding = Binding<CGFloat>(
                          get: { toolState.eraserAreaWidthPresets[i] },
                          set: { newValue in
                            let clamped = max(4.0, min(newValue, eraserBitmapMaxWidth))
                            toolState.eraserAreaWidthPresets[i] = clamped
                            if toolState.selectedEraserAreaPresetIndex == i { updateCanvasTool() }
                          }
                        )
                        Slider(value: binding, in: 4...20, step: 1)
                          .frame(width: 200)
                      }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .offset(y: 36)
                    .onTapGesture { }
                  }
                }
              }
            }
          } else {
            // Object eraser: show text with same spacing as area eraser controls
            HStack {
              Text("Erase entire strokes")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.matchalight_dark.opacity(0.1))
            .cornerRadius(8)
          }
        }
        .frame(width: 250) // Fixed width to prevent toolbar movement
      }


    case .lasso:
      // Minimal lasso tool options
      HStack {
        Text("Selection Mode")
          .font(.caption)
          .foregroundColor(.gray)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.matchalight_dark.opacity(0.1))
      .cornerRadius(8)

    case .photo:
      HStack(spacing: 12) {
        // Camera button
        Button(action: {
          imagePickerSourceType = .camera
          pickerID = UUID()
          showImagePicker = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "camera")
              .font(.system(size: 16))
            Text("Camera")
              .font(.caption)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .foregroundColor(.white)
          .background(Color.matchalight_dark)
          .cornerRadius(6)
        }

        // Gallery button
        Button(action: {
          imagePickerSourceType = .photoLibrary
          pickerID = UUID()
          showImagePicker = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle")
              .font(.system(size: 16))
            Text("Gallery")
              .font(.caption)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.matchalight_dark)
          .foregroundColor(.white)
          .cornerRadius(6)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)

    case .textbox:
      HStack(spacing: 12) {


        // Show formatting controls when a textbox is selected
        if textBoxManager.hasSelectedTextBox {
    
          TextBoxFormattingControls(textBoxManager: textBoxManager)
        }
        else {
                  // Hint text for user
        Text("Tap anywhere to create a text box")
          .font(.caption)
          .foregroundColor(.gray)
          .padding(.horizontal, 8)
        }
      }
    case .shape:
      HStack(spacing: 12) {
        // Width presets with dropdown segmented control (same as pen)
        HStack(spacing: 12) {
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
                    // Fixed outer circle frame to prevent layout shifts
                    Circle()
                      .fill(Color.gray.opacity(0.1))
                      .frame(width: 32, height: 32)
                    
                    // Inner circle that changes size based on tool width
                    Circle()
                      .fill(
                        toolState.selectedPenPresetIndex == i
                          ? Color.matchalight_dark : Color.gray.opacity(0.5)
                      )
                      .frame(
                        width: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 10),
                        height: dotDiameter(for: toolState.penWidthPresets[i], maxRange: 10)
                      )
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
                      Text("Width: \(String(format: "%.1f", toolState.penWidthPresets[i]))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    
                    let binding = Binding<CGFloat>(
                      get: { toolState.penWidthPresets[i] },
                      set: { newValue in
                        toolState.penWidthPresets[i] = newValue
                        if toolState.selectedPenPresetIndex == i { updateCanvasTool() }
                      }
                    )
                    Slider(value: binding, in: 0.5...10, step: 0.25)
                      .frame(width: 200)
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 12)
                }
          }
        }
        
        Divider()
          .frame(height: 20)
        
        // Colors (same as pen)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(Array(toolState.penPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                  .fill(color)
                  .frame(width: 20, height: 20)
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
                            .font(.system(size: 20))
              }
              .popover(isPresented: $showPenColorPicker) {
                ColorPickerDropdown(
                  selectedColor: $newPenColor,
                  customColors: $toolState.penDropdownCustomColors,

                  onColorSelected: { color in
                    addPenColor(color)
                    showPenColorPicker = false
                  }
                )
              }
            }
            .padding(.horizontal, 4)
          }
          .frame(maxWidth: 220)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 8)
            }
          )
      }
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
      let requestedWidth =
        toolState.eraserType == .area
        ? toolState.eraserAreaWidthPresets[safe: toolState.selectedEraserAreaPresetIndex] ?? 16.0
        : 1.0
      // Clamp to a safe maximum so PencilKit behavior aligns with UI
      let appliedWidth = min(requestedWidth, eraserBitmapMaxWidth)
      canvas.tool = tool.toolInstance(width: appliedWidth, eraserType: toolState.eraserType)
    case .lasso:
      canvas.tool = tool.toolInstance()
    case .photo:
      canvas.tool = tool.toolInstance()
    case .textbox:
      canvas.tool = tool.toolInstance()
    case .shape:
      let width = toolState.penWidthPresets[safe: toolState.selectedPenPresetIndex] ?? 3.0
      canvas.tool = tool.toolInstance(color: toolState.penColor, width: width)
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
    let minDiam: CGFloat = 6
    let maxDiam: CGFloat = 26
    let clamped = max(0.5, min(width, maxRange))
    // Use linear scaling to better represent actual pen widths
    let fraction = clamped / maxRange
    return minDiam + fraction * (maxDiam - minDiam)
  }
  
  // Map a highlighter width to a visually distinct diameter for the preset dot
  private func highlighterDotDiameter(for width: CGFloat, maxRange: CGFloat) -> CGFloat {
    let minDiam: CGFloat = 8
    let maxDiam: CGFloat = 26
    let clamped = max(0.5, min(width, maxRange))
    // Use square root scaling for highlighter to better show size differences
    let fraction = sqrt(clamped / maxRange)
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
    // Reduce polling frequency to cut CPU usage
    undoRedoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
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

  // MARK: - Auto Stroke Recognition Methods

  private func syncAutoStrokeSettings() {
    // Only enable auto stroke recognition for shape tool
    autoStrokeManager.isEnabled = (currentTool == .shape)
    // Don't override longPressThreshold and sensitivity - let them use stored UserDefaults values
  }

  // MARK: - TextBox Handling Methods
  // TextBox creation is now handled by tapping on the canvas when textbox tool is active

  // Determine first enabled tool based on user preferences
  private func firstEnabledTool() -> PenTool? {
    let orderedTools: [PenTool] = preferencesManager.noteEditorToolsOrder.compactMap { id in toolFromId(id) }
    for tool in (orderedTools.isEmpty ? [.pen, .marker, .eraser, .lasso, .photo, .textbox, .shape] : orderedTools) {
      if isToolEnabled(tool) {
        return tool
      }
    }
    return nil
  }

  // Check if a given tool is enabled in preferences
  private func isToolEnabled(_ tool: PenTool) -> Bool {
    switch tool {
    case .pen: return preferencesManager.noteEditorToolPen
    case .marker: return preferencesManager.noteEditorToolMarker
    case .eraser: return preferencesManager.noteEditorToolEraser
    case .lasso: return preferencesManager.noteEditorToolLasso
    case .photo: return preferencesManager.noteEditorToolPhoto
    case .textbox: return preferencesManager.noteEditorToolTextbox
    case .shape: return preferencesManager.noteEditorToolShape
    }
  }

  private func isToolEnabled(_ id: String) -> Bool {
    return preferencesManager.isToolEnabled(id)
  }

  private func toolFromId(_ id: String) -> PenTool? {
    switch id {
    case "pen": return .pen
    case "marker": return .marker
    case "eraser": return .eraser
    case "lasso": return .lasso
    case "photo": return .photo
    case "textbox": return .textbox
    case "shape": return .shape
    default: return nil
    }
  }

  @ViewBuilder
  private func renderToolButton(_ id: String) -> some View {
    switch id {
    case "pen":
      Button(action: { selectTool(.pen) }) { renderPenIcon(isActive: currentTool == .pen) }
    case "marker":
      Button(action: { selectTool(.marker) }) { renderMarkerIcon(isActive: currentTool == .marker) }
    case "eraser":
      Button(action: { selectTool(.eraser) }) { renderEraserIcon(isActive: currentTool == .eraser) }
    case "lasso":
      Button(action: {
        if currentTool == .lasso { selectTool(.pen) } else { selectTool(.lasso) }
      }) { renderLassoIcon(isActive: currentTool == .lasso) }
    case "photo":
      Button(action: { previousToolBeforePhoto = currentTool; selectTool(.photo) }) { renderPhotoIcon(isActive: currentTool == .photo) }
    case "textbox":
      Button(action: { selectTool(.textbox) }) { renderTextboxIcon(isActive: currentTool == .textbox) }
    case "shape":
      Button(action: { selectTool(.shape) }) { renderShapeIcon(isActive: currentTool == .shape) }
    default:
      EmptyView()
    }
  }

  // MARK: - Tool Buttons View
  @ViewBuilder
  private var toolButtonsView: some View {
    HStack(spacing: 20) {
      ForEach(preferencesManager.noteEditorToolsOrder, id: \.self) { id in
        if isToolEnabled(id) {
          renderToolButton(id)
        }
      }
    }
  }

  // MARK: - Icon Renderers
  @ViewBuilder private func renderPenIcon(isActive: Bool) -> some View {
    if isActive {
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

  @ViewBuilder private func renderMarkerIcon(isActive: Bool) -> some View {
    if isActive {
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

  @ViewBuilder private func renderEraserIcon(isActive: Bool) -> some View {
    if isActive {
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

  @ViewBuilder private func renderLassoIcon(isActive: Bool) -> some View {
    if isActive {
      Image("lasso_fill")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
    } else {
      Image("lasso_outline")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .foregroundColor(colorScheme == .dark ? .gray : .black)
    }
  }

  @ViewBuilder private func renderPhotoIcon(isActive: Bool) -> some View {
    if isActive {
      Image("photo_fill")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
    } else {
      Image("photo_outline")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .foregroundColor(colorScheme == .dark ? .gray : .black)
    }
  }

  @ViewBuilder private func renderTextboxIcon(isActive: Bool) -> some View {
    if isActive {
      Image("textbox_fill")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
    } else {
      Image("textbox_outline")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .foregroundColor(colorScheme == .dark ? .gray : .black)
    }
  }

  @ViewBuilder private func renderShapeIcon(isActive: Bool) -> some View {
    if isActive {
      Image("shapes_fill")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
    } else {
      Image("shapes_outline")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .foregroundColor(colorScheme == .dark ? .gray : .black)
    }
  }
}

// MARK: - Color Picker Dropdown Component
struct ColorPickerDropdown: View {
  @Binding var selectedColor: Color
  @Binding var customColors: [Color]
  var onColorSelected: (Color) -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var currentPage: Int = 0
  @State private var isExpanded: Bool = false

  // Track which button opened the picker
  enum PickerSource {
    case paintpalette  // Adds to toolbar
    case plusButton    // Adds to dropdown palette
  }
  @State private var pickerSource: PickerSource = .plusButton

  // Custom color picker state (HSB values)
  @State private var hue: Double = 0.5
  @State private var saturation: Double = 1.0
  @State private var brightness: Double = 1.0

  // Define predefined color pages
  private let predefinedColors: [Color] = [
    // Row 1
    .yellow, .orange, .red, Color(red: 1.0, green: 0.0, blue: 1.0), // magenta
    Color(red: 0.5, green: 1.0, blue: 0.0), // lime
    .green, .purple, Color(red: 0.5, green: 0.0, blue: 0.5), // dark purple
    // Row 2
    Color(red: 0.0, green: 0.5, blue: 0.5), // teal
    .blue, Color(red: 0.25, green: 0.41, blue: 0.88), // royal blue
    Color(red: 0.0, green: 0.0, blue: 0.5), // navy
    .white, .gray, .black, Color(red: 0.6, green: 0.4, blue: 0.2) // brown
  ]

  // Computed property to combine predefined and custom colors into pages
  private var colorPages: [[Color]] {
    var pages: [[Color]] = []
    var allColors = predefinedColors + customColors

    while !allColors.isEmpty {
      let pageColors = Array(allColors.prefix(15))
      pages.append(pageColors)
      allColors = Array(allColors.dropFirst(15))
    }

    return pages.isEmpty ? [[]] : pages
  }

  private var customColor: Color {
    Color(hue: hue, saturation: saturation, brightness: brightness)
  }

  var body: some View {
    VStack(spacing: 12) {
      // Header with title and icon
      HStack(spacing: 8) {
        Text("Colors")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(colorScheme == .dark ? .white : .black)

        Spacer()

        Button(action: {
          pickerSource = .paintpalette
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: "paintpalette.fill")
            .font(.system(size: 18))
            .foregroundColor(.matchalight_dark)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // Color grid - two rows with smooth paging
      TabView(selection: $currentPage) {
        ForEach(0..<colorPages.count, id: \.self) { pageIndex in
          VStack(spacing: 12) {
            // Row 1
            HStack(spacing: 12) {
              ForEach(0..<8, id: \.self) { col in
                colorSwatch(at: col, page: pageIndex)
              }
            }

            // Row 2 (7 colors + plus button)
            HStack(spacing: 12) {
              ForEach(8..<15, id: \.self) { col in
                colorSwatch(at: col, page: pageIndex)
              }

              // Plus button to expand custom color picker
              Button(action: {
                pickerSource = .plusButton
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  isExpanded.toggle()
                }
              }) {
                ZStack {
                  Circle()
                    .stroke(Color.matchalight_dark, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 32, height: 32)

                  Image(systemName: isExpanded ? "minus" : "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.matchalight_dark)
                }
              }
              .buttonStyle(PlainButtonStyle())
              .contentShape(Circle().size(width: 40, height: 40))
            }
          }
          .padding(.horizontal, 16)
          .tag(pageIndex)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: 88)

      // Custom color picker section (expanded)
      if isExpanded {
        VStack(spacing: 16) {
          Divider()

          // 2D Color Picker Area
          GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
              // Background gradient (saturation + brightness)
              LinearGradient(
                gradient: Gradient(colors: [
                  .white,
                  Color(hue: hue, saturation: 1.0, brightness: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .overlay(
                LinearGradient(
                  gradient: Gradient(colors: [.clear, .black]),
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .cornerRadius(8)

              // Selector circle
              Circle()
                .strokeBorder(Color.white, lineWidth: 3)
                .background(Circle().fill(customColor))
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.3), radius: 2)
                .position(
                  x: saturation * geometry.size.width,
                  y: (1 - brightness) * geometry.size.height
                )
            }
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  saturation = min(max(value.location.x / geometry.size.width, 0), 1)
                  brightness = 1 - min(max(value.location.y / geometry.size.height, 0), 1)
                }
            )
          }
          .frame(height: 180)
          .padding(.horizontal, 16)

          // Hue slider
          VStack(spacing: 8) {
            HStack {
              Text("Hue")
                .font(.system(size: 11))
                .foregroundColor(.gray)
              Spacer()
              Circle()
                .fill(customColor)
                .frame(width: 24, height: 24)
                .overlay(
                  Circle()
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            Slider(value: $hue, in: 0...1)
              .accentColor(Color(hue: hue, saturation: 1.0, brightness: 1.0))
          }
          .padding(.horizontal, 16)

          // Add button
          Button(action: {
            if pickerSource == .paintpalette {
              // Add to toolbar
              onColorSelected(customColor)
            } else {
              // Add to dropdown palette
              addCustomColorToDropdown()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              isExpanded = false
            }
          }) {
            Text(pickerSource == .paintpalette ? "Add to Toolbar" : "Add to Palette")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(Color.matchalight_dark)
              .cornerRadius(8)
          }
          .buttonStyle(PlainButtonStyle())
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
        }
        .transition(.opacity)
      }

      // Pagination dots (if multiple pages in the future)
      if colorPages.count > 1 {
        HStack(spacing: 6) {
          ForEach(0..<colorPages.count, id: \.self) { index in
            Button(action: {
              withAnimation(.easeInOut(duration: 0.2)) {
                currentPage = index
              }
            }) {
              Circle()
                .fill(currentPage == index ? Color.matchalight_dark : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(.bottom, 16)
      } else {
        Spacer().frame(height: 8)
      }
    }
    .frame(width: 360)
    .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
  }

  // Add custom color to the dropdown palette
  private func addCustomColorToDropdown() {
    customColors.append(customColor)
  }

  @ViewBuilder
  private func colorSwatch(at index: Int, page: Int) -> some View {
    if index < colorPages[page].count {
      let color = colorPages[page][index]
      let isSelected = colorsAreEqual(selectedColor, color)

      Button(action: {
        selectedColor = color
        onColorSelected(color)
      }) {
        ZStack {
          Circle()
            .fill(color)
            .frame(width: 32, height: 32)

          // Border for white color visibility
          if color == .white {
            Circle()
              .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
              .frame(width: 32, height: 32)
          }

          // Checkmark for selected color
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(colorIsDark(color) ? .white : .black)
              .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
    } else {
      Circle()
        .fill(Color.clear)
        .frame(width: 32, height: 32)
    }
  }

  // Helper to compare colors
  private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
    let uiColor1 = UIColor(color1)
    let uiColor2 = UIColor(color2)

    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

    uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

    return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
  }

  // Helper to determine if color is dark (for checkmark visibility)
  private func colorIsDark(_ color: Color) -> Bool {
    let uiColor = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    // Calculate luminance
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    return luminance < 0.5
  }
}

// Safe index extension
extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    guard indices.contains(index) else { return nil }
    return self[index]
  }
}

