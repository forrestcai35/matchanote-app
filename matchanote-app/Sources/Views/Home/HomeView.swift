//
//  HomeView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI
import Combine
import PencilKit

struct SidebarItem: Identifiable {
    var id: String
    var title: String
    var icon: String
}

struct HomeView: View {
    @EnvironmentObject private var storageManager: StorageManager
    @EnvironmentObject private var documentHandler: DocumentHandler
    @State private var searchText = ""
    @State private var selectedNote: Note? = nil
    @State private var selectedItem = "documents"
    @State private var sortOption = "Date"
    @State private var isGridView = true
    @State private var showingSettings = false
    @State private var currentFolderID: UUID? = nil
    @State private var folderPath: [Folder] = []
    @State private var dragItem: (type: DragItemType, id: UUID)? = nil
    @State private var refreshID = UUID()
    @ObservedObject private var tabManager = TabManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var screenSize: CGSize = .zero
    @State private var showNewWrittenNoteView = false
    @State private var showNewFolderView = false
    @State private var showingFileImporter = false
    @State private var showMoveSheet = false
    @State private var notePendingMove: Note? = nil
    @State private var selectedDestinationFolderID: UUID? = nil
    
    // Selection state
    @State private var isSelectionMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var selectedFolders: Set<UUID> = []
    @State private var showBulkMoveSheet = false
    
    // Progress feedback for bulk operations
    @State private var isDeleting = false
    @State private var deletionProgress: Double = 0.0
    @State private var deletionStatus = ""

    private enum DragItemType {
        case folder
        case note
    }
    let sidebarItems = [
        SidebarItem(id: "documents", title: "Documents", icon: "folder"),
        SidebarItem(id: "recents", title: "Recents", icon: "clock.arrow.circlepath"),
        SidebarItem(id: "favorites", title: "Favorites", icon: "star"),
    ]
    
    // Dynamic sidebar width based on orientation
    private var sidebarWidth: CGFloat {
        return screenSize.width > screenSize.height ? 350 : 300
    }
    
    // Dynamic grid spacing based on orientation - keep same as landscape
    private var gridSpacing: CGFloat {
        return 20 // Same spacing for both orientations
    }
    
    // Dynamic grid item spacing based on orientation - keep same as landscape
    private var gridItemSpacing: CGFloat {
        return 20 // Same spacing for both orientations
    }
    // Filtered notes based on search text and current folder
    var filteredNotes: [Note] {
        let folderNotes = storageManager.notes.filter { note in
            if let currentFolderID = currentFolderID {
                // Get the folder to check its noteIDs
                if let folder = storageManager.folders.first(where: { $0.id == currentFolderID }) {
                    return folder.noteIDs.contains(note.id)
                }
                return false
            } else {
                // Root level - show notes that don't belong to any folder
                return !storageManager.folders.flatMap { $0.noteIDs }.contains(note.id)
            }
        }
        if searchText.isEmpty {
            return folderNotes
        } else {
            return folderNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    // Filtered Notes
    var filteredFolders: [Folder] {
        let folderItems = storageManager.folders.filter { folder in
            if let currentFolderID = currentFolderID {
                return folder.parentID == currentFolderID
            } else {
                return folder.parentID == nil
            }
        }
        if searchText.isEmpty {
            return folderItems
        } else {
            return folderItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var filteredFavoriteNotes: [Note] {
        let favoriteNotes = storageManager.notes.filter { $0.isFavorite }
        if searchText.isEmpty {
            return favoriteNotes
        } else {
            return favoriteNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var filteredFavoriteFolders: [Folder] {
        let favoriteFolders = storageManager.folders.filter { $0.isFavorite }
        if searchText.isEmpty {
            return favoriteFolders
        } else {
            return favoriteFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
            // Sidebar - Always visible
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)

                    Text("Matcha")
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                    Spacer()

                    // Settings button in sidebar
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .fontWeight(.medium)
                            .foregroundStyle(
                                colorScheme == .dark
                                    ? Color.matchabrown_dark : Color.matchabrown_light)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 15)

                // Settings sheet
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }

                searchBar
                sidebarList
                
                Spacer()
            }
            .frame(width: sidebarWidth)
            .frame(maxHeight: .infinity)
            .background(
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
                    .ignoresSafeArea(.container, edges: .top)
            )

            // Main content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                screenSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                screenSize = newSize
            }
        }
        .accentColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
    }

    // MARK: - Component Views
    private var searchBar: some View {
        MatchaSearchBar(text: $searchText)
            .padding(.horizontal)
            .padding(.top, 15)
    }

    private var sidebarList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(sidebarItems) { item in
                MatchaSidebarItem(
                    item: item,
                    isSelected: selectedItem == item.id,
                    onSelect: {
                        selectedItem = item.id
                        if item.id == "documents" {
                            currentFolderID = nil
                            folderPath = []
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Header with title and controls
            HStack {
                Text(currentViewTitle)
                    .font(.system(.largeTitle, design: .serif))
                    .bold()
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)

                Spacer()

                // Header controls
                HStack(spacing: 12) {
                    if isSelectionMode && (selectedNotes.count > 0 || selectedFolders.count > 0) {
                        bulkActionButtons
                    }
                    viewToggleButton
                    if !isSelectionMode {
                        headerNewButton
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)

            // Main content
            if selectedItem == "documents" {
                documentsView
            } else if selectedItem == "recents" {
                recentsView
            } else if selectedItem == "favorites" {
                favoritesView
            }
        }
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
    }

    // Helper computed property for the current view title
    private var currentViewTitle: String {
        switch selectedItem {
        case "documents":
            return currentFolderID == nil ? "Documents" : folderPath.last?.name ?? "Documents"
        case "recents":
            return "Recents"
        case "favorites":
            return "Favorites"
        default:
            return "Documents"
        }
    }

    // MARK: - Document view
    private var documentsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderPathBreadcrumbs
            documentContent
        }
        .fullScreenCover(item: $selectedNote) { note in
            NoteView(note: note)
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveNoteSheet(
                folders: storageManager.folders,
                currentFolderID: currentFolderID,
                selectedDestinationFolderID: $selectedDestinationFolderID,
                onCancel: {
                    notePendingMove = nil
                    showMoveSheet = false
                },
                onConfirm: {
                    if let note = notePendingMove {
                        moveNote(note, to: selectedDestinationFolderID)
                    }
                    notePendingMove = nil
                    showMoveSheet = false
                }
            )
        }
        .sheet(isPresented: $showBulkMoveSheet) {
            BulkMoveSheet(
                folders: storageManager.folders,
                currentFolderID: currentFolderID,
                selectedDestinationFolderID: $selectedDestinationFolderID,
                selectedNotes: selectedNotes,
                selectedFolders: selectedFolders,
                onCancel: {
                    showBulkMoveSheet = false
                },
                onConfirm: {
                    moveSelectedItems(to: selectedDestinationFolderID)
                    showBulkMoveSheet = false
                }
            )
        }
    }

    // MARK: - Folder navigation breadcrumbs
    private var folderPathBreadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            folderPathContent
        }
        .frame(height: folderPath.isEmpty ? 0 : 36)
    }

