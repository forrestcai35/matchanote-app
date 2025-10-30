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
    @State private var previewImage: UIImage?
    @State private var isLoadingPreview = false

    init(note: Note, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.note = note
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    // Optimized preview view with async loading and caching
    @ViewBuilder
    private var notePreview: some View {
        if let preview = previewImage {
            Image(uiImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: previewSize.width, height: previewSize.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
        } else {
            // Clean placeholder while loading - no spinner needed as preloading handles it
            RoundedRectangle(cornerRadius: previewCornerRadius)
                .fill(note.color.opacity(0.15))
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(
                    Image(systemName: note.noteType == .written ? "doc.text" : "photo")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.4))
                )
        }
    }

    private var previewCornerRadius: CGFloat {
        note.noteType == .written ? 6 : 2
    }

    private var noteAspectRatio: CGFloat {
        PaperUtilities.paperAspectRatio(
            for: note.paperSize,
            orientation: note.paperOrientation
        )
    }

    private var previewSize: CGSize {
        let baseSize: CGSize = note.paperOrientation == .landscape
            ? CGSize(width: 40, height: 32)
            : CGSize(width: 32, height: 40)
        let area = baseSize.width * baseSize.height
        guard noteAspectRatio > 0, area > 0 else { return baseSize }
        let width = sqrt(area * noteAspectRatio)
        let height = area / width
        return CGSize(width: width, height: height)
    }

    private var isLandscape: Bool {
        note.paperOrientation == .landscape
    }

    private var favoriteButton: some View {
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
                
                // Note preview with shadow and async loading
                notePreview
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .task(id: note.dateModified) {
                        // Load preview asynchronously when note changes
                        // Check cache first for instant display
                        if let cached = PreviewCache.shared.getCachedPreview(for: note, size: .list) {
                            previewImage = cached
                        } else {
                            isLoadingPreview = true
                            previewImage = await PreviewCache.shared.getPreview(for: note, size: .list)
                            isLoadingPreview = false
                        }
                    }

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
                                .font(.jost(.headline()))

                            ClearableTextField(placeholder: "Note name", text: $newTitle)
                                .frame(width: 200)

                            HStack {
                                Button("Cancel") {
                                    showRenamePopover = false
                                }
                                .font(.jost(.body()))
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
                                .font(.jost(.body()))
                                .disabled(newTitle.isEmpty)
                            }
                        }
                        .padding()
                        .frame(minWidth: 250)
                    }

                    Text(note.dateModified, style: .date)
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Star indicator for notes
                if isLandscape {
                    VStack {
                        Spacer()
                        favoriteButton
                    }
                    .frame(height: 56)
                } else {
                    favoriteButton
                }
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
                                    .font(.jost(.headline()))

                                ClearableTextField(placeholder: "Folder name", text: $newName)
                                    .frame(width: 200)

                                HStack {
                                    Button("Cancel") {
                                        showRenamePopover = false
                                    }
                                    .font(.jost(.body()))
                                    .foregroundColor(.red)

                                    Spacer()

                                    Button("Save") {
                                        if storageManager.updateFolderName(folderId: folder.id, newName: newName) != nil {
                                            // Folder updated successfully
                                        }
                                        showRenamePopover = false
                                    }
                                    .font(.jost(.body()))
                                    .disabled(newName.isEmpty)
                                }
                            }
                            .padding()
                            .frame(minWidth: 250)
                        }
                    }

                    Text(folder.dateModified, style: .date)
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Star indicator
                Button(action: {
                    var updatedFolder = folder
                    updatedFolder.isFavorite.toggle()
                    updatedFolder.dateModified = Date()
                    _ = storageManager.saveFolder(updatedFolder)
                }) {
                    Image(systemName: folder.isFavorite ? "star.fill" : "star")
                        .foregroundColor(folder.isFavorite ? .yellow : .gray)
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
}
