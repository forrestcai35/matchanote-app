import PencilKit
import SwiftDown
import SwiftUI
import UIKit

// Written Note View with PencilKit
struct WrittenNoteView: View {
  var note: Note
  @Binding var isEdited: Bool
  @Binding var toolPickerIsVisible: Bool
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?
  @State private var pageCount = 1
  @State private var toolPicker = PKToolPicker()
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager
  @ObservedObject private var tabManager = TabManager.shared
  @State private var currentNoteId: UUID?

  var body: some View {
    VStack(spacing: 0) {
      TabView(selection: $currentPage) {
        ForEach(0..<pageCount, id: \.self) { pageIndex in
          pageContent(pageIndex: pageIndex, isInfinite: false)
            .tag(pageIndex)
            .transition(
              .asymmetric(
                insertion: .opacity.combined(with: .scale),
                removal: .opacity
              ))
        }
      }
      .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
      .tabViewStyle(.page(indexDisplayMode: .never))
      .overlay(alignment: .bottomTrailing) {
        controlsOverlay
      }
    }
    .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
    .onAppear {
      // Only load if this is a different note
      if currentNoteId != note.id {
        currentNoteId = note.id
        loadDrawingData()
      }
      setupToolPicker()
    }
    .onChange(of: note.id) { _, newNoteId in
      // Note changed, load new drawing data
      if currentNoteId != newNoteId {
        saveCurrentDrawingData() // Save current note before switching
        currentNoteId = newNoteId
        loadDrawingData()
      }
    }
    .onChange(of: toolPickerIsVisible) { _, newValue in
      updateToolPickerVisibility(newValue)
    }
    .onChange(of: currentPage) { _, newPage in
      updateActiveCanvas()
    }
    .onChange(of: currentTool) { _, newTool in
      updateCanvasTool()
    }
    .onChange(of: isEdited) { _, newValue in
      if newValue {
        saveCurrentDrawingData()
      }
    }
    .onDisappear {
      // Save any unsaved drawing data when view disappears
      saveCurrentDrawingData()
    }
  }
  
  // Load drawing data when view appears
  private func loadDrawingData() {
    // Clear existing canvas views to start fresh
    canvasViews.removeAll()
    
    // Determine the number of pages based on stored drawings
    let maxPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let requiredPageCount = max(1, maxPage + 1)
    
    // Create canvas views for all required pages
    for pageIndex in 0..<requiredPageCount {
      let canvas = PKCanvasView()
      canvas.overrideUserInterfaceStyle = .light
      canvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
      canvas.isScrollEnabled = false
      canvas.backgroundColor = .clear
      
      // Load drawing data if it exists for this page
      if let drawingData = note.drawingDataByPage[String(pageIndex)] {
        do {
          let drawing = try PKDrawing(data: drawingData)
          canvas.drawing = drawing
        } catch {
          print("Error loading drawing for page \(pageIndex): \(error)")
        }
      }
      
      canvasViews.append(canvas)
    }
    
    // Update page count
    pageCount = requiredPageCount
  }
  
  // Save drawing data for the current note
  private func saveCurrentDrawingData() {
    
    var updatedNote = note
    var hasChanges = false
    
    // Create new drawing data dictionary
    var newDrawingData: [String: Data] = [:]
    
    for (index, canvas) in canvasViews.enumerated() {
      if !canvas.drawing.strokes.isEmpty {
        let drawingData = canvas.drawing.dataRepresentation()
        newDrawingData[String(index)] = drawingData
      }
    }
    
    // Quick check: if the number of pages with data changed
    if newDrawingData.keys.count != note.drawingDataByPage.keys.count {
      hasChanges = true
    } else {
      // Check if any drawing data actually changed
      for (key, newData) in newDrawingData {
        if let existingData = note.drawingDataByPage[key] {
          // Compare data sizes first for quick comparison
          if newData.count != existingData.count || newData != existingData {
            hasChanges = true
            break
          }
        } else {
          hasChanges = true
          break
        }
      }
    }
    
    // Only save if there are actual changes
    if hasChanges {
      updatedNote.drawingDataByPage = newDrawingData
      updatedNote.dateModified = Date()
      let savedNote = storageManager.saveNote(updatedNote)
      tabManager.updateNote(savedNote)
      
      // Reset edited flag
      DispatchQueue.main.async {
        isEdited = false
      }
    }
  }