    // Extract folder path content to reduce complexity
    private var folderPathContent: some View {
        HStack {
            if !folderPath.isEmpty {
                // Root folder navigation
                rootFolderButton

                // Chevron between path items
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Show path of folders
                folderPathLinks
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var rootFolderButton: some View {
        Button(action: {
            currentFolderID = nil
            folderPath = []
        }) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.caption)
                Text("Home")
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var folderPathLinks: some View {
        ForEach(0..<folderPath.count, id: \.self) { index in
            folderPathLink(for: index)

            // Add chevron between path items, but not after the last one
            if index < folderPath.count - 1 {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private func folderPathLink(for index: Int) -> some View {
        Button(action: {
            // Navigate to this folder in the path
            if index == folderPath.count - 1 {
                // Already in this folder, do nothing
                return
            }

            // Navigate to the selected folder
            currentFolderID = folderPath[index].id
            folderPath = Array(folderPath.prefix(index + 1))
        }) {
            HStack(spacing: 4) {

                Text(folderPath[index].name)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                index == folderPath.count - 1
                    ? (colorScheme == .dark
                        ? Color.matchalight_dark.opacity(0.2)
                        : Color.matchalight_light.opacity(0.2)) : Color.gray.opacity(0.1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    // MARK: - Document View Components
    // Note: documentHeader removed - now handled by unified header in contentView

    //    private var sortMenu: some View {
    //        Menu {
    //            Button("Date", action: { sortOption = "Date" })
    //                .fontWeight(.medium)
    //            Button("Name", action: { sortOption = "Name" })
    //                .fontWeight(.medium)
    //            Button("Type", action: { sortOption = "Type" })
    //                .fontWeight(.medium)
    //
    //        } label: {
    //            Label {
    //                Text(sortOption)
    //                    .fontWeight(.medium)
    //            } icon: {
    //                Image(systemName: "arrow.up.arrow.down")
    //            }
    //            .foregroundColor(
    //                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
    //            )
    //            .fontWeight(.medium)
    //        }
    //    }
    private var viewToggleButton: some View {
        HStack(spacing: 8) {
            // Grid/List toggle
            Button(action: { isGridView.toggle() }) {
                Label(
                    isGridView ? "Grid View" : "List View",
                    systemImage: isGridView ? "square.grid.2x2" : "list.bullet"
                )
                .fontWeight(.medium)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .labelStyle(.iconOnly)
                .padding(8)
                .cornerRadius(8)
            }
            .help(isGridView ? "Switch to List View" : "Switch to Grid View")
            
            // Selection mode toggle
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        // Clear selections when exiting selection mode
                        selectedNotes.removeAll()
                        selectedFolders.removeAll()
                    }
                }
            }) {
                Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .fontWeight(.medium)
                    .foregroundColor(
                        isSelectionMode 
                            ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                            : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    )
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelectionMode 
                                    ? (colorScheme == .dark ? Color.matchalight_dark.opacity(0.2) : Color.matchalight_light.opacity(0.2))
                                    : Color.clear
                            )
                    )
            }
            .help(isSelectionMode ? "Exit Selection Mode" : "Enter Selection Mode")
        }
    }
    
    // MARK: - Bulk Action Buttons
    private var bulkActionButtons: some View {
        Group {
            if isPortrait {
                // Compact horizontal layout for portrait
                portraitBulkActionButtons
            } else {
                // Full layout for landscape
                landscapeBulkActionButtons
            }
        }
    }
    
    // Portrait: Compact horizontal layout
    private var portraitBulkActionButtons: some View {
        HStack(spacing: 6) {
            // Selection count (compact)
            Text("\(selectedNotes.count + selectedFolders.count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                )
            
            // Move button (icon only)
            Button(action: {
                showBulkMoveSheet = true
            }) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDeleting)
            
            // Delete button (icon only)
            Button(action: {
                deleteSelectedItems()
            }) {
                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(6)
                } else {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(6)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDeleting)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.1))
            )
        }
    }
    
    // Landscape: Full layout with progress indicator
    private var landscapeBulkActionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Selection count
                Text("\(selectedNotes.count + selectedFolders.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    )
                
                // Move button
                Button(action: {
                    showBulkMoveSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Move")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeleting)
                
                // Delete button
                Button(action: {
                    deleteSelectedItems()
                }) {
                    HStack(spacing: 4) {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(isDeleting ? "Deleting..." : "Delete")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeleting)
            }
            
            // Progress indicator for large operations
            if isDeleting && !deletionStatus.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text(deletionStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(deletionProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: deletionProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.05))
                )
            }
        }
    }
    
