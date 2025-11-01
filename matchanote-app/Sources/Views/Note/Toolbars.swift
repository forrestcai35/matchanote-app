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
  case ruler

  func toolInstance(color: Color = .black, width: CGFloat = 1.0, eraserType: EraserType = .object)
    -> PKTool
  {
    switch self {
    case .pen:
      return PKInkingTool(.monoline, color: UIColor(color), width: width)
    case .marker:
      // Simplified: always use monoline with semi-transparent color for consistent width
      return PKInkingTool(
        .monoline,
        color: UIColor(color).withAlphaComponent(0.4),
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
    case .ruler:
      // Ruler is not a PKTool; toggling handled via PKCanvasView.isRulerActive
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

  // Use SF Symbols for distinct eraser types
  var icon: String {
    switch self {
    case .object: return "stroke.line.diagonal.slash"
    case .area: return "circle.fill"
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
    static let markerStraightLineEnabled = "tool.markerStraightLineEnabled"
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

  // Marker mode removed; we use a single monoline marker. Only straight-lines toggle remains.

  // Marker straight line toggle
  @Published var markerStraightLineEnabled: Bool = false {
    didSet {
      UserDefaults.standard.set(markerStraightLineEnabled, forKey: DefaultsKeys.markerStraightLineEnabled)
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

    markerStraightLineEnabled = defaults.object(forKey: DefaultsKeys.markerStraightLineEnabled) as? Bool ?? false

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

  // Callback to trigger save before PageOverviewView opens
  var saveCallback: (() -> Void)?

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
  @State private var showEraserTypeDropdown = false
  @State private var showMarkerModeDropdown = false
  @State private var showPenSubtoolDropdown = false
  // Pen subtool selection (Pen vs Pencil)
  private enum PenSubtool { case pen, pencil }
  @State private var selectedPenSubtool: PenSubtool = .pen
  // Ruler active flag to refresh UI
  @State private var isRulerActiveState: Bool = false
  private let penSubtoolDefaultsKey = "tool.penSubtool.selected"
  private let rulerActiveDefaultsKey = "tool.rulerActive"

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
            .frame(width: 360, alignment: .leading) // Left-align contents within fixed width
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
    .background(colorScheme == .dark ? Color.toolbar_background_dark : Color.toolbar_background_light)
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
      // Apply persisted ruler state across canvases
      if currentPage < canvasViews.count {
        let persisted = UserDefaults.standard.object(forKey: rulerActiveDefaultsKey) as? Bool ?? false
        let canvasesToUpdate = preferencesManager.noteEditorVerticalScrollMode ? canvasViews : [canvasViews[currentPage]]
        for canvas in canvasesToUpdate {
          canvas.isRulerActive = persisted
        }
        isRulerActiveState = persisted
      }
      // Load persisted pen/pencil subtool selection
      loadPersistedPenSubtoolSelection()
      if currentTool == .pen { updateCanvasTool() }
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
      // Update ruler state to match current canvas
      if currentPage < canvasViews.count {
        isRulerActiveState = canvasViews[currentPage].isRulerActive
      }
    }
    .onChange(of: selectedPenSubtool) { _, _ in
      persistPenSubtoolSelection()
    }
    .onChange(of: currentTool) { _, _ in
      // Collapse dropdowns when switching tools and re-apply tool
      expandedPenPresetIndex = nil
      expandedMarkerPresetIndex = nil
      expandedEraserPresetIndex = nil
      updateCanvasTool()

      // Sync auto stroke settings (includes shape tool enabling)
      syncAutoStrokeSettings()

      // Re-attach to canvas when switching to shape or marker (with straight lines) to ensure fresh state
      if (currentTool == .shape || (currentTool == .marker && toolState.markerStraightLineEnabled))
        && currentPage < canvasViews.count
      {
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
    // Marker mode removed
    .onChange(of: toolState.markerStraightLineEnabled) { _, _ in
      syncAutoStrokeSettings()
      // Re-attach to canvas when enabling straight lines to ensure fresh state
      if toolState.markerStraightLineEnabled && currentPage < canvasViews.count {
        autoStrokeManager.attachToCanvas(canvasViews[currentPage])
      }
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
    .onChange(of: showPageOverview) { _, isShowing in
      if isShowing {
        // Save current drawing data before showing PageOverviewView
        saveCallback?()
      }
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
                        .font(.jost(.caption()))
                        .foregroundColor(.gray)
                      Text("Width: \(String(format: "%.1f", toolState.penWidthPresets[i]))")
                        .font(.jost(.caption()))
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
        
        // Colors (with delete and add) - hidden when Pencil selected
        if selectedPenSubtool == .pen {
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
            .padding(.horizontal, 8)
          }
          .frame(maxWidth: 260)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
            }
          )
        }
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
                        .font(.jost(.caption()))
                        .foregroundColor(.gray)
                      Text("Width: \(String(format: "%.1f", toolState.markerWidthPresets[i]))")
                        .font(.jost(.caption()))
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
            .padding(.horizontal, 8)
          }
          .frame(maxWidth: 240)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
            }
          )
      }

    case .eraser:
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
                      .font(.jost(.caption()))
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
        .frame(width: 250) // Fixed width to prevent toolbar movement
      } else {
        // Object eraser: show text and span full options width
        HStack {
          Text("Erase entire strokes")
            .font(.jost(.caption()))
            .foregroundColor(colorScheme == .dark ? .white : .gray)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.matchalight_dark.opacity(0.1))
        .cornerRadius(8)
      }


    case .lasso:
      // Minimal lasso tool options
      HStack {
        Text("Selection Mode")
          .font(.jost(.caption()))
          .foregroundColor(.gray)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
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
              .font(.jost(.caption()))
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
              .font(.jost(.caption()))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.matchalight_dark)
          .foregroundColor(.white)
          .cornerRadius(6)
        }
      }
      // Left-aligned, background hugs content
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
            .font(.jost(.caption()))
            .foregroundColor(.gray)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(.jost(.caption()))
                        .foregroundColor(.gray)
                      Text("Width: \(String(format: "%.1f", toolState.penWidthPresets[i]))")
                        .font(.jost(.caption()))
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
            .padding(.horizontal, 8)
          }
          .frame(maxWidth: 260)
          .mask(
            HStack(spacing: 0) {
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
              
              Rectangle()
                .fill(Color.black)
              
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: 6)
            }
          )
      }

    case .ruler:
      // Minimal options panel to match other tools
      HStack {
        Text("Ruler active")
          .font(.jost(.caption()))
          .foregroundColor(.gray)
      }
      // Left-aligned, background hugs content
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
    let currentCanvas = canvasViews[currentPage]

    // Ensure image manager has the correct undo manager
    imageManager.setUndoManager(currentCanvas.undoManager)

    // Ensure textbox manager has the correct undo manager
    textBoxManager.setUndoManager(currentCanvas.undoManager)

    // In vertical scroll mode, all canvases are visible, so update all of them
    // In page mode, only update the current canvas
    let canvasesToUpdate = preferencesManager.noteEditorVerticalScrollMode ? canvasViews : [currentCanvas]

    for canvas in canvasesToUpdate {
      switch tool {
      case .pen:
        let width = toolState.penWidthPresets[safe: toolState.selectedPenPresetIndex] ?? 3.0
        if selectedPenSubtool == .pencil {
          canvas.tool = PKInkingTool(.pencil, color: UIColor(toolState.penColor), width: width)
        } else {
          canvas.tool = tool.toolInstance(color: toolState.penColor, width: width)
        }
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
      case .ruler:
        // Keep non-inking tool while ruler is active
        canvas.tool = tool.toolInstance()
      }
    }
  }

  // MARK: - Pen subtool persistence
  private func loadPersistedPenSubtoolSelection() {
    let raw = UserDefaults.standard.string(forKey: penSubtoolDefaultsKey) ?? "pen"
    selectedPenSubtool = (raw == "pencil") ? .pencil : .pen
  }

  private func persistPenSubtoolSelection() {
    let raw = (selectedPenSubtool == .pencil) ? "pencil" : "pen"
    UserDefaults.standard.set(raw, forKey: penSubtoolDefaultsKey)
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
    // Enable auto stroke recognition for shape tool OR marker with straight lines enabled
    let shouldEnableRecognition = (currentTool == .shape) ||
                                  (currentTool == .marker && toolState.markerStraightLineEnabled)
    autoStrokeManager.isEnabled = shouldEnableRecognition
    // Restrict recognition to lines when using marker straight lines; allow all shapes for shape tool
    autoStrokeManager.restrictToLinesOnly = (currentTool == .marker && toolState.markerStraightLineEnabled)
    // Don't override longPressThreshold and sensitivity - let them use stored UserDefaults values
  }

  // MARK: - TextBox Handling Methods
  // TextBox creation is now handled by tapping on the canvas when textbox tool is active

  // Determine first enabled tool based on user preferences
  private func firstEnabledTool() -> PenTool? {
    let orderedTools: [PenTool] = preferencesManager.noteEditorToolsOrder.compactMap { id in toolFromId(id) }
    for tool in (orderedTools.isEmpty ? [.pen, .marker, .eraser, .lasso, .photo, .textbox, .shape, .ruler] : orderedTools) {
      // Skip ruler for default drawing tool selection
      if tool != .ruler && isToolEnabled(tool) {
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
    case .ruler: return preferencesManager.noteEditorToolRuler
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
    case "ruler": return .ruler
    default: return nil
    }
  }

  @ViewBuilder
  private func renderToolButton(_ id: String) -> some View {
    switch id {
    case "pen":
      Button(action: {
        if currentTool == .pen {
          showPenSubtoolDropdown.toggle()
        } else {
          selectTool(.pen)
        }
      }) { renderPenIcon(isActive: currentTool == .pen) }
      .popover(isPresented: $showPenSubtoolDropdown) {
        VStack(spacing: 8) {
          Button(action: {
            selectedPenSubtool = .pen
            showPenSubtoolDropdown = false
            updateCanvasTool()
          }) {
            HStack {
              renderPenSubIcon(isActive: selectedPenSubtool == .pen)
                .frame(width: 20, height: 20)
              Text("Pen")
                .foregroundColor(colorScheme == .dark ? .white : .black)
              Spacer()
              if selectedPenSubtool == .pen { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          }
          .buttonStyle(PlainButtonStyle())

          Button(action: {
            selectedPenSubtool = .pencil
            showPenSubtoolDropdown = false
            updateCanvasTool()
          }) {
            HStack {
              renderPencilSubIcon(isActive: selectedPenSubtool == .pencil)
                .frame(width: 20, height: 20)
              Text("Pencil")
                .foregroundColor(colorScheme == .dark ? .white : .black)
              Spacer()
              if selectedPenSubtool == .pencil { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          }
          .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .frame(width: 160)
      }
    case "marker":
      Button(action: {
        if currentTool == .marker {
          // If already active, show marker options (straight line toggle)
          showMarkerModeDropdown.toggle()
        } else {
          // If not active, select the marker tool
          selectTool(.marker)
        }
      }) { renderMarkerIcon(isActive: currentTool == .marker) }
      .popover(isPresented: $showMarkerModeDropdown) {
        VStack(spacing: 8) {
          // Straight line toggle
          HStack {
            Image(systemName: "line.diagonal")
              .resizable()
              .scaledToFit()
              .frame(width: 20, height: 20)
              .foregroundColor(colorScheme == .dark ? .white : .black)
            Text("Straight Lines")
              .foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
            Toggle("", isOn: Binding(
              get: { toolState.markerStraightLineEnabled },
              set: { newValue in
                toolState.markerStraightLineEnabled = newValue
                updateCanvasTool()
              }
            ))
            .labelsHidden()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        }
        .padding(8)
        .frame(width: 200)
      }
    case "eraser":
      Button(action: {
        if currentTool == .eraser {
          // If already active, show dropdown to switch eraser type
          showEraserTypeDropdown.toggle()
        } else {
          // If not active, select the eraser tool
          selectTool(.eraser)
        }
      }) { renderEraserIcon(isActive: currentTool == .eraser) }
      .popover(isPresented: $showEraserTypeDropdown) {
        VStack(spacing: 8) {
          ForEach(EraserType.allCases, id: \.self) { type in
            Button(action: {
              toolState.eraserType = type
              showEraserTypeDropdown = false
              updateCanvasTool()
            }) {
              HStack {
                Image(systemName: type.icon)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 20, height: 20)
                  .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(type.displayName)
                  .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                if toolState.eraserType == type {
                  Image(systemName: "checkmark")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(8)
        .frame(width: 150)
      }
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
    case "ruler":
      Button(action: { toggleRuler() }) { renderRulerIcon(isActive: isRulerActiveState) }
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
    let usePencil = (selectedPenSubtool == .pencil)
    if isActive {
      ZStack {
        if usePencil {
          if let fillImage = UIImage(named: "pencil_fill") {
            Image(uiImage: fillImage)
              .renderingMode(.original)
              .resizable()
              .scaledToFit()
              .frame(width: 26, height: 26)
          }
        
        } else {
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
      }
    } else {
      if usePencil {
        Image("pencil_outline")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 26, height: 26)
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      } else {
        Image("pen_outline")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 26, height: 26)
          .foregroundColor(colorScheme == .dark ? .gray : .black)
      }
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

  // Suboption icons (dropdown): always outline for Pen/Pencil
  @ViewBuilder private func renderPenSubIcon(isActive: Bool) -> some View {
    Image("pen_outline")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: 26, height: 26)
      .foregroundColor(colorScheme == .dark ? .white : .black)
  }

  @ViewBuilder private func renderPencilSubIcon(isActive: Bool) -> some View {
    Image("pencil_outline")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: 26, height: 26)
      .foregroundColor(colorScheme == .dark ? .white : .black)
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

  // Ruler icon renderer
  @ViewBuilder private func renderRulerIcon(isActive: Bool) -> some View {
    if isActive {
      Image("ruler_fill")
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
    } else {
      Image("ruler_outline")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 26, height: 26)
        .foregroundColor(colorScheme == .dark ? .gray : .black)
    }
  }

  private var isRulerActive: Bool {
    guard currentPage < canvasViews.count else { return false }
    return canvasViews[currentPage].isRulerActive
  }

  private func toggleRuler() {
    guard currentPage < canvasViews.count else { return }
    let newState = !isRulerActive
    let canvasesToUpdate = preferencesManager.noteEditorVerticalScrollMode ? canvasViews : [canvasViews[currentPage]]
    for canvas in canvasesToUpdate {
      canvas.isRulerActive = newState
    }
    isRulerActiveState = newState
    UserDefaults.standard.set(newState, forKey: rulerActiveDefaultsKey)
  }
}

// Safe index extension
extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    guard indices.contains(index) else { return nil }
    return self[index]
  }
}
