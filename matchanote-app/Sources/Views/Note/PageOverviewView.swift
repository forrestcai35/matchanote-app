import SwiftUI
import PencilKit

struct PageOverviewView: View {
  var note: Note
  @Binding var currentPage: Int
  @Binding var canvasViews: [PKCanvasView]
  @Binding var isPresented: Bool
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager
  @ObservedObject private var tabManager = TabManager.shared
  
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(0..<totalPages, id: \.self) { pageIndex in
            PageThumbnailView(
              pageIndex: pageIndex,
              note: note,
              canvasViews: canvasViews,
              isCurrentPage: pageIndex == currentPage,
              isBookmarked: note.bookmarkedPages.contains(pageIndex),
              onTap: {
                navigateToPage(pageIndex)
              },
              onBookmarkToggle: {
                toggleBookmark(for: pageIndex)
              }
            )
          }
        }
        .padding(16)
      }
      .navigationTitle("Pages Overview")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            isPresented = false
          }
        }
      }
    }
    .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
  }
  
  private var totalPages: Int {
    let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let canvasPageCount = canvasViews.count
    return max(1, max(maxDrawingPage + 1, canvasPageCount))
  }
  
  private func navigateToPage(_ pageIndex: Int) {
    currentPage = pageIndex
    isPresented = false
  }
  
  private func toggleBookmark(for pageIndex: Int) {
    var updatedNote = note
    if updatedNote.bookmarkedPages.contains(pageIndex) {
      updatedNote.bookmarkedPages.remove(pageIndex)
    } else {
      updatedNote.bookmarkedPages.insert(pageIndex)
    }
    updatedNote.dateModified = Date()
    
    let savedNote = storageManager.saveNote(updatedNote)
    tabManager.updateNote(savedNote)
  }
}

struct PageThumbnailView: View {
  let pageIndex: Int
  let note: Note
  let canvasViews: [PKCanvasView]
  let isCurrentPage: Bool
  let isBookmarked: Bool
  let onTap: () -> Void
  let onBookmarkToggle: () -> Void
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var previewImage: UIImage?
  