  // Setup the PKToolPicker for the current canvas
  private func setupToolPicker() {
    guard let currentCanvas = getCurrentCanvas() else { return }

    // Set tool based on current selection
    if let selectedTool = currentTool {
      currentCanvas.tool = selectedTool.toolInstance()
    } else {
      // Default to pen if no tool is selected
      currentCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
    }

    // Let the PencilKit system handle drawing policies
    toolPicker.setVisible(toolPickerIsVisible, forFirstResponder: currentCanvas)
    toolPicker.addObserver(currentCanvas)

    if toolPickerIsVisible {
      currentCanvas.becomeFirstResponder()
    }
  }

  private func getCurrentCanvas() -> PKCanvasView? {
    guard currentPage < canvasViews.count else { return nil }
    return canvasViews[currentPage]
  }

  // Update active canvas when page changes
  private func updateActiveCanvas() {
    ensureCanvasExists(for: currentPage)

    // Update tool picker for the current canvas
    guard let currentCanvas = getCurrentCanvas() else { return }

    // Update visibility for current canvas
    toolPicker.setVisible(toolPickerIsVisible, forFirstResponder: currentCanvas)

    if toolPickerIsVisible {
      currentCanvas.becomeFirstResponder()
    }
  }

  // Update tool picker visibility
  private func updateToolPickerVisibility(_ isVisible: Bool) {
    guard let currentCanvas = getCurrentCanvas() else { return }

    toolPicker.setVisible(isVisible, forFirstResponder: currentCanvas)

    if isVisible {
      currentCanvas.becomeFirstResponder()
    } else {
      currentCanvas.resignFirstResponder()
    }
  }

  // Make sure a canvas exists for the given page index
  private func ensureCanvasExists(for pageIndex: Int) {
    // Add new canvases if needed
    while canvasViews.count <= pageIndex {
      let newCanvas = PKCanvasView()
      newCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
      newCanvas.overrideUserInterfaceStyle = .light
      newCanvas.isScrollEnabled = false
      newCanvas.backgroundColor = .clear
      toolPicker.addObserver(newCanvas)
      canvasViews.append(newCanvas)
    }
  }

  // Extracted Page Content View Builder
  @ViewBuilder
  private func pageContent(pageIndex: Int, isInfinite: Bool) -> some View {
    // Wrap Canvas in a GeometryReader to get parent size for centering
    GeometryReader { geometry in
      ZoomableScrollView(
        minScale: 0.8,
        maxScale: 3.0,
        resetOnDoubleTap: true
      ) {

        // Content is now fixed without scrolling

        ZStack {
          paperBackground()
          if pageIndex < canvasViews.count {
            PencilKitCanvasView(
              canvasView: canvasViews[pageIndex],
              currentTool: $currentTool,
              canvasViews: $canvasViews,
              currentPage: $currentPage
            )
              .frame(
                width: getPaperWidth(for: note.paperSize),
                height: getPaperHeight(for: note.paperSize)
              )
              .onChange(of: canvasViews[pageIndex].drawing) { _, _ in
                isEdited = true
              }
          } else {
            Text("Error: Canvas not available for page \(pageIndex + 1)")
              .foregroundColor(.red)
              .frame(
                width: getPaperWidth(for: note.paperSize),
                height: getPaperHeight(for: note.paperSize)
              )
          }
        }
      }
      .coordinateSpace(name: "scroll")
    }
  }

  @ViewBuilder
  private func paperBackground() -> some View {
    let paperBackground: Color = getPaperBackgroundColor(for: note.paperColor)
    Rectangle()
      .fill(paperBackground)
      .frame(
        width: getPaperWidth(for: note.paperSize),
        height: getPaperHeight(for: note.paperSize)
      )
      .overlay {
        GeometryReader { geometry in
          switch note.paperStyle {
          case .grid:
            gridOverlay(size: geometry.size)
          case .dotted:
            dottedOverlay(size: geometry.size)
          case .lined:
            linedOverlay(size: geometry.size)
          case .blank:
            EmptyView()
          }
        }
      }
  }

  @ViewBuilder
  private func gridOverlay(size: CGSize) -> some View {
    let gridSpacing: CGFloat = 20

    ZStack {
      // Horizontal lines
      ForEach(0..<Int(size.height / gridSpacing + 1), id: \.self) { i in
        let y = CGFloat(i) * gridSpacing
        Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
          .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
      }
      // Vertical lines
      ForEach(0..<Int(size.width / gridSpacing + 1), id: \.self) { i in
        let x = CGFloat(i) * gridSpacing
        Line(start: CGPoint(x: x, y: 0), end: CGPoint(x: x, y: size.height))
          .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
      }
    }
  }

