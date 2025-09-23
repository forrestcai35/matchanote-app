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
                // Show uploaded content preview
                if let firstPageImages = note.imageDataByPage["0"],
                   let firstImageData = firstPageImages.first,
                   let uiImage = UIImage(data: firstImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 40)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: note.noteType == .written ? 6 : 2))
                } else {
                    RoundedRectangle(cornerRadius: note.noteType == .written ? 6 : 2)
                        .fill(note.color)
                        .frame(width: 32, height: 40)
                        .overlay(
                            Image(systemName: "doc.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
            } else {
                // Show content preview for notes without uploaded content
                if note.noteType == .written {
                    // Check if there's actual drawing content
                    if let drawingData = note.drawingDataByPage["0"],
                       let pkDrawing = try? PKDrawing(data: drawingData),
                       !pkDrawing.strokes.isEmpty {
                        // Show drawing preview
                        let paperSize = PaperUtilities.paperSize(for: note.paperSize)
                        let previewBounds = CGRect(origin: .zero, size: paperSize)
                        let previewImage = pkDrawing.image(from: previewBounds, scale: 0.3)

                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 40)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        // Empty written note - show paper background with pencil icon
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PaperUtilities.getPaperBackgroundColor(for: note.paperColor))
                            .frame(width: 32, height: 40)
                            .overlay(
                                Image(systemName: "pencil.tip")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.gray.opacity(0.5))
                            )
                    }
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
                        .foregroundColor(isSelected ? .blue : .gray)
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
                    HStack(spacing: 4) {
                        Text(note.title)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        // Rename dropdown button
                        Button(action: {
                            newTitle = note.title
                            showRenamePopover = true
                        }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                                .font(.system(size: 10))
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
                    }

                    Text(note.dateModified, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Star indicator
                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .foregroundColor(note.isFavorite ? .yellow : .gray)
                    .font(.caption)
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
        switch type {
        case .written:
            return "pencil"
        case .text:
            return "text.page"
        }
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
                        .foregroundColor(isSelected ? .blue : .gray)
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
                
                // Selection indicator
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .blue : .white)
                                .font(.title2)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
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
        .background(
            isSelected && isSelectionMode 
                ? Color.blue.opacity(0.1) 
                : Color.clear
        )
        .cornerRadius(12)
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

    // Preview view for uploaded content
    @ViewBuilder
    private var uploadedContentPreview: some View {
        if let firstPageImages = note.imageDataByPage["0"],
           let firstImageData = firstPageImages.first,
           let uiImage = UIImage(data: firstImageData) {
            // Show actual image preview without overlay icon
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Fallback for non-image content or empty content
            RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0)
                .fill(note.color)
                .overlay(
                    VStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Imported")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
        }
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
                // Use actual paper dimensions for proper aspect ratio
                let paperSize = PaperUtilities.paperSize(for: note.paperSize)
                let previewBounds = CGRect(origin: .zero, size: paperSize)
                let previewImage = pkDrawing.image(from: previewBounds, scale: 0.5)

                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit) // Use .fit instead of .fill to show full content
            } else {
                // Empty note - show paper with subtle pencil icon
                VStack {
                    Spacer()
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 30))
                        .foregroundColor(Color.gray.opacity(0.3))
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.6))
                    Spacer()
                }
            }
        }
    }

    // Preview view for text notes
    @ViewBuilder
    private var textNotePreview: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 0)
                .fill(note.color)

            // Show text preview if available
            if !note.content.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<min(8, note.content.components(separatedBy: .newlines).count), id: \.self) { lineIndex in
                        let lines = note.content.components(separatedBy: .newlines)
                        if lineIndex < lines.count {
                            HStack {
                                Text(lines[lineIndex])
                                    .font(.system(size: 8))
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
                .padding(8)
            } else {
                // Empty text note
                VStack {
                    Spacer()
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 30))
                        .foregroundColor(
                            colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
                        )
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(
                            colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
                        )
                    Spacer()
                }
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
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0))
                } else {
                    // Show content previews for notes without uploaded content
                    if note.noteType == .written {
                        writtenNotePreview
                            .frame(width: 160, height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if note.noteType == .text {
                        textNotePreview
                            .frame(width: 160, height: 200)
                            .clipped()
                    }
                }

                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .foregroundColor(note.isFavorite ? .yellow : .gray)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                // Selection indicator
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .white)
                        .font(.title2)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 28, height: 28)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                }

                Image(systemName: noteTypeIcon(note.noteType))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }

            HStack(spacing: 4) {
                Text(note.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fontWeight(.medium)
                    .font(.subheadline)

                // Rename dropdown button
                Button(action: {
                    newTitle = note.title
                    showRenamePopover = true
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 10))
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
        .background(
            isSelected && isSelectionMode 
                ? Color.blue.opacity(0.1) 
                : Color.clear
        )
        .cornerRadius(12)
        .contentShape(Rectangle())

    }

    // Use the DocumentsView noteTypeIcon function
    private func noteTypeIcon(_ type: NoteType) -> String {
        switch type {
        case .written:
            return "pencil"
        case .text:
            return "text.page"
        }
    }
}
