import PencilKit
import SwiftDown
import SwiftUI
import matchanote_app

// Written Note View with PencilKit
struct WrittenNoteView: View {
  var note: Note
  @Binding var isEdited: Bool
  @Binding var toolPickerIsVisible: Bool
  @Binding var canvasViews: [PKCanvasView]
  @Binding var currentPage: Int
  @Binding var currentTool: PenTool?
  @State private var pageCount = 1
  @State private var currentScale: CGFloat = 1.25
  @State private var finalScale: CGFloat = 1.0
  @State private var toolPicker = PKToolPicker()
  @Environment(\.colorScheme) private var colorScheme
  private let infiniteScrollHeight: CGFloat = 10000

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
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pageCount)
      .tabViewStyle(.page(indexDisplayMode: .never))
      .overlay(alignment: .bottomTrailing) {
        controlsOverlay
      }
    }
    .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
    .onAppear {
      setupToolPicker()
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
  }

  // Setup the PKToolPicker for the current canvas
  private func setupToolPicker() {
    guard let currentCanvas = getCurrentCanvas() else { return }

    // Set tool based on current selection
    if let selectedTool = currentTool {
      currentCanvas.tool = selectedTool.toolInstance
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
      toolPicker.addObserver(newCanvas)
      canvasViews.append(newCanvas)
    }
  }

  // Extracted Page Content View Builder
  @ViewBuilder
  private func pageContent(pageIndex: Int, isInfinite: Bool) -> some View {
    // Wrap Canvas in a GeometryReader to get parent size for centering
    GeometryReader { geometry in
      // Scroll view now explicitly centers content
      ScrollView([.horizontal, .vertical], showsIndicators: false) {
        ZStack {
          // Background with paper style
          paperBackground()

          // PencilKit Canvas - use the canvas for this specific page
          if pageIndex < canvasViews.count {
            PencilKitCanvasView(canvasView: canvasViews[pageIndex])
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

        .scaleEffect(finalScale * currentScale)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .coordinateSpace(name: "scroll")
      .gesture(
        MagnificationGesture()
          .onChanged { value in
            // Use a more forgiving magnification with damping
            let dampedValue = 1.0 + ((value - 1.0) * 0.8)  // Apply 20% damping
            // Limit scaling with stricter bounds (0.8 min, 3.0 max considering finalScale)
            let newScale = dampedValue
            if finalScale * newScale >= 0.8 && finalScale * newScale <= 3.0 {
              currentScale = newScale
            }
          }
          .onEnded { value in
            let dampedFinalValue = 1.0 + ((value - 1.0) * 0.8)
            let potentialFinalScale = finalScale * dampedFinalValue
            finalScale = min(max(potentialFinalScale, 0.8), 3.0)
            currentScale = 1.0
          }
      )
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
      currentCanvas.tool = selectedTool.toolInstance
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

  func makeUIView(context: Context) -> PKCanvasView {
    canvasView.backgroundColor = .clear
    canvasView.isScrollEnabled = false
    return canvasView
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    // No custom policy updates needed
  }
}

//Markdown View
struct TextNoteView: View {
  var note: Note
  @State private var textContent: String
  @Binding var isEdited: Bool
  private let infiniteScrollHeight: CGFloat = 10000
  @Environment(\.colorScheme) private var colorScheme
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
            .theme(Theme.BuiltIn.defaultLight.theme())
            .scrollContentBackground(.hidden)
            .frame(minHeight: infiniteScrollHeight)
            .frame(width: 700)
            .background(getPaperBackgroundColor(for: note.paperColor))
            .onChange(of: textContent) { oldValue, newValue in
              if oldValue != newValue {
                isEdited = true
              }
            }

            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
        }
      }
      .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
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
