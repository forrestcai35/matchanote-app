import SwiftUI
import PencilKit


// Add a helper view for folder grid items
public struct GridFolderItemView: View {
    let folder: Folder
    let isSelected: Bool
    let isSelectionMode: Bool
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storageManager: StorageManager
    @State private var showRenamePopover = false
    @State private var newName = ""
    
    init(folder: Folder, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.folder = folder
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Folder card
            ZStack {
                // Folder image instead of background
                Image("folder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 175, height: 140)
                    .clipped()
                
                // Star indicator for folders
                Button(action: {
                    if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folder.id }) {
                        var updatedFolder = storageManager.folders[folderIndex]
                        updatedFolder.toggleFavorite()
                        _ = storageManager.saveFolder(updatedFolder)
                    }
                }) {
                    Image(systemName: folder.isFavorite ? "star.fill" : "star")
                        .foregroundColor(folder.isFavorite ? .yellow : .gray)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 1, y: 26)
                
                // Selection indicator - centered circle with checkmark
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .shadow(radius: 2)
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(
                                    colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                                )
                                .font(.system(size: 20))
                        } else {
                            Circle()
                                .stroke(Color.gray, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            // Folder title with rename dropdown
            HStack(spacing: 4) {
                Text(folder.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fontWeight(.medium)
                    .font(.subheadline)

                // Rename dropdown button
                Button(action: {
                    newName = folder.name
                    showRenamePopover = true
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showRenamePopover) {
                    VStack(spacing: 12) {
                        Text("Rename Folder")
                            .font(.headline)

                        TextField("Folder name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)

                        HStack {
                            Button("Cancel") {
                                showRenamePopover = false
                            }
                            .foregroundColor(.red)

                            Spacer()

                            Button("Save") {
                                if storageManager.updateFolderName(folderId: folder.id, newName: newName) != nil {
                                    // Folder updated successfully
                                }
                                showRenamePopover = false
                            }
                            .disabled(newName.isEmpty)
                        }
                    }
                    .padding()
                    .frame(minWidth: 250)
                }
            }
            .padding(.top, 5)
            .frame(width: 160)
            .multilineTextAlignment(.center)
            // Date
            Text(folder.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(width: 160)
        .contentShape(Rectangle())
    }
}

// Add a helper view for grid items
public struct GridItemView: View {
    let note: Note
    let isSelected: Bool
    let isSelectionMode: Bool
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storageManager: StorageManager
    @State private var showRenamePopover = false
    @State private var newTitle = ""
    
    init(note: Note, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.note = note
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    // Check if note has uploaded content to preview
    private var hasUploadedContent: Bool {
        return !note.imageDataByPage.isEmpty
    }

    // Helper to get the drawing data for uploaded content preview
    private var uploadedContentDrawing: PKDrawing {
        if let drawingData = note.drawingDataByPage["0"],
           let existingDrawing = try? PKDrawing(data: drawingData) {
            return existingDrawing
        } else {
            return PKDrawing() // Empty drawing
        }
    }
    
    // Preview view for uploaded content
    @ViewBuilder
    private var uploadedContentPreview: some View {
        // Use PaperUtilities to properly composite paper background, uploaded images, and drawing data
        let paperSize = PaperUtilities.paperSize(for: note.paperSize)
        let backgroundImages = note.imageDataByPage["0"]
        let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: 0)
        let previewImage = PaperUtilities.generatePreviewWithBackground(
            drawing: uploadedContentDrawing,
            paperSize: paperSize,
            paperColor: note.paperColor,
            paperStyle: note.paperStyle,
            scale: 0.5,
            backgroundImages: backgroundImages,
            overlayImages: overlayImages
        )
        
        Image(uiImage: previewImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }

    // Preview view for written notes (show drawing/content preview)
    @ViewBuilder
    private var writtenNotePreview: some View {
        ZStack {
            // Paper background
            RoundedRectangle(cornerRadius: 10)
                .fill(PaperUtilities.getPaperBackgroundColor(for: note.paperColor))

            // Show drawing preview if available
            if let drawingData = note.drawingDataByPage["0"],
               let pkDrawing = try? PKDrawing(data: drawingData) {
                // Use PaperUtilities for consistent preview generation with background images
                let paperSize = PaperUtilities.paperSize(for: note.paperSize)
                let backgroundImages = note.imageDataByPage["0"]
                let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: 0)
                let previewImage = PaperUtilities.generatePreviewWithBackground(
                    drawing: pkDrawing,
                    paperSize: paperSize,
                    paperColor: note.paperColor,
                    paperStyle: note.paperStyle,
                    scale: 0.5,
                    backgroundImages: backgroundImages,
                    overlayImages: overlayImages
                )

                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } 
        }
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Note card
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0)
                    .fill(note.color)
                    .frame(width: 160, height: 200)
                    .shadow(
                        color: itemShadow(in: colorScheme),
                        radius: note.noteType == .written ? 5 : 6,
                        x: 0,
                        y: 2
                    )

                // Content preview
                if hasUploadedContent {
                    // Show uploaded content preview
                    uploadedContentPreview
                        .frame(width: 160, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0))
                } else {
                    // Show content previews for notes without uploaded content
                    if note.noteType == .written {
                        writtenNotePreview
                            .frame(width: 160, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button(action: {
                    var updatedNote = note
                    updatedNote.isFavorite.toggle()
                    updatedNote.dateModified = Date()
                    let savedNote = storageManager.saveNote(updatedNote)
                    TabManager.shared.updateNote(savedNote)
                }) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundColor(note.isFavorite ? .yellow : .gray)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                Image(systemName: noteTypeIcon(note.noteType))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
                
                // Selection indicator - centered circle with checkmark
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .shadow(radius: 2)
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(
                                    colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                                )
                                .font(.system(size: 20))
                        } else {
                            Circle()
                                .stroke(Color.gray, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }

            Button(action: {
                newTitle = note.title
                showRenamePopover = true
            }) {
                HStack(spacing: 4) {
                    Text(note.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .fontWeight(.medium)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 10))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showRenamePopover) {
                VStack(spacing: 12) {
                    Text("Rename Note")
                        .font(.headline)

                    TextField("Note name", text: $newTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)

                    HStack {
                        Button("Cancel") {
                            showRenamePopover = false
                        }
                        .foregroundColor(.red)

                        Spacer()

                        Button("Save") {
                            var updatedNote = note
                            updatedNote.title = newTitle
                            updatedNote.dateModified = Date()
                            let savedNote = storageManager.saveNote(updatedNote)
                            TabManager.shared.updateNote(savedNote)
                            showRenamePopover = false
                        }
                        .disabled(newTitle.isEmpty)
                    }
                }
                .padding()
                .frame(minWidth: 250)
            }
            .padding(.top, 5)
            .frame(width: 160)
            .multilineTextAlignment(.center)

            Text(note.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .contentShape(Rectangle())

    }

    // Use the DocumentsView noteTypeIcon function
    private func noteTypeIcon(_ type: NoteType) -> String {
        return "pencil"
    }
}