  var body: some View {
    VStack(spacing: 8) {
      // Page thumbnail
      ZStack {
        // Paper background
        Rectangle()
          .fill(getPaperBackgroundColor(for: note.paperColor))
          .aspectRatio(paperAspectRatio, contentMode: .fit)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(
                isCurrentPage ? Color.matchalight_dark : Color.gray.opacity(0.3),
                lineWidth: isCurrentPage ? 3 : 1
              )
          )
        
        // Drawing preview
        if let previewImage = previewImage {
          Image(uiImage: previewImage)
            .resizable()
            .aspectRatio(paperAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if pageIndex < canvasViews.count && !canvasViews[pageIndex].drawing.strokes.isEmpty {
          // Fallback while loading
          Rectangle()
            .fill(Color.gray.opacity(0.1))
            .aspectRatio(paperAspectRatio, contentMode: .fit)
            .overlay(
              ProgressView()
                .scaleEffect(0.8)
            )
        }
        
        // Paper pattern overlay (subtle)
        if previewImage == nil || (pageIndex < canvasViews.count && canvasViews[pageIndex].drawing.strokes.isEmpty) {
          paperPatternOverlay()
            .opacity(0.3)
            .aspectRatio(paperAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        
        // Bookmark indicator
        if isBookmarked {
          VStack {
            HStack {
              Spacer()
              Image(systemName: "bookmark.fill")
                .foregroundColor(.matchalight_dark)
                .font(.caption)
                .padding(4)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
          }
        }
        
        // Current page indicator
        if isCurrentPage {
          VStack {
            Spacer()
            HStack {
              Spacer()
              Circle()
                .fill(Color.matchalight_dark)
                .frame(width: 8, height: 8)
                .padding(8)
            }
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
      .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
      .onTapGesture {
        onTap()
      }
      .onAppear {
        generatePreview()
      }
      .onChange(of: pageIndex) { _, _ in
        generatePreview()
      }
      
      // Page number and bookmark button
      HStack {
        Text("Page \(pageIndex + 1)")
          .font(.caption)
          .foregroundColor(colorScheme == .dark ? .white : .black)
        
        Spacer()
        
        Button(action: onBookmarkToggle) {
          Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .foregroundColor(isBookmarked ? .matchalight_dark : .gray)
            .font(.caption)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  @ViewBuilder
  private func paperPatternOverlay() -> some View {
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
  
  @ViewBuilder
  private func gridOverlay(size: CGSize) -> some View {
    let gridSpacing: CGFloat = max(8, size.width / 30) // Adaptive spacing for thumbnail
    
    ZStack {
      // Horizontal lines
      ForEach(0..<Int(size.height / gridSpacing + 1), id: \.self) { i in
        let y = CGFloat(i) * gridSpacing
        Path { path in
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: size.width, y: y))
        }
        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
      }
      // Vertical lines
      ForEach(0..<Int(size.width / gridSpacing + 1), id: \.self) { i in
        let x = CGFloat(i) * gridSpacing
        Path { path in
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: size.height))
        }
        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
      }
    }
  }
  
  @ViewBuilder
  private func dottedOverlay(size: CGSize) -> some View {
    let baseSpacing: CGFloat = max(12, size.width / 20) // Adaptive spacing for thumbnail
    let dotRadius: CGFloat = 0.8
    
    Canvas { context, canvasSize in
      let horizontalCount = Int(canvasSize.width / baseSpacing)
      let verticalCount = Int(canvasSize.height / baseSpacing)
      
      for row in 0...verticalCount {
        for col in 0...horizontalCount {
          let x = CGFloat(col) * baseSpacing
          let y = CGFloat(row) * baseSpacing
          
          context.fill(
            Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
            with: .color(.gray.opacity(0.4))
          )
        }
      }
    }
  }
  
  @ViewBuilder
  private func linedOverlay(size: CGSize) -> some View {
    let lineSpacing: CGFloat = max(10, size.height / 20) // Adaptive spacing for thumbnail
    
    ForEach(0..<Int(size.height / lineSpacing + 1), id: \.self) { i in
      let y = CGFloat(i) * lineSpacing
      Path { path in
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }
      .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
    }
  }
  
  private func generatePreview() {
    guard pageIndex < canvasViews.count else {
      previewImage = nil
      return
    }
    
    let canvas = canvasViews[pageIndex]
    
    // Only generate preview if there are strokes
    guard !canvas.drawing.strokes.isEmpty else {
      previewImage = nil
      return
    }
    
    DispatchQueue.main.async {
      // Create preview image from canvas drawing
      let paperSize = CGSize(
        width: getPaperWidth(for: note.paperSize),
        height: getPaperHeight(for: note.paperSize)
      )
      
      // Use higher scale for crisp thumbnails - scale based on screen density
      let screenScale = UIScreen.main.scale
      let thumbnailScale: CGFloat = 0.5 // Increased from 0.2 for better quality
      let effectiveScale = thumbnailScale * screenScale
      
      let thumbnailSize = CGSize(
        width: paperSize.width * thumbnailScale,
        height: paperSize.height * thumbnailScale
      )
      
      // Always use the full paper size as bounds to show entire page
      let fullPageBounds = CGRect(origin: .zero, size: paperSize)
      
      let image = canvas.drawing.image(from: fullPageBounds, scale: effectiveScale)
      
      // Create a composite image with paper background
      UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, screenScale)
      
      defer {
        UIGraphicsEndImageContext()
      }
      
      guard let context = UIGraphicsGetCurrentContext() else {
        previewImage = nil
        return
      }
      
      // Enable high quality rendering
      context.setAllowsAntialiasing(true)
      context.setShouldAntialias(true)
      context.interpolationQuality = .high
      
      // Draw paper background
      let paperColor = getPaperBackgroundColor(for: note.paperColor)
      UIColor(paperColor).setFill()
      context.fill(CGRect(origin: .zero, size: thumbnailSize))
      
      // Draw the entire page drawing at thumbnail size
      image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
      
      previewImage = UIGraphicsGetImageFromCurrentImageContext()
    }
  }
  
  private var paperAspectRatio: CGFloat {
    return PaperUtilities.paperAspectRatio(for: note.paperSize)
  }
  
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    return PaperUtilities.getPaperBackgroundColor(for: color)
  }
  
  private func getPaperWidth(for size: PaperSize) -> CGFloat {
    return PaperUtilities.getPaperWidth(for: size)
  }
  
  private func getPaperHeight(for size: PaperSize) -> CGFloat {
    return PaperUtilities.getPaperHeight(for: size)
  }
}

#Preview {
  PageOverviewView(
    note: Note.samples[0],
    currentPage: .constant(0),
    canvasViews: .constant([]),
    isPresented: .constant(true)
  )
} 