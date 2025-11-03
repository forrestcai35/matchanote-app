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
  
  // Selection state
  @State private var isSelectionMode = false
  @State private var selectedPages: Set<Int> = []
  @State private var showingExportSheet = false
  @State private var showingDeleteAlert = false
  @State private var showingDeleteNoteAlert = false
  
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
  
  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack {
          Text("Pages Overview")
            .font(.jost(.largeTitle()))
            .fontWeight(.bold)
            .foregroundStyle(
              colorScheme == .dark
                ? Color.matchabrown_dark : Color.matchabrown_light)
          
          Spacer()
          
          // Toolbar buttons in header
          HStack(spacing: 12) {
            if isSelectionMode {
              // Selection mode controls
              if !selectedPages.isEmpty {
                Button("Export") {
                  showingExportSheet = true
                }
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                
                Button("Delete") {
                  // If user selected all pages, show the Delete Note alert directly
                  if selectedPages.count >= totalPages {
                    showingDeleteAlert = false
                    showingDeleteNoteAlert = true
                  } else {
                    showingDeleteAlert = true
                  }
                }
                .font(.jost(.subheadline()))
                .foregroundColor(.red)
              }
            } else {
              Button("Select") {
                enterSelectionMode()
              }
              .font(.jost(.subheadline()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            }
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
          colorScheme == .dark
            ? Color.matchabackground_dark : Color.matchabackground_light)
        
        // Pages grid content
        ScrollView {
          LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
              PageThumbnailView(
                pageIndex: pageIndex,
                note: note,
                canvasViews: canvasViews,
                isCurrentPage: pageIndex == currentPage,
                isBookmarked: note.bookmarkedPages.contains(pageIndex),
                isSelectionMode: isSelectionMode,
                isSelected: selectedPages.contains(pageIndex),
                onTap: {
                  if isSelectionMode {
                    togglePageSelection(pageIndex)
                  } else {
                    navigateToPage(pageIndex)
                  }
                },
                onBookmarkToggle: {
                  toggleBookmark(for: pageIndex)
                }
              )
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 16)
        }
      }
      .background(
        colorScheme == .dark
          ? Color.matchabackground_dark : Color.matchabackground_light)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          if isSelectionMode {
            Button("Cancel") {
              exitSelectionMode()
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
          } else {
            Button("Done") {
              isPresented = false
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
          }
        }
      }
    }
    .alert("Delete Pages", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        deleteSelectedPages()
        exitSelectionMode()
      }
    } message: {
      Text("Are you sure you want to delete \(selectedPages.count) page\(selectedPages.count == 1 ? "" : "s")? This action cannot be undone.")
    }
    .alert("Delete Note", isPresented: $showingDeleteNoteAlert) {
      Button("Cancel", role: .cancel) { }
      
      Button("Delete Note", role: .destructive) {
        // Delete the entire note and close its tabs
        storageManager.deleteNote(withID: note.id)
        isPresented = false
      }
    } message: {
      Text("Deleting all pages will remove the entire note. This action cannot be undone. Continue?")
    }
    .onChange(of: showingExportSheet) { _, newValue in
      if newValue {
        exportSelectedPages()
        showingExportSheet = false
      }
    }
  }
  
  private var totalPages: Int {
    let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let maxTextBoxPage = note.textBoxDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    return max(1, max(maxDrawingPage, max(maxImagePage, maxTextBoxPage)) + 1)
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
  
  // MARK: - Selection Management
  private func enterSelectionMode() {
    isSelectionMode = true
    selectedPages.removeAll()
  }
  
  private func exitSelectionMode() {
    isSelectionMode = false
    selectedPages.removeAll()
  }
  
  private func togglePageSelection(_ pageIndex: Int) {
    if selectedPages.contains(pageIndex) {
      selectedPages.remove(pageIndex)
    } else {
      selectedPages.insert(pageIndex)
    }
  }
  
  // MARK: - Page Actions
  private func exportSelectedPages() {
    guard !selectedPages.isEmpty else { return }
    
    // Use the universal export manager with selected pages
    let selectedPagesArray = Array(selectedPages).sorted()
    ExportManager.shared.presentExportShareSheet(for: note, selectedPages: selectedPagesArray)
  }
  
  private func deleteSelectedPages() {
    guard !selectedPages.isEmpty else { return }
    
    // If deletion would remove all pages, confirm deleting the entire note
    if selectedPages.count >= totalPages {
      showingDeleteNoteAlert = true
      return
    }
    
    // Create updated note with selected pages removed
    var updatedNote = note
    let selectedPagesArray = Array(selectedPages).sorted()
    
    // Remove drawing data for selected pages
    for pageIndex in selectedPagesArray {
      updatedNote.drawingDataByPage.removeValue(forKey: String(pageIndex))
      updatedNote.imageDataByPage.removeValue(forKey: String(pageIndex))
      updatedNote.textBoxDataByPage.removeValue(forKey: String(pageIndex))
      updatedNote.bookmarkedPages.remove(pageIndex)
    }
    
    // Adjust remaining page indices
    var adjustedNote = adjustPageIndicesAfterDeletion(updatedNote, deletedPages: selectedPagesArray)

    // Adjust currentPage if necessary
    if selectedPages.contains(currentPage) {
      // Current page was deleted, move to the nearest remaining page
      currentPage = 0
    } else {
      // Current page wasn't deleted, adjust its index based on how many pages before it were deleted
      let deletedBefore = selectedPagesArray.filter { $0 < currentPage }.count
      currentPage = max(0, currentPage - deletedBefore)
    }

    // Set modified date on the adjusted note
    adjustedNote.dateModified = Date()
    let savedNote = storageManager.saveNote(adjustedNote)
    tabManager.updateNote(savedNote)

    // Close the overview to show the updated note
    isPresented = false
  }
  
  
  private func adjustPageIndicesAfterDeletion(_ note: Note, deletedPages: [Int]) -> Note {
    var adjustedNote = note
    var newDrawingData: [String: Data] = [:]
    var newImageData: [String: [Data]] = [:]
    var newTextBoxData: [String: [Data]] = [:]
    var newBookmarkedPages: Set<Int> = []

    // Calculate total pages from the Note data being adjusted (before deletion was applied)
    let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let maxTextBoxPage = note.textBoxDataByPage.keys.compactMap { Int($0) }.max() ?? -1
    let maxPage = max(maxDrawingPage, max(maxImagePage, maxTextBoxPage))

    // Get all remaining pages (not deleted)
    let allPages = Set(0...max(0, maxPage))
    let remainingPages = allPages.subtracting(Set(deletedPages)).sorted()
    
    // Reindex remaining pages
    for (newIndex, originalIndex) in remainingPages.enumerated() {
      if let drawingData = note.drawingDataByPage[String(originalIndex)] {
        newDrawingData[String(newIndex)] = drawingData
      }
      if let imageData = note.imageDataByPage[String(originalIndex)] {
        newImageData[String(newIndex)] = imageData
      }
      if let textBoxData = note.textBoxDataByPage[String(originalIndex)] {
        newTextBoxData[String(newIndex)] = textBoxData
      }
      if note.bookmarkedPages.contains(originalIndex) {
        newBookmarkedPages.insert(newIndex)
      }
    }
    
    adjustedNote.drawingDataByPage = newDrawingData
    adjustedNote.imageDataByPage = newImageData
    adjustedNote.textBoxDataByPage = newTextBoxData
    adjustedNote.bookmarkedPages = newBookmarkedPages
    
    return adjustedNote
  }
  
  
}

