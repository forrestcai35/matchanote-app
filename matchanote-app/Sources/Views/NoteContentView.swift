import SwiftDown
import SwiftUI
import matchanote_app

struct WrittenNoteView: View {
  var note: Note
  @Binding var isEdited: Bool

  @State private var currentPage = 0
  @State private var pageCount = 1
  @State private var currentScale: CGFloat = 1.0
  @State private var finalScale: CGFloat = 1.0

  private let infiniteScrollHeight: CGFloat = 10000

  var body: some View {
    VStack(spacing: 0) {
      // Scroll/Swipe View based on note.scrollType
      if note.scrollType == .pages {
        // Pages Mode: Horizontal TabView
        TabView(selection: $currentPage) {
          ForEach(0..<pageCount, id: \.self) { pageIndex in
            pageContent(pageIndex: pageIndex, isInfinite: false)
              .tag(pageIndex)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
      } else {
        ScrollView(.vertical, showsIndicators: true) {
          pageContent(pageIndex: 0, isInfinite: true)
        }
      }
      controlsOverlay
    }
  }

  // Extracted Page Content View Builder
  @ViewBuilder
  private func pageContent(pageIndex: Int, isInfinite: Bool) -> some View {
    // Wrap Canvas in a ScrollView for panning fixed-size content
    ScrollView([.horizontal, .vertical], showsIndicators: false) {
      Canvas { context, size in
        // Draw paper background based on paper color
        let rect = CGRect(origin: .zero, size: size)
        let paperBackground: Color = getPaperBackgroundColor(for: note.paperColor)
        context.fill(Path(rect), with: .color(paperBackground))

        // Draw paper style - helpers adapt to size automatically
        switch note.paperStyle {
        case .grid:
          drawGrid(context: context, size: size)
        case .dotted:
          drawDots(context: context, size: size)
        case .lined:
          drawLines(context: context, size: size)
        case .blank:
          break
        }

        // TODO: Add logic here later to load/save drawing for `pageIndex` (or infinite area)
      }
      .frame(
        width: getPaperWidth(for: note.paperSize),
        // Set fixed height unless infinite
        height: isInfinite ? infiniteScrollHeight : getPaperHeight(for: note.paperSize)
      )
      // Removed .aspectRatio
      .background(Color.white)  // Use white background for shadow visibility
      .cornerRadius(10)
      .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
      // No outer padding needed here, ScrollView handles clipping
      .onTapGesture {
        // When canvas is drawn on, mark as edited
        // TODO: In infinite mode, this marks the whole note edited, not a specific part
        isEdited = true
      }
      .padding(.top, 20)  // Add padding only to the top of the Canvas
      .scaleEffect(finalScale * currentScale)  // Apply scaling
    }
    .gesture(  // Add magnification gesture
      MagnificationGesture()
        .onChanged { value in
          currentScale = value
        }
        .onEnded { value in
          finalScale *= value
          currentScale = 1.0  // Reset temporary scale
        }
    )
  }

  // Controls View
  @ViewBuilder
  private var controlsOverlay: some View {

    if note.scrollType == .pages {
      HStack {

        Spacer()

        Text("Page \(currentPage + 1) of \(pageCount)")
          .font(.caption)

        Spacer()

        Button {
          pageCount += 1
          currentPage = pageCount - 1

        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.title2)
        }
      }
      .padding()
      .background(.thinMaterial)
    }
  }

  private func drawGrid(context: GraphicsContext, size: CGSize) {
    let gridSpacing: CGFloat = 20
    let gridColor = Color.gray.opacity(0.3)

    // Draw horizontal lines
    for y in stride(from: 0, to: size.height, by: gridSpacing) {
      var path = Path()
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: size.width, y: y))
      context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }

    // Draw vertical lines
    for x in stride(from: 0, to: size.width, by: gridSpacing) {
      var path = Path()
      path.move(to: CGPoint(x: x, y: 0))
      path.addLine(to: CGPoint(x: x, y: size.height))
      context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }
  }

  private func drawDots(context: GraphicsContext, size: CGSize) {
    let dotSpacing: CGFloat = 20
    let dotColor = Color.gray.opacity(0.3)
    let dotSize: CGFloat = 2

    for y in stride(from: dotSpacing, to: size.height - dotSpacing, by: dotSpacing) {
      for x in stride(from: dotSpacing, to: size.width - dotSpacing, by: dotSpacing) {
        let dotRect = CGRect(
          x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
        context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
      }
    }
  }

  private func drawLines(context: GraphicsContext, size: CGSize) {
    let lineSpacing: CGFloat = 24
    let lineColor = Color.blue.opacity(0.3)
    let marginTop: CGFloat = 30  // Add a top margin like real lined paper

    for y in stride(from: marginTop, to: size.height, by: lineSpacing) {
      var path = Path()
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: size.width, y: y))
      context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
    }
  }

  // Helper function for background color
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .yellow:
      return Color(red: 1.0, green: 0.98, blue: 0.8)
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

  // Helper to maintain aspect ratio
  private func getPaperAspectRatio(for size: PaperSize) -> CGFloat {
    return getPaperWidth(for: size) / getPaperHeight(for: size)
  }
}

