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
                    .font(.jost(.subheadline()))

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
            .padding(.top, 5)
            .frame(width: 160)
            .multilineTextAlignment(.center)
            // Date
            Text(folder.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.jost(.caption()))
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
    @State private var previewImage: UIImage?
    @State private var isLoadingPreview = false

    init(note: Note, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.note = note
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    private var previewSize: CGSize {
        // Portrait: standard size (160x200)
        // Landscape: same as folder size (175x140)
        return note.paperOrientation == .landscape
            ? CGSize(width: 175, height: 140)
            : CGSize(width: 160, height: 200)
    }

    // Optimized preview view with async loading and caching
    @ViewBuilder
    private var notePreview: some View {
        if let preview = previewImage {
            TopAlignedFillImage(image: preview, targetSize: previewSize)
        } else {
            // Clean placeholder while loading - no spinner needed as preloading handles it
            RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0)
                .fill(note.color.opacity(0.15))
                .overlay(
                    Image(systemName: note.noteType == .written ? "doc.text" : "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                )
        }
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Note card - add padding for landscape to align with folders
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0)
                    .fill(note.color)
                    .frame(width: previewSize.width, height: previewSize.height)
                    .shadow(
                        color: itemShadow(in: colorScheme),
                        radius: note.noteType == .written ? 5 : 6,
                        x: 0,
                        y: 2
                    )

                // Content preview - using cached async preview generation
                notePreview
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: note.noteType == .written ? 10 : 0))
                    .task(id: note.dateModified) {
                        // Load preview asynchronously when note changes
                        // Check cache first for instant display
                        if let cached = PreviewCache.shared.getCachedPreview(for: note, size: .grid) {
                            previewImage = cached
                        } else {
                            isLoadingPreview = true
                            previewImage = await PreviewCache.shared.getPreview(for: note, size: .grid)
                            isLoadingPreview = false
                        }
                    }

                // Favorite button
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
            .padding(.top, note.paperOrientation == .landscape ? 60 : 0)

            Button(action: {
                newTitle = note.title
                showRenamePopover = true
            }) {
                HStack(spacing: 4) {
                    Text(note.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.jost(.subheadline()))
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
            .padding(.top, 5)
            .frame(width: 160)
            .multilineTextAlignment(.center)

            Text(note.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.jost(.caption()))
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .contentShape(Rectangle())

    }

 
}

// Helper view to render a UIImage scaled to fill and top-aligned within a target size
private struct TopAlignedFillImage: View {
    let image: UIImage
    let targetSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let imgSize = image.size
            // Compute scale to cover the frame (fill)
            let scale = max(frame.width / max(imgSize.width, 1), frame.height / max(imgSize.height, 1))
            let scaledHeight = imgSize.height * scale

            Image(uiImage: image)
                .resizable()
                .frame(width: frame.width, height: scaledHeight)
                .clipped()
        }
        .frame(width: targetSize.width, height: targetSize.height)
    }
}
