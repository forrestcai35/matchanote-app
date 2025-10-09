import SwiftUI
import PencilKit

public struct ListItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storageManager: StorageManager
    let note: Note
    let isSelected: Bool
    let isSelectionMode: Bool
    @State private var showRenamePopover = false
    @State private var newTitle = ""
    
    init(note: Note, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.note = note
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    // Check if note has uploaded content to preview
    private var hasUploadedContent: Bool {
        return !note.imageDataByPage.isEmpty
    }

    // Small preview view for list items - using grid view aspect ratio
    @ViewBuilder
    private var notePreview: some View {
        ZStack {
            // Content preview with vertical rectangle aspect ratio (same as grid)
            if hasUploadedContent {
                // Show uploaded content preview with drawing strokes
                let paperSize = PaperUtilities.paperSize(for: note.paperSize)
                let backgroundImages = note.imageDataByPage["0"]
                let drawingData = note.drawingDataByPage["0"]
                let pkDrawing = (drawingData != nil) ? (try? PKDrawing(data: drawingData!)) ?? PKDrawing() : PKDrawing()
                
                let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: 0)
                let previewImage = PaperUtilities.generatePreviewWithBackground(
                    drawing: pkDrawing,
                    paperSize: paperSize,
                    paperColor: note.paperColor,
                    paperStyle: note.paperStyle,
                    scale: 0.3,
                    backgroundImages: backgroundImages,
                    overlayImages: overlayImages
                )
                
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 40)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: note.noteType == .written ? 6 : 2))
            } else {
                // Show content preview for notes without uploaded content
                if note.noteType == .written {
                    ZStack {
                        // Paper background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PaperUtilities.getPaperBackgroundColor(for: note.paperColor))
                            .frame(width: 32, height: 40)
                        
                        // Show drawing preview if available
                        if let drawingData = note.drawingDataByPage["0"],
                           let pkDrawing = try? PKDrawing(data: drawingData),
                           !pkDrawing.strokes.isEmpty {
                            // Use PaperUtilities for consistent preview generation
                            let paperSize = PaperUtilities.paperSize(for: note.paperSize)
                            let backgroundImages = note.imageDataByPage["0"]
                            let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: 0)
                            let previewImage = PaperUtilities.generatePreviewWithBackground(
                                drawing: pkDrawing,
                                paperSize: paperSize,
                                paperColor: note.paperColor,
                                paperStyle: note.paperStyle,
                                scale: 0.3,
                                backgroundImages: backgroundImages,
                                overlayImages: overlayImages
                            )

                            Image(uiImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 40)
                                .clipped()
                        } 
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // Text note preview
                    if !note.content.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(0..<min(5, note.content.components(separatedBy: .newlines).count), id: \.self) { lineIndex in
                                let lines = note.content.components(separatedBy: .newlines)
                                if lineIndex < lines.count && !lines[lineIndex].isEmpty {
                                    HStack {
                                        Text(lines[lineIndex])
                                            .font(.system(size: 6))
                                            .lineLimit(1)
                                            .foregroundColor(
                                                colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8)
                                            )
                                        Spacer()
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(3)
                        .frame(width: 32, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(note.color)
                        )
                    } else {
                        // Empty text note
                        RoundedRectangle(cornerRadius: 2)
                            .fill(note.color)
                            .frame(width: 32, height: 40)
                            .overlay(
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 14))
                                    .foregroundColor(
                                        colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
                                    )
                            )
                    }
                }
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Selection indicator
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(
                            isSelected 
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : .gray
                        )
                        .font(.title3)
                }
                
                // Note preview with shadow
                notePreview
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15),
                        radius: 2,
                        x: 0,
                        y: 1
                    )

                // Note info
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: {
                        newTitle = note.title
                        showRenamePopover = true
                    }) {
                        HStack(spacing: 4) {
                            Text(note.title)
                                .fontWeight(.medium)
                                .lineLimit(1)
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

                    Text(note.dateModified, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Star indicator
                Button(action: {
                    var updatedNote = note
                    updatedNote.isFavorite.toggle()
                    updatedNote.dateModified = Date()
                    let savedNote = storageManager.saveNote(updatedNote)
                    TabManager.shared.updateNote(savedNote)
                }) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundColor(note.isFavorite ? .yellow : .gray)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal)
            .background(
                isSelected && isSelectionMode 
                    ? Color.blue.opacity(0.1) 
                    : Color.clear
            )
            .contentShape(Rectangle())

            // Divider
            Divider()
                .padding(.horizontal)
        }
    }

    // Use the DocumentsView noteTypeIcon function
    private func noteTypeIcon(_ type: NoteType) -> String {
        return "pencil"
    }
}

// Add a helper view for folder list items
public struct ListFolderItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storageManager: StorageManager
    let folder: Folder
    let isSelected: Bool
    let isSelectionMode: Bool
    @State private var showRenamePopover = false
    @State private var newName = ""
    
    init(folder: Folder, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.folder = folder
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    // Small folder preview using the same folder image as grid view - vertical rectangle
    @ViewBuilder
    private var folderPreview: some View {
        Image("folder")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 40)
            .clipped()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Selection indicator
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(
                            isSelected 
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : .gray
                        )
                        .font(.title3)
                }
                
                // Folder preview with shadow
                folderPreview
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15),
                        radius: 2,
                        x: 0,
                        y: 1
                    )

                // Folder info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(folder.name)
                            .fontWeight(.medium)
                            .lineLimit(1)

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

                    Text(folder.dateModified, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Star indicator for folders
                Button(action: {
                    if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folder.id }) {
                        var updatedFolder = storageManager.folders[folderIndex]
                        updatedFolder.toggleFavorite()
                        let savedFolder = storageManager.saveFolder(updatedFolder)
                    }
                }) {
                    Image(systemName: folder.isFavorite ? "star.fill" : "star")
                        .foregroundColor(folder.isFavorite ? .yellow : .gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal)
            .background(
                isSelected && isSelectionMode 
                    ? Color.blue.opacity(0.1) 
                    : Color.clear
            )
            .contentShape(Rectangle())

            // Divider
            Divider()
                .padding(.horizontal)
        }
    }
}

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
                
                // Star indicator
                Button(action: {
                    if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folder.id }) {
                        var updatedFolder = storageManager.folders[folderIndex]
                        updatedFolder.toggleFavorite()
                        let savedFolder = storageManager.saveFolder(updatedFolder)
                    }
                }) {
                    Image(systemName: folder.isFavorite ? "star.fill" : "star")
                        .foregroundColor(folder.isFavorite ? .yellow : .gray)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 1, y: 28)
                
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