  @ViewBuilder
  private func dottedOverlay(size: CGSize) -> some View {
    let baseSpacing: CGFloat = 18
    let dotRadius: CGFloat = 1
    let margin: CGFloat = baseSpacing

    Canvas { context, canvasSize in
      // Calculate available space after margins
      let availableWidth = canvasSize.width - 2 * margin
      let availableHeight = canvasSize.height - 2 * margin

      // Calculate number of intervals that can fit
      let horizontalIntervals = max(1, Int(availableWidth / baseSpacing))
      let verticalIntervals = max(1, Int(availableHeight / baseSpacing))

      // Calculate dynamic spacing to fill available width
      let horizontalSpacing = availableWidth / CGFloat(horizontalIntervals)
      let verticalSpacing = availableHeight / CGFloat(verticalIntervals)

      // Draw dots within margins
      for y in 0...verticalIntervals {
        for x in 0...horizontalIntervals {
          let xPos = margin + CGFloat(x) * horizontalSpacing
          let yPos = margin + CGFloat(y) * verticalSpacing
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: xPos - dotRadius,
                y: yPos - dotRadius,
                width: 2 * dotRadius,
                height: 2 * dotRadius
              )),
            with: .color(Color.gray.opacity(0.3))
          )
        }
      }
    }
    .frame(width: size.width, height: size.height)
  }

  @ViewBuilder
  private func linedOverlay(size: CGSize) -> some View {
    let lineSpacing: CGFloat = 24
    let marginTop: CGFloat = 30

    ZStack {
      ForEach(0..<Int((size.height - marginTop) / lineSpacing + 1), id: \.self) { i in
        let y = marginTop + CGFloat(i) * lineSpacing
        Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
          .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
      }
    }
  }

  // Page Control View
  @ViewBuilder
  private var controlsOverlay: some View {
    VStack(spacing: 8) {
      HStack {
        Text("\(currentPage + 1)/\(pageCount)")
          .font(.caption)
          .foregroundColor(.gray)

      }
      Button {
        pageCount += 1
        ensureCanvasExists(for: pageCount - 1)
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.caption)
          .foregroundColor(Color.matchalight_dark)
      }
    }
    .padding(8)
    .background(Color.white.opacity(0.9))
    .cornerRadius(20)
    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    .padding(16)
  }

  // Helper function for background color
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .dark:
      return Color(red: 0.1961, green: 0.1961, blue: 0.2000)
    }
  }
  // Helper functions to get paper dimensions
  private func getPaperWidth(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 612  // 8.5 x 14 inches at 72 dpi
    case .letter:
      return 612  // 8.5 x 11 inches at 72 dpi
    case .tabloid:
      return 792  // 11 x 17 inches at 72 dpi
    case .a4:
      return 595  // 210 × 297 mm at 72 dpi
    }
  }
  private func getPaperHeight(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 1008  // 8.5 x 14 inches at 72 dpi
    case .letter:
      return 792  // 8.5 x 11 inches at 72 dpi
    case .tabloid:
      return 1224  // 11 x 17 inches at 72 dpi
    case .a4:
      return 842  // 210 × 297 mm at 72 dpi
    }
  }

  // Update canvas tool when tool selection changes
  private func updateCanvasTool() {
    guard let currentCanvas = getCurrentCanvas() else { return }
    if let selectedTool = currentTool {
      currentCanvas.tool = selectedTool.toolInstance()
    } else {
      currentCanvas.tool = PKInkingTool(.pen, color: .black, width: 1.0)
    }
  }
}

// Line Shape for drawing grids and lines
struct Line: Shape {
  var start, end: CGPoint
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    return path
  }
}

// PencilKit Canvas SwiftUI wrapper
struct PencilKitCanvasView: UIViewRepresentable {
  var canvasView: PKCanvasView
  @Binding var currentTool: PenTool?
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int

  func makeUIView(context: Context) -> PKCanvasView {
    canvasView.backgroundColor = .clear
    canvasView.isScrollEnabled = false
    canvasView.overrideUserInterfaceStyle = .light
    
    // Add pencil interaction for double tap
    if UIPencilInteraction.preferredTapAction == .switchEraser {
      let pencilInteraction = UIPencilInteraction()
      pencilInteraction.delegate = context.coordinator
      canvasView.addInteraction(pencilInteraction)
    }
    
    return canvasView
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    // No custom policy updates needed
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, UIPencilInteractionDelegate {
    var parent: PencilKitCanvasView
    private var previousTool: PenTool = .pen
    
    init(_ parent: PencilKitCanvasView) {
      self.parent = parent
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
      // Handle double tap to switch between eraser and previous tool
      if let currentTool = parent.currentTool {
        if currentTool == .eraser {
          // Switch back to previous tool
          parent.currentTool = previousTool
          if parent.currentPage < parent.canvasViews.count {
            parent.canvasViews[parent.currentPage].tool = previousTool.toolInstance()
          }
        } else {
          // Store current tool and switch to eraser
          previousTool = currentTool
          parent.currentTool = .eraser
          if parent.currentPage < parent.canvasViews.count {
            parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
          }
        }
      } else {
        // If no current tool, default to pen then switch to eraser
        previousTool = .pen
        parent.currentTool = .eraser
        if parent.currentPage < parent.canvasViews.count {
          parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
        }
      }
    }
  }
}

//Markdown View
struct TextNoteView: View {
  var note: Note
  @State private var textContent: String
  @Binding var isEdited: Bool
  private let infiniteScrollHeight: CGFloat = 10000
  @Environment(\.colorScheme) private var colorScheme
  
