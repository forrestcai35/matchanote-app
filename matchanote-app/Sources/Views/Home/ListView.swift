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
                        _ = storageManager.saveFolder(updatedFolder)
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