    // Helper to determine if we're in portrait mode
    private var isPortrait: Bool {
        screenSize.height > screenSize.width
    }
    
    private var documentContent: some View {
        ScrollView {
            if filteredNotes.isEmpty && filteredFolders.isEmpty {
                EmptyDocumentsView(showNewWrittenNoteView: $showNewWrittenNoteView)
            } else if isGridView {
                gridView
            } else {
                listView
            }
        }
    }
    private var gridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: gridItemSpacing)],
            spacing: gridSpacing
        ) {
            // Break grid content into separate views
            foldersGridContent
            notesGridContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .id(refreshID)
        // Simplify root drop target
        .onDrop(of: ["public.text"], isTargeted: nil) { _, _ in
            // Only handle drop if we're at the root level
            guard currentFolderID == nil else { return false }
            return handleDrop()
        }
    }
    // Extracted folders grid content
    private var foldersGridContent: some View {
        ForEach(filteredFolders) { folder in
            folderGridItem(for: folder)
        }
    }

    // Extracted notes grid content
    private var notesGridContent: some View {
        ForEach(filteredNotes) { note in
            noteGridItem(for: note)
        }
    }

    // Reset drag state
    private func resetDragState() {
        print("Resetting drag state")
        self.dragItem = nil
    }

    // Helper to apply common modifiers for items (both notes and folders)
    private func applyCommonItemModifiers<T: View, U: Identifiable>(
        view: T,
        for item: U,
        onTap: @escaping () -> Void,
        contextMenu: @escaping () -> some View,
        dragStartHandler: @escaping () -> NSItemProvider,
        dragPreviewHandler: @escaping () -> some View,
        dropHandler: @escaping () -> Bool
    ) -> some View {
        view
            .onTapGesture {
                onTap()
            }
            .contextMenu {
                contextMenu()
            }
            .onDrag {
                dragStartHandler()
            } preview: {
                dragPreviewHandler()
            }
            .onDrop(of: ["public.text"], isTargeted: nil) { _, _ in
                dropHandler()
            }
    }

    // Helper to add consistent shadow styling
    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    // Centralize note type icon logic
    private func noteTypeIcon(_ type: NoteType) -> String {
        return "pencil"
    }

    // MARK: - Drag and Drop Handling
    // Generic drag preview function that works for both folders and notes
    private func dragPreview(for item: Any) -> some View {
        let width: CGFloat = 120
        let height: CGFloat = 150

        if item is Folder {
            return AnyView(
                Image("folder")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .background(Color.clear)
            )
        } else if let note = item as? Note {
            return AnyView(
                ZStack {
                    if note.noteType == .written {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(note.color)
                            .frame(width: width, height: height)

                        Image(systemName: "pencil.tip")
                            .font(.system(size: 30))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .background(Color.clear)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // Helper function to create a folder grid item
    private func folderGridItem(for folder: Folder) -> some View {
        let isSelected = selectedFolders.contains(folder.id)
        
        return applyCommonItemModifiers(
            view: GridFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode),
            for: folder,
            onTap: {
                if isSelectionMode {
                    toggleFolderSelection(folder.id)
                } else {
                    navigateToFolder(folder)
                }
            },
            contextMenu: {
                folderContextMenu(folder)
            },
            dragStartHandler: {
                startDragging(folder: folder)
            },
            dragPreviewHandler: {
                dragPreview(for: folder)
            },
            dropHandler: {
                handleDrop(onto: folder)
            }
        )
    }

    // Helper function to create a note grid item
    private func noteGridItem(for note: Note) -> some View {
        let isSelected = selectedNotes.contains(note.id)
        
        return Button(action: {
            if isSelectionMode {
                toggleNoteSelection(note.id)
            } else {
                var opened = note
                opened.lastOpenedAt = Date()
                let saved = storageManager.saveNote(opened)
                TabManager.shared.updateNote(saved)
                TabManager.shared.openTab(note: saved)
                selectedNote = saved
            }
        }) {
            GridItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            noteContextMenu(note)
        }
        .onDrag {
            startDragging(note: note)
        } preview: {
            dragPreview(for: note)
        }
    }

    private var listView: some View {
        VStack(spacing: 12) {
            listContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .id(refreshID)
        .onDrop(of: ["public.text"], isTargeted: nil) { _, _ in
            guard currentFolderID == nil else { return false }
            return handleDrop()
        }
    }

    // Extract list content to reduce complexity
    private var listContent: some View {
        LazyVStack(spacing: 8) {
            // Show folders first
            foldersListContent
            // Then show notes
            notesListContent
        }
    }

    // Extracted folders list content
    private var foldersListContent: some View {
        ForEach(filteredFolders) { folder in
            folderListItem(for: folder)
        }
    }

    // Extracted notes list content
    private var notesListContent: some View {
        ForEach(filteredNotes) { note in
            noteListItem(for: note)
        }
    }

    // Helper function to create a folder list item
    private func folderListItem(for folder: Folder) -> some View {
        let isSelected = selectedFolders.contains(folder.id)
        
        return applyCommonItemModifiers(
            view: ListFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode),
            for: folder,
            onTap: {
                if isSelectionMode {
                    toggleFolderSelection(folder.id)
                } else {
                    navigateToFolder(folder)
                }
            },
            contextMenu: {
                folderContextMenu(folder)
            },
            dragStartHandler: {
                startDragging(folder: folder)
            },
            dragPreviewHandler: {
                dragPreview(for: folder)
            },
            dropHandler: {
                handleDrop(onto: folder)
            }
        )
    }

    // Helper function to create a note list item
    private func noteListItem(for note: Note) -> some View {
        let isSelected = selectedNotes.contains(note.id)
        
        return Button(action: {
            if isSelectionMode {
                toggleNoteSelection(note.id)
            } else {
                var opened = note
                opened.lastOpenedAt = Date()
                let saved = storageManager.saveNote(opened)
                TabManager.shared.updateNote(saved)
                TabManager.shared.openTab(note: saved)
                selectedNote = saved
            }
        }) {
            ListItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            noteContextMenu(note)
        }
        .onDrag {
            startDragging(note: note)
        } preview: {
            dragPreview(for: note)
        }
    }

    // Start dragging a folder
    private func startDragging(folder: Folder) -> NSItemProvider {
        dragItem = (.folder, folder.id)
        return NSItemProvider(object: folder.id.uuidString as NSString)
    }

    // Start dragging a note
    private func startDragging(note: Note) -> NSItemProvider {
        dragItem = (.note, note.id)
        return NSItemProvider(object: note.id.uuidString as NSString)
    }

    // Handle drop to root level
    private func handleDropToRoot() -> Bool {
        guard let draggedItemType = self.dragItem else {
            return false
        }

        switch draggedItemType.type {
        case .folder:
            // Move folder to root level
            if let sourceFolder = storageManager.folders.first(where: {
                $0.id == draggedItemType.id
            }) {
                var updatedFolder = sourceFolder
                updatedFolder.parentID = nil
                _ = storageManager.saveFolder(updatedFolder)
                return true
            }
        case .note:
            // Remove note from all folders
            let foldersContainingNote = storageManager.folders.filter {
                $0.noteIDs.contains(draggedItemType.id)
            }
            for folder in foldersContainingNote {
                var updatedFolder = folder
                updatedFolder.noteIDs.removeAll(where: { $0 == draggedItemType.id })
                updatedFolder.dateModified = Date()
                _ = storageManager.saveFolder(updatedFolder)
                print("Removed note \(draggedItemType.id) from folder \(updatedFolder.id)")
            }
            return true
        }

        return false
    }

    // Handle drop onto a specific folder
    private func handleDrop(onto targetFolder: Folder? = nil) -> Bool {
        guard let (type, id) = dragItem else { return false }

        switch type {
        case .folder:
            if let targetFolder = targetFolder {
                // Don't allow dropping on self or circular references
                if id == targetFolder.id
                    || wouldCreateCircularReference(sourceID: id, targetID: targetFolder.id)
                {
                    return false
                }

                // Move folder to target folder
                if let sourceFolderIndex = storageManager.folders.firstIndex(where: { $0.id == id }) {
                    storageManager.folders[sourceFolderIndex].parentID = targetFolder.id

                    // Update target folder's modified date
                    if let targetFolderIndex = storageManager.folders.firstIndex(where: { $0.id == targetFolder.id }) {
                        storageManager.folders[targetFolderIndex].dateModified = Date()
                    }

                    // Save all folder changes at once
                    storageManager.saveFoldersState()
                }
            } else {
                // Move to root
                if let sourceFolderIndex = storageManager.folders.firstIndex(where: { $0.id == id }) {
                    storageManager.folders[sourceFolderIndex].parentID = nil
                    storageManager.saveFoldersState()
                }
            }

        case .note:
            // Remove note from all folders that contain it
            for i in 0..<storageManager.folders.count {
                if storageManager.folders[i].noteIDs.contains(id) {
                    storageManager.folders[i].noteIDs.removeAll { $0 == id }
                    storageManager.folders[i].dateModified = Date()
                }
            }

            // Add to target folder if provided
            if let targetFolder = targetFolder {
                if let targetIndex = storageManager.folders.firstIndex(where: { $0.id == targetFolder.id }) {
                    storageManager.folders[targetIndex].noteIDs.append(id)
                    storageManager.folders[targetIndex].dateModified = Date()
                }
            }

            // Save all folder changes at once to ensure persistence
            storageManager.saveFoldersState()
        }

        // Refresh UI
        DispatchQueue.main.async {
            self.refreshID = UUID()
            self.dragItem = nil
        }

        return true
    }

    // Helper to check if moving a folder would create a circular reference
    private func wouldCreateCircularReference(sourceID: UUID, targetID: UUID) -> Bool {
        // If source and target are the same, it would create a circular reference
        if sourceID == targetID {
            return true
        }

        // Check if target is a child of source (which would create a loop)
        var currentID = targetID
        while let folder = storageManager.folders.first(where: { $0.id == currentID }) {
            if folder.parentID == sourceID {
                return true
            }

            if let parentID = folder.parentID {
                currentID = parentID
            } else {
                break
            }
        }

        return false
    }

    // Helper function to navigate into a folder
    private func navigateToFolder(_ folder: Folder) {
        currentFolderID = folder.id

        // Update the folder path
        if let index = folderPath.firstIndex(where: { $0.id == folder.id }) {
            // This folder is already in our path, truncate to this point
            folderPath = Array(folderPath.prefix(through: index))
        } else {
            // Add this folder to our path
            folderPath.append(folder)
        }
    }

    // Helper function to navigate to a folder from favorites
    private func navigateToFolderFromFavorites(_ folder: Folder) {
        // Switch to documents view
        selectedItem = "documents"
        
        // Build the folder path from the folder up to the root
        var path: [Folder] = []
        var currentFolder: Folder? = folder
        
        // Traverse up to build the path
        while let folder = currentFolder {
            path.insert(folder, at: 0)
            
            // Find parent folder if it exists
            if let parentID = folder.parentID {
                currentFolder = storageManager.folders.first(where: { $0.id == parentID })
            } else {
                currentFolder = nil
            }
        }
        
        // Set the current folder and path
        folderPath = path
        currentFolderID = folder.id
    }

    private func folderContextMenu(_ folder: Folder) -> some View {
        Group {
            Button(action: {
                // Toggle favorite
                var updatedFolder = folder
                updatedFolder.toggleFavorite()
                let savedFolder = storageManager.saveFolder(updatedFolder)
            }) {
                Label(
                    folder.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: folder.isFavorite ? "star.slash" : "star"
                )
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    storageManager.deleteFolder(withID: folder.id)
                }
            ) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // Context menu for notes
    private func noteContextMenu(_ note: Note) -> some View {
        Group {
            Button(action: {
                notePendingMove = note
                selectedDestinationFolderID = currentFolderID
                showMoveSheet = true
            }) {
                Label("Move to...", systemImage: "folder")
            }

            Button(action: {
                // Toggle favorite
                var updatedNote = note
                updatedNote.isFavorite.toggle()
                let savedNote = storageManager.saveNote(updatedNote)
                TabManager.shared.updateNote(savedNote)
            }) {
                Label(
                    note.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: note.isFavorite ? "star.slash" : "star"
                )
            }

            Button(action: {
                exportNote(note)
            }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    storageManager.deleteNote(withID: note.id)
                }
            ) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Export Functionality
    private func exportNote(_ note: Note) {
        // Always export as PDF for consistency with NoteView
        exportNoteAsPDF(note)
    }
    
    private func exportNoteAsPDF(_ note: Note) {
        // Use the universal export manager
        ExportManager.shared.presentExportShareSheet(for: note)
    }
    

    // MARK: - Selection Helpers
    private func toggleNoteSelection(_ noteID: UUID) {
        if selectedNotes.contains(noteID) {
            selectedNotes.remove(noteID)
        } else {
            selectedNotes.insert(noteID)
        }
    }
    
    private func toggleFolderSelection(_ folderID: UUID) {
        if selectedFolders.contains(folderID) {
            selectedFolders.remove(folderID)
        } else {
            selectedFolders.insert(folderID)
        }
    }
    
    // MARK: - Bulk Operations
    private func deleteSelectedItems() {
        guard !isDeleting else { return }
        
        let noteIDs = Array(selectedNotes)
        let folderIDs = Array(selectedFolders)
        let totalItems = noteIDs.count + folderIDs.count
        
        guard totalItems > 0 else { return }
        
        // Show progress for large operations
        if totalItems > 10 {
            isDeleting = true
            deletionProgress = 0.0
            deletionStatus = "Deleting \(totalItems) items..."
        }
        
        // Use optimized bulk deletion methods
        Task {
            if !noteIDs.isEmpty {
                await MainActor.run {
                    if totalItems > 10 {
                        deletionStatus = "Deleting \(noteIDs.count) notes..."
                        deletionProgress = 0.3
                    }
                }
                storageManager.deleteNotesBulk(noteIDs: noteIDs)
            }
            
            if !folderIDs.isEmpty {
                await MainActor.run {
                    if totalItems > 10 {
                        deletionStatus = "Deleting \(folderIDs.count) folders..."
                        deletionProgress = 0.7
                    }
                }
                storageManager.deleteFoldersBulk(folderIDs: folderIDs)
            }
            
            await MainActor.run {
                // Clear selections
                selectedNotes.removeAll()
                selectedFolders.removeAll()
                
                // Hide progress
                isDeleting = false
                deletionProgress = 0.0
                deletionStatus = ""
                
                // Refresh UI
                self.refreshID = UUID()
            }
        }
    }
    
    private func moveSelectedItems(to destinationFolderID: UUID?) {
        // Move selected notes
        for noteID in selectedNotes {
            if let note = storageManager.notes.first(where: { $0.id == noteID }) {
                moveNote(note, to: destinationFolderID)
            }
        }
        
        // Move selected folders
        for folderID in selectedFolders {
            if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folderID }) {
                storageManager.folders[folderIndex].parentID = destinationFolderID
            }
        }
        
        // Save folder changes
        storageManager.saveFoldersState()
        
        // Clear selections
        selectedNotes.removeAll()
        selectedFolders.removeAll()
        
        // Refresh UI
        DispatchQueue.main.async {
            self.refreshID = UUID()
        }
    }
    
    private func moveNote(_ note: Note, to destinationFolderID: UUID?) {
        print("Moving note '\(note.title)' to folder: \(destinationFolderID?.uuidString ?? "Home")")
        
        // Remove note from all folders first
        for i in 0..<storageManager.folders.count {
            if storageManager.folders[i].noteIDs.contains(note.id) {
                storageManager.folders[i].noteIDs.removeAll { $0 == note.id }
                storageManager.folders[i].dateModified = Date()
                print("Removed note from folder: \(storageManager.folders[i].name)")
            }
        }

        // If destination is a folder, add it
        if let destID = destinationFolderID,
           let index = storageManager.folders.firstIndex(where: { $0.id == destID }) {
            storageManager.folders[index].noteIDs.append(note.id)
            storageManager.folders[index].dateModified = Date()
            print("Added note to folder: \(storageManager.folders[index].name)")
        } else if destinationFolderID == nil {
            print("Moved note to Home (no folder)")
        } else {
            print("Warning: Destination folder not found!")
        }

        // Persist folder state changes
        storageManager.saveFoldersState()

        // Refresh UI context if needed
        DispatchQueue.main.async {
            self.refreshID = UUID()
        }
    }

    private func createItemButton(inGrid: Bool) -> some View {
        Menu {
            // Note creation options
            Button {
                showNewWrittenNoteView = true
            } label: {
                Label("Note", systemImage: "pencil")
            }

            // Folder creation option
            Button {
                showNewFolderView = true
            } label: {
                Label("Folder", systemImage: "folder")
            }


            // Upload
            Button {
                showingFileImporter = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc")
            }

        } label: {
            if inGrid {
                gridNewButton
            } else {
                listNewButton
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showNewWrittenNoteView) {
            NewWrittenNoteView(onSave: { newNote in
                // Add to current folder if we're in one
                if let currentFolderID = currentFolderID,
                    let folderIndex = storageManager.folders.firstIndex(where: {
                        $0.id == currentFolderID
                    })
                {
                    var updatedFolder = storageManager.folders[folderIndex]
                    updatedFolder.addNote(noteID: newNote.id)
                    _ = storageManager.saveFolder(updatedFolder)
                }
                let savedNote = storageManager.saveNote(newNote)
                TabManager.shared.openTab(note: savedNote)
                selectedNote = savedNote
            })
        }
        .sheet(isPresented: $showNewFolderView) {
            NewFolderView(
                parentFolderID: currentFolderID,
                onSave: { newFolder in
                    _ = storageManager.saveFolder(newFolder)
                }
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                handleImportedFiles(urls)
            } catch {
                print("Error importing file: \(error)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .documentImported)) { notification in
            if let userInfo = notification.userInfo,
               let url = userInfo["url"] as? URL,
               let type = userInfo["type"] as? String {
                handleDocumentImport(url: url, type: type)
            }
        }
        .onChange(of: documentHandler.shouldProcessDocument) { _, shouldProcess in
            if shouldProcess {
                documentHandler.processDocument()
            }
        }
    }

    private func handleDocumentImport(url: URL, type: String) {
        print("HomeView: Handling document import - URL: \(url), Type: \(type)")
        
        switch type {
        case "pdf":
            createNoteFromPDF(url: url, fileName: url.deletingPathExtension().lastPathComponent)
        case "image":
            createNoteFromImage(url: url, fileName: url.deletingPathExtension().lastPathComponent)
        case "matcha":
            createNoteFromMatchaFile(url: url, fileName: url.deletingPathExtension().lastPathComponent)
        default:
            print("HomeView: Unknown document type: \(type)")
        }
    }

    private func handleImportedFiles(_ urls: [URL]) {
        for url in urls {
            #if canImport(UIKit)
                if url.startAccessingSecurityScopedResource() {
                    createNoteFromImportedFile(url)
                    url.stopAccessingSecurityScopedResource()
                }
            #else
                createNoteFromImportedFile(url)
            #endif
        }
    }

    private func createNoteFromImportedFile(_ url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent

        // Check if it's a PDF or image file
        if fileExtension == "pdf" {
            createNoteFromPDF(url: url, fileName: fileName)
        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"].contains(fileExtension) {
            createNoteFromImage(url: url, fileName: fileName)
        } else {
            // Ignore unsupported file types for uploads
            print("Unsupported upload file type: \(fileExtension)")
        }
    }

    private func createNoteFromPDF(url: URL, fileName: String) {
        guard let pdf = CGPDFDocument(url as CFURL) else {
            print("Error: Could not load PDF from \(url)")
            return
        }

        let pageCount = pdf.numberOfPages
        var imageDataByPage: [String: [Data]] = [:]

        // Extract each page as an image at native page size
        for pageIndex in 1...pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: pageRect.size))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page)
                context.cgContext.restoreGState()
            }

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                imageDataByPage[String(pageIndex - 1)] = [imageData]
            }
        }

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "PDF")

        let newNote = Note(
            title: noteTitle,
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        saveAndOpenNote(newNote)
    }

    private func createNoteFromImage(url: URL, fileName: String) {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Could not load image data from \(url)")
            return
        }

        // Create a note with the image as background on the first page
        let imageDataByPage: [String: [Data]] = ["0": [imageData]]

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "Image")

        let newNote = Note(
            title: noteTitle,
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        saveAndOpenNote(newNote)
    }

    private func createNoteFromMatchaFile(url: URL, fileName: String) {
        do {
            // Read the Matcha note data
            let matchaData = try Data(contentsOf: url)
            
            // Decode the note from JSON
            let importedNote = try JSONDecoder().decode(Note.self, from: matchaData)
            
            // Create a new note with the imported data but with a new ID and current timestamp
            let newNote = Note(
                title: importedNote.title,
                subject: importedNote.subject,
                color: importedNote.color,
                dateCreated: Date(),
                dateModified: Date(),
                lastOpenedAt: nil,
                isFavorite: false,
                content: importedNote.content,
                noteType: importedNote.noteType,
                paperColor: importedNote.paperColor,
                paperStyle: importedNote.paperStyle,
                paperSize: importedNote.paperSize,
                drawingDataByPage: importedNote.drawingDataByPage,
                imageDataByPage: importedNote.imageDataByPage,
                textBoxDataByPage: importedNote.textBoxDataByPage,
                bookmarkedPages: importedNote.bookmarkedPages
            )
            
            saveAndOpenNote(newNote)
        } catch {
            print("Error: Could not load Matcha note from \(url): \(error)")
        }
    }

    private func createTextNoteFromFile(url: URL, fileName: String) {
        let newNote = Note(
            title: fileName,
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            content: "Imported from \(fileName)",
            noteType: .written
        )

        saveAndOpenNote(newNote)
    }

    // MARK: - Helper Functions for Upload
    private func createNoteTitle(from fileName: String, type: String) -> String {
        // Clean up the filename and create a better title
        let cleanName = fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        // If the name is too long, truncate it
        if cleanName.count > 30 {
            let truncated = String(cleanName.prefix(27))
            return "\(truncated)..."
        }
        
        return cleanName.isEmpty ? "Imported \(type)" : cleanName
    }
    
    
    
    private func saveAndOpenNote(_ newNote: Note) {
        // Add to current folder if we're in one
        if let currentFolderID = currentFolderID,
            let folderIndex = storageManager.folders.firstIndex(where: { $0.id == currentFolderID })
        {
            var updatedFolder = storageManager.folders[folderIndex]
            updatedFolder.addNote(noteID: newNote.id)
            _ = storageManager.saveFolder(updatedFolder)
        }

        let savedNote = storageManager.saveNote(newNote)

        // Optionally open the imported note
        TabManager.shared.openTab(note: savedNote)
        selectedNote = savedNote
    }

    private var listNewButton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.matchalight_light)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Item")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Create note or folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .contentShape(Rectangle())
    }

    private var gridNewButton: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.matchalight_light.opacity(0.1),
                                Color.matchalight_light.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.matchalight_light.opacity(0.3),
                                        Color.matchalight_light.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .frame(width: 160, height: 200)
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.matchalight_light)
                    }
                    
                    VStack(spacing: 4) {
                        Text("New Item")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Create note or folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .frame(width: 160)
    }

    // MARK: - Favorites view
    private var favoritesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            favoritesContent
        }
        .fullScreenCover(item: $selectedNote) { note in
            NoteView(note: note)
        }
    }

    private var favoritesContent: some View {
        ScrollView {
            if filteredFavoriteNotes.isEmpty && filteredFavoriteFolders.isEmpty {
                EmptyFavoritesView(
                    selectedItem: $selectedItem,
                    currentFolderID: $currentFolderID,
                    folderPath: $folderPath
                )
            } else if isGridView {
                favoritesGridView
            } else {
                favoritesListView
            }
        }
    }

    // MARK: - Recents view
    private var recentsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            recentsContent
        }
        .fullScreenCover(item: $selectedNote) { note in
            NoteView(note: note)
        }
    }

    private var recentsContent: some View {
        ScrollView {
            if recentNotes.isEmpty {
                EmptyRecentsView(
                    selectedItem: $selectedItem,
                    currentFolderID: $currentFolderID,
                    folderPath: $folderPath
                )
            } else if isGridView {
                recentsGridView
            } else {
                recentsListView
            }
        }
    }

    private var recentNotes: [Note] {
        let cutoff =
            Calendar.current.date(byAdding: .day, value: -1, to: Date())
            ?? Date().addingTimeInterval(-86400)
        let recents = storageManager.notes.filter { note in
            if let lastOpened = note.lastOpenedAt {
                return lastOpened >= cutoff
            }
            return false
        }
        if sortOption == "Name" {
            return recents.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else if sortOption == "Type" {
            return recents.sorted { $0.noteType.rawValue < $1.noteType.rawValue }
        } else {
            return recents.sorted {
                ($0.lastOpenedAt ?? Date.distantPast) > ($1.lastOpenedAt ?? Date.distantPast)
            }
        }
    }

    private var recentsGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 20)],
            spacing: 20
        ) {
            ForEach(recentNotes) { note in
                let isSelected = selectedNotes.contains(note.id)
                Button(action: {
                    if isSelectionMode {
                        toggleNoteSelection(note.id)
                    } else {
                        var opened = note
                        opened.lastOpenedAt = Date()
                        let saved = storageManager.saveNote(opened)
                        TabManager.shared.updateNote(saved)
                        TabManager.shared.openTab(note: saved)
                        selectedNote = saved
                    }
                }) {
                    GridItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    noteContextMenu(note)
                }
                .onDrag {
                    startDragging(note: note)
                } preview: {
                    dragPreview(for: note)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .id(refreshID)
    }

    private var recentsListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(recentNotes) { note in
                let isSelected = selectedNotes.contains(note.id)
                Button(action: {
                    if isSelectionMode {
                        toggleNoteSelection(note.id)
                    } else {
                        var opened = note
                        opened.lastOpenedAt = Date()
                        let saved = storageManager.saveNote(opened)
                        TabManager.shared.updateNote(saved)
                        TabManager.shared.openTab(note: saved)
                        selectedNote = saved
                    }
                }) {
                    ListItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    noteContextMenu(note)
                }
                .onDrag {
                    startDragging(note: note)
                } preview: {
                    dragPreview(for: note)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .id(refreshID)
    }

    private var favoritesGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 20)],
            spacing: 20
        ) {
            // Show favorite folders first
            ForEach(filteredFavoriteFolders) { folder in
                let isSelected = selectedFolders.contains(folder.id)
                Button(action: {
                    if isSelectionMode {
                        toggleFolderSelection(folder.id)
                    } else {
                        // Navigate to folder from favorites
                        navigateToFolderFromFavorites(folder)
                    }
                }) {
                    GridFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    folderContextMenu(folder)
                }
                .onDrag {
                    startDragging(folder: folder)
                } preview: {
                    dragPreview(for: folder)
                }
            }

            // Then show favorite notes
            ForEach(filteredFavoriteNotes) { note in
                let isSelected = selectedNotes.contains(note.id)
                Button(action: {
                    if isSelectionMode {
                        toggleNoteSelection(note.id)
                    } else {
                        var opened = note
                        opened.lastOpenedAt = Date()
                        let saved = storageManager.saveNote(opened)
                        TabManager.shared.updateNote(saved)
                        TabManager.shared.openTab(note: saved)
                        selectedNote = saved
                    }
                }) {
                    GridItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    noteContextMenu(note)
                }
                .onDrag {
                    startDragging(note: note)
                } preview: {
                    dragPreview(for: note)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .id(refreshID)
    }

    private var favoritesListView: some View {
        LazyVStack(spacing: 8) {
            // Show favorite folders first
            ForEach(filteredFavoriteFolders) { folder in
                let isSelected = selectedFolders.contains(folder.id)
                Button(action: {
                    if isSelectionMode {
                        toggleFolderSelection(folder.id)
                    } else {
                        // Navigate to folder from favorites
                        navigateToFolderFromFavorites(folder)
                    }
                }) {
                    ListFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    folderContextMenu(folder)
                }
                .onDrag {
                    startDragging(folder: folder)
                } preview: {
                    dragPreview(for: folder)
                }
            }

            // Then show favorite notes
            ForEach(filteredFavoriteNotes) { note in
                let isSelected = selectedNotes.contains(note.id)
                Button(action: {
                    if isSelectionMode {
                        toggleNoteSelection(note.id)
                    } else {
                        var opened = note
                        opened.lastOpenedAt = Date()
                        let saved = storageManager.saveNote(opened)
                        TabManager.shared.updateNote(saved)
                        TabManager.shared.openTab(note: saved)
                        selectedNote = saved
                    }
                }) {
                    ListItemView(note: note, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    noteContextMenu(note)
                }
                .onDrag {
                    startDragging(note: note)
                } preview: {
                    dragPreview(for: note)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .id(refreshID)
    }

}

// MARK: - Header "+ New" Button
extension HomeView {
    private var headerNewButton: some View {
        Menu {
            // Note creation options
            Button {
                showNewWrittenNoteView = true
            } label: {
                Label("Note", systemImage: "pencil")
            }

            // Folder creation option
            Button {
                showNewFolderView = true
            } label: {
                Label("Folder", systemImage: "folder")
            }


            // Upload
            Button {
                showingFileImporter = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc")
            }

        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.matchalight_light)
                }
                
                Text("New")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showNewWrittenNoteView) {
            NewWrittenNoteView(onSave: { newNote in
                // Add to current folder if we're in one
                if let currentFolderID = currentFolderID,
                    let folderIndex = storageManager.folders.firstIndex(where: {
                        $0.id == currentFolderID
                    })
                {
                    var updatedFolder = storageManager.folders[folderIndex]
                    updatedFolder.addNote(noteID: newNote.id)
                    _ = storageManager.saveFolder(updatedFolder)
                }
                let savedNote = storageManager.saveNote(newNote)
                TabManager.shared.openTab(note: savedNote)
                selectedNote = savedNote
            })
        }
        .sheet(isPresented: $showNewFolderView) {
            NewFolderView(
                parentFolderID: currentFolderID,
                onSave: { newFolder in
                    _ = storageManager.saveFolder(newFolder)
                }
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                handleImportedFiles(urls)
            } catch {
                print("Error importing file: \(error)")
            }
        }
    }
}

// MARK: - Move Note Sheet
struct MoveNoteSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID?
    @Binding var selectedDestinationFolderID: UUID?
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Move to")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Destination list
            List {
                // Home (no folder)
                HStack {
                    Image(systemName: "house")
                    Text("Home")
                    Spacer()
                    if selectedDestinationFolderID == nil { 
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDestinationFolderID = nil
                }

                // Top-level folders only (no parent)
                ForEach(folders.filter { $0.parentID == nil }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.name)
                        Spacer()
                        if selectedDestinationFolderID == folder.id { 
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDestinationFolderID = folder.id
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Button("Cancel") { 
                    onCancel() 
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Move") { 
                    onConfirm() 
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .background(
            colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
        )
    }
}

// MARK: - Bulk Move Sheet
struct BulkMoveSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID?
    @Binding var selectedDestinationFolderID: UUID?
    let selectedNotes: Set<UUID>
    let selectedFolders: Set<UUID>
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Move Selected Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Selection summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Moving \(selectedNotes.count + selectedFolders.count) items:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if selectedNotes.count > 0 {
                    Text("• \(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if selectedFolders.count > 0 {
                    Text("• \(selectedFolders.count) folder\(selectedFolders.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )

            // Destination list
            List {
                // Home (no folder)
                HStack {
                    Image(systemName: "house")
                    Text("Home")
                    Spacer()
                    if selectedDestinationFolderID == nil { 
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDestinationFolderID = nil
                }

                // Top-level folders only (no parent)
                ForEach(folders.filter { $0.parentID == nil }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.name)
                        Spacer()
                        if selectedDestinationFolderID == folder.id { 
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDestinationFolderID = folder.id
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Button("Cancel") { 
                    onCancel() 
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Move") { 
                    onConfirm() 
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .background(
            colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
        )
    }
}