  // Use computed property instead of @State for theme
  private var currentTheme: Theme {
    colorScheme == .dark ? Theme.BuiltIn.defaultDark.theme() : Theme.BuiltIn.defaultLight.theme()
  }
  
  init(note: Note, isEdited: Binding<Bool>) {
    self.note = note
    _textContent = State(initialValue: note.content)
    _isEdited = isEdited
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical, showsIndicators: true) {
        VStack {
          SwiftDownEditor(text: $textContent)
            .insetsSize(40)
            .theme(currentTheme)
            .scrollContentBackground(.hidden)
            .frame(minHeight: infiniteScrollHeight)
            .frame(width: 700)
            .id(colorScheme) // Force recreation when color scheme changes
            .onChange(of: textContent) { oldValue, newValue in
              if oldValue != newValue {
                isEdited = true
              }
            }

            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
        }
      }
      .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
      .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }

  // Helper function for background color
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .dark:
      return Color(red: 0.196, green: 0.196, blue: 0.200)
    }
  }

}

// Custom ZoomableScrollView that provides a much more natural zooming experience
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
  private var content: Content
  private var minScale: CGFloat
  private var maxScale: CGFloat
  private var resetOnDoubleTap: Bool

  @Binding private var currentScale: CGFloat

  // Initialize with default scale binding
  init(
    minScale: CGFloat = 1.0,
    maxScale: CGFloat = 3.0,
    resetOnDoubleTap: Bool = true,
    currentScale: Binding<CGFloat> = .constant(1.0),
    @ViewBuilder content: () -> Content
  ) {
    self.minScale = minScale
    self.maxScale = maxScale
    self.resetOnDoubleTap = resetOnDoubleTap
    self._currentScale = currentScale
    self.content = content()
  }

  func makeUIView(context: Context) -> UIScrollView {
    // Set up the UIScrollView
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator
    scrollView.maximumZoomScale = maxScale
    scrollView.minimumZoomScale = minScale
    scrollView.bouncesZoom = true
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.clipsToBounds = false

    // Add the SwiftUI content
    let hostedView = UIHostingController(rootView: content).view!
    hostedView.translatesAutoresizingMaskIntoConstraints = false
    hostedView.backgroundColor = .clear

    scrollView.addSubview(hostedView)

    NSLayoutConstraint.activate([
      hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
      hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
    ])

    // Add double-tap gesture if needed
    if resetOnDoubleTap {
      let doubleTapGesture = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
      doubleTapGesture.numberOfTapsRequired = 2
      scrollView.addGestureRecognizer(doubleTapGesture)
    }

    return scrollView
  }

  func updateUIView(_ uiView: UIScrollView, context: Context) {
    // Update the view if needed
    context.coordinator.parent = self

    // Update the hosting controller's rootView
    if let hostedView = uiView.subviews.first,
      let hostingController = hostedView.findViewController() as? UIHostingController<Content>
    {
      hostingController.rootView = content
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UIScrollViewDelegate {
    var parent: ZoomableScrollView

    init(_ parent: ZoomableScrollView) {
      self.parent = parent
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      return scrollView.subviews.first
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      // Update the binding
      parent.currentScale = scrollView.zoomScale

      // Center the content
      let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
      let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
      scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }

    @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
      guard let scrollView = gestureRecognizer.view as? UIScrollView else { return }

      if scrollView.zoomScale > scrollView.minimumZoomScale {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
      } else {
        let point = gestureRecognizer.location(in: scrollView)
        let zoomRect = CGRect(
          x: point.x - 50,
          y: point.y - 50,
          width: 100,
          height: 100
        )
        scrollView.zoom(to: zoomRect, animated: true)
      }
    }
  }
}

// Extension to find the UIViewController
extension UIView {
  func findViewController() -> UIViewController? {
    if let nextResponder = self.next as? UIViewController {
      return nextResponder
    } else if let nextResponder = self.next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
}