struct PageThumbnailView: View {
  let pageIndex: Int
  let note: Note
  let canvasViews: [PKCanvasView]
  let isCurrentPage: Bool
  let isBookmarked: Bool
  let isSelectionMode: Bool
  let isSelected: Bool
  let onTap: () -> Void
  let onBookmarkToggle: () -> Void
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var previewImage: UIImage?
  @State private var isLoading = false
  @State private var hasContentCache: Bool?
  
  var body: some View {
    VStack(spacing: 8) {
      // Page thumbnail
      ZStack {
        // Paper background
        Rectangle()
          .fill(getPaperBackgroundColor(for: note.paperColor))
          .aspectRatio(paperAspectRatio(for: pageIndex), contentMode: .fit)
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
            .aspectRatio(paperAspectRatio(for: pageIndex), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if isLoading {
          // Show loading indicator
          Rectangle()
            .fill(Color.gray.opacity(0.05))
            .aspectRatio(paperAspectRatio(for: pageIndex), contentMode: .fit)
            .overlay(
              ProgressView()
                .scaleEffect(0.7)
            )
        } else if hasContentCache == true {
          // Has content but preview not loaded yet
          Rectangle()
            .fill(Color.gray.opacity(0.05))
            .aspectRatio(paperAspectRatio(for: pageIndex), contentMode: .fit)
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
        
        // Selection indicator
        if isSelectionMode {
          VStack {
            HStack {
              Spacer()
              Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
                .padding(8)
            }
            Spacer()
          }
        }
        
        // Current page indicator (only show when not in selection mode)
        if isCurrentPage && !isSelectionMode {
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
      .task {
        // Check content immediately on appear (fast check)
        hasContentCache = PreviewGenerator.hasContent(note: note, pageIndex: pageIndex)

        // Always generate preview to show paper pattern even on blank pages
        await generatePreview()
      }
      
      // Page number and bookmark button
      HStack {
        Text("Page \(pageIndex + 1)")
          .font(.jost(.caption()))
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
  
  
  private func generatePreview() async {
    // Set loading state
    isLoading = true
    
    // Generate preview on background thread using Task
    let note = self.note
    let pageIndex = self.pageIndex
    
    let preview = await Task.detached(priority: .userInitiated) { () -> UIImage in
      return PreviewGenerator.generatePreview(
        for: note,
        pageIndex: pageIndex,
        size: .grid
      )
    }.value
    
    // Update UI on main thread
    self.previewImage = preview
    self.isLoading = false
  }
  
  private var paperAspectRatio: CGFloat {
    PaperUtilities.paperAspectRatio(
      for: note.paperSize,
      orientation: note.paperOrientation
    )
  }

  private func paperAspectRatio(for pageIndex: Int) -> CGFloat {
    if let imageDataArray = note.imageDataByPage[String(pageIndex)],
       let first = imageDataArray.first {
      if let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: first) {
        return CGFloat(pdfBg.width / pdfBg.height)
      } else if let uiImage = UIImage(data: first) {
        return uiImage.size.width / uiImage.size.height
      }
    }
    return paperAspectRatio
  }
  
  private func getPaperBackgroundColor(for color: PaperColor) -> Color {
    return PaperUtilities.getPaperBackgroundColor(for: color)
  }
  
  private func getPaperWidth(for size: PaperSize) -> CGFloat {
    PaperUtilities.getPaperWidth(for: size, orientation: note.paperOrientation)
  }
  
  private func getPaperHeight(for size: PaperSize) -> CGFloat {
    PaperUtilities.getPaperHeight(for: size, orientation: note.paperOrientation)
  }
}