// Renamed from TextNoteView to reflect its Markdown nature
struct MarkdownNoteView: View {
  var note: Note
  @State private var textContent: String
  @Binding var isEdited: Bool
  @State private var currentScale: CGFloat = 1.0
  @State private var finalScale: CGFloat = 1.0
  private let infiniteScrollHeight: CGFloat = 10000

  init(note: Note, isEdited: Binding<Bool>) {
    self.note = note
    _textContent = State(initialValue: note.content)
    _isEdited = isEdited
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack {
        SwiftDownEditor(text: $textContent)
          .insetsSize(40)
          .theme(Theme.BuiltIn.defaultLight.theme())
          .scrollContentBackground(.hidden)

          .frame(minHeight: infiniteScrollHeight)
          .frame(width: getPaperWidth(for: note.paperSize) - 40)
          .background(getPaperBackgroundColor(for: note.paperColor))
          .cornerRadius(10)
          .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
          .padding(20)
          .onChange(of: textContent) { oldValue, newValue in
            if oldValue != newValue {
              isEdited = true
            }
          }
          .scaleEffect(finalScale * currentScale)  // Apply scaling
      }
    }
    .gesture(  // Add magnification gesture
      MagnificationGesture()
        .onChanged { value in
          currentScale = value
        }
        .onEnded { value in
          finalScale *= value
          currentScale = 1.0  // Reset temporary scale
        }
    )
  }

  // Helper function for background color
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .yellow:
      return Color(red: 1.0, green: 0.98, blue: 0.8)
    }
  }

  // Helper function to get paper width
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
}

// Plain Text Notes
struct TextNoteView: View {
  var note: Note
  @State private var textContent: String
  @Binding var isEdited: Bool
  @State private var currentScale: CGFloat = 1.0
  @State private var finalScale: CGFloat = 1.0

  init(note: Note, isEdited: Binding<Bool>) {
    self.note = note
    _textContent = State(initialValue: note.content)
    _isEdited = isEdited
  }

  var body: some View {
    EmptyView()
      .padding()
    // Wrap TextEditor in a ScrollView for panning fixed-size content
    ScrollView([.horizontal, .vertical], showsIndicators: false) {
      TextEditor(text: $textContent)
        .scrollContentBackground(.hidden)  // Make TextEditor background transparent
        .frame(  // Set both width and height for page dimensions
          width: getPaperWidth(for: note.paperSize),
          height: getPaperHeight(for: note.paperSize)
        )
        .background(getPaperBackgroundColor(for: note.paperColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)  // Add shadow
        // No outer padding needed here, ScrollView handles clipping
        .onChange(of: textContent) { oldValue, newValue in
          if oldValue != newValue {
            isEdited = true
          }
        }
        // .padding(.top, 20)
        .scaleEffect(finalScale * currentScale)  // Apply scaling
    }
    .gesture(  // Add magnification gesture
      MagnificationGesture()
        .onChanged { value in
          currentScale = value
        }
        .onEnded { value in
          finalScale *= value
          currentScale = 1.0  // Reset temporary scale
        }
    )
  }

  // Helper function for background color (can be shared or duplicated)
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    switch color {
    case .white:
      return .white
    case .offwhite:
      return Color(red: 0.98, green: 0.96, blue: 0.9)
    case .yellow:
      return Color(red: 1.0, green: 0.98, blue: 0.8)
    }
  }

  // Helper function to get paper width (can be shared or duplicated)
  private func getPaperWidth(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 612
    case .letter:
      return 612
    case .tabloid:
      return 792
    case .a4:
      return 595
    }
  }

  // Helper function to get paper height (needed now)
  private func getPaperHeight(for size: PaperSize) -> CGFloat {
    switch size {
    case .legal:
      return 1008
    case .letter:
      return 792
    case .tabloid:
      return 1224
    case .a4:
      return 842
    }
  }
}
