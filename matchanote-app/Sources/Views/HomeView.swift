//
//  HomeView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI
import matchanote_app

struct SidebarItem: Identifiable {
    var id: String
    var title: String
    var icon: String
}

struct HomeView: View {
    @State private var notes = Note.samples
    @State private var folders = Folder.samples
    @State private var searchText = ""
    @State private var selectedNote: Note? = nil
    @State private var selectedItem = "documents"
    @State private var sortOption = "Date"
    @State private var isGridView = true
    @State private var showSettings = false
    @State private var currentFolderID: UUID? = nil
    @State private var folderPath: [Folder] = []
    @State private var dragItem: (type: DragItemType, id: UUID)? = nil
    @State private var refreshID = UUID()
    @ObservedObject private var tabManager = TabManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private enum DragItemType {
        case folder
        case note
    }
    let sidebarItems = [
        SidebarItem(id: "documents", title: "Documents", icon: "folder"),
        SidebarItem(id: "favorites", title: "Favorites", icon: "star")
        
    ]
    // Filtered notes based on search text and current folder
    var filteredNotes: [Note] {
        let folderNotes = notes.filter { note in
            if let currentFolderID = currentFolderID {
                // Get the folder to check its noteIDs
                if let folder = folders.first(where: { $0.id == currentFolderID }) {
                    return folder.noteIDs.contains(note.id)
                }
                return false
            } else {
                // Root level - show notes that don't belong to any folder
                return !folders.flatMap { $0.noteIDs }.contains(note.id)
            }
        }
        if searchText.isEmpty {
            return folderNotes
        } else {
            return folderNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    // Filtered folders based on search text and current folder
    var filteredFolders: [Folder] {
        let folderItems = folders.filter { folder in
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
var body: some View {
    NavigationSplitView {
        // Sidebar
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)  

                Text("Matcha")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            }
            searchBar
            sidebarList
        }
        .background(
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light,
                        colorScheme == .dark ? Color.black : Color.white,
                    ]
                ),
                startPoint: .bottom,
                endPoint: .top
            )
        )
    } detail: {
        contentView
    }
    .accentColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
}

    // MARK: - Component Views
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var sidebarList: some View {
        List {
            ForEach(sidebarItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .fontWeight(.medium)
                        .foregroundStyle(
                            colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
                    Text(item.title)
                        .foregroundStyle(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    Spacer()
                }
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItem = item.id
                    if item.id == "documents" {
                        currentFolderID = nil
                        folderPath = []
                    }
                }
                .listRowBackground(
                    (selectedItem == item.id
                        ? (colorScheme == .dark
                            ? Color.matchalight_dark.opacity(0.2)
                            : Color.matchalight_light.opacity(0.2)) : Color.clear)
                        .cornerRadius(8)
                        .padding(.horizontal, 0)
                        .padding(.vertical, 8)
                )
            }

        }
        .scrollDisabled(true)
        .padding(.top, 10)
        .listStyle(SidebarListStyle())
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var contentView: some View {
        if selectedItem == "documents" {
            documentsView
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                                .fontWeight(.medium)
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.matchabrown_dark : Color.matchabrown_light)
                        }
                        .popover(isPresented: $showSettings, arrowEdge: .top) {
                            SettingsPopover()
                        }
                    }
                }

        }

    }

    // MARK: - Document view
    private var documentsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            documentHeader
            folderPathBreadcrumbs
            documentContent
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
    private var documentHeader: some View {
        HStack {
            Text(currentFolderID == nil ? "Documents" : folderPath.last?.name ?? "Documents")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.matchabrown_dark : Color.matchabrown_light)
            Spacer()
            sortMenu
            viewToggleButton
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private var sortMenu: some View {
        Menu {
            Button("Date", action: { sortOption = "Date" })
                .fontWeight(.medium)
            Button("Name", action: { sortOption = "Name" })
                .fontWeight(.medium)
            Button("Type", action: { sortOption = "Type" })
                .fontWeight(.medium)

    
        } label: {
            Label {
                Text(sortOption)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .foregroundColor(
                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            .fontWeight(.medium)
        }
    }
    private var viewToggleButton: some View {
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
    }
    private var documentContent: some View {
        ScrollView {
            if isGridView {
                gridView
            } else {
                listView
            }
        }
    }
    private var gridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            spacing: 12
        ) {
            createItemButton(inGrid: true)

            // Break grid content into separate views
            foldersGridContent
            notesGridContent
        }
        .padding(.horizontal)
        .padding(.top, 8)
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
        switch type {
        case .written:
            return "pencil"
        case .text:
            return "text.page"
        }
    }

    // MARK: - Drag and Drop Handling
    // Generic drag preview function that works for both folders and notes
    private func dragPreview(for item: Any) -> some View {
        let width: CGFloat = 120
        let height: CGFloat = 150
            
        if item is Folder {
            return AnyView(
                ZStack {
                    Image("folder")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 175, height: 140)
                        .clipped()

                }
            )
        } else if let note = item as? Note {
            return AnyView(
                ZStack {
                    if note.noteType == .written {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(note.color)
                            .frame(width: width, height: height)
                            .shadow(
                                color: itemShadow(in: colorScheme),
                                radius: 5,
                                x: 0,
                                y: 2
                            )

                        Image(systemName: "pencil.tip")
                            .font(.system(size: 30))
                            .foregroundColor(Color.white.opacity(0.3))
                    } else if note.noteType == .text {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(note.color)
                            .frame(width: width, height: height)
                            .shadow(
                                color: itemShadow(in: colorScheme),
                                radius: 6,
                                x: 0,
                                y: 2
                            )
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 30))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // Helper function to create a folder grid item
    private func folderGridItem(for folder: Folder) -> some View {
        applyCommonItemModifiers(
            view: GridFolderItemView(folder: folder),
            for: folder,
            onTap: {
                navigateToFolder(folder)
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
        let baseView = NavigationLink(
            destination: NoteView(note: note)
                .navigationBarBackButtonHidden(true)

        ) {
            GridItemView(note: note)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            TapGesture().onEnded {
                TabManager.shared.openTab(note: note)
            }
        )
        return

            baseView
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
            createItemButton(inGrid: false)
            listContent
        }
        .padding(.vertical)
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
        applyCommonItemModifiers(
            view: ListFolderItemView(folder: folder),
            for: folder,
            onTap: {
                navigateToFolder(folder)
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
        // NavigationLink needs special handling since we can't directly apply modifiers to it
        let baseView = NavigationLink(
            destination: NoteView(note: note)
                .navigationBarBackButtonHidden(true)
        ) {
            ListItemView(note: note)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            TapGesture().onEnded {
                TabManager.shared.openTab(note: note)
            }
        )

        return
            baseView
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

        // Create a new copy of the folders array
        var newFolders = folders
        switch draggedItemType.type {
        case .folder:
            // Move folder to root level
            if let index = newFolders.firstIndex(where: { $0.id == draggedItemType.id }) {
                newFolders[index].parentID = nil

                // Replace the entire folders array
                DispatchQueue.main.async {
                    self.folders = newFolders

                }

                return true
            }
        case .note:
            // Remove note from all folders
            var madeChanges = false
            for i in 0..<newFolders.count {
                if newFolders[i].noteIDs.contains(draggedItemType.id) {
                    newFolders[i].noteIDs.removeAll(where: { $0 == draggedItemType.id })
                    newFolders[i].dateModified = Date()
                    madeChanges = true
                    print("Removed note \(draggedItemType.id) from folder \(newFolders[i].id)")
                }
            }

            if madeChanges {
                // Replace the entire folders array
                DispatchQueue.main.async {
                    self.folders = newFolders

                }
            }

            return true
        }

        return false
    }

    // Handle drop onto a specific folder
    private func handleDrop(onto targetFolder: Folder? = nil) -> Bool {
        guard let (type, id) = dragItem else { return false }
        // Create a working copy of folders
        var newFolders = folders

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
                if let index = newFolders.firstIndex(where: { $0.id == id }),
                    let targetIndex = newFolders.firstIndex(where: { $0.id == targetFolder.id })
                {
                    newFolders[index].parentID = targetFolder.id
                    newFolders[targetIndex].dateModified = Date()
                }
            } else {
                // Move to root
                if let index = newFolders.firstIndex(where: { $0.id == id }) {
                    newFolders[index].parentID = nil
                }
            }

        case .note:
            // Remove note from all folders first
            for i in 0..<newFolders.count {
                if newFolders[i].noteIDs.contains(id) {
                    newFolders[i].noteIDs.removeAll(where: { $0 == id })
                    newFolders[i].dateModified = Date()
                }
            }

            // Add to target folder if provided
            if let targetFolder = targetFolder,
                let targetIndex = newFolders.firstIndex(where: { $0.id == targetFolder.id })
            {
                newFolders[targetIndex].noteIDs.append(id)
                newFolders[targetIndex].dateModified = Date()
            }
        }

        // Update folders and refresh UI
        DispatchQueue.main.async {
            self.folders = newFolders
            self.refreshID = UUID()
            self.dragItem = nil
        }

        return true
    }

    // Check if moving a folder would create a circular reference
    private func wouldCreateCircularReference(sourceID: UUID, targetID: UUID) -> Bool {
        // If source and target are the same, it would create a circular reference
        if sourceID == targetID {
            return true
        }

        // Check if target is a child of source (which would create a loop)
        var currentID = targetID
        while let folder = folders.first(where: { $0.id == currentID }) {
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

    // Context menu for folders
    private func folderContextMenu(_ folder: Folder) -> some View {
        Group {
            Button(action: {
                // Rename folder functionality would go here
            }) {
                Label("Rename", systemImage: "pencil")
            }

            Button(action: {
                // Change color functionality would go here
            }) {
                Label("Change Color", systemImage: "paintpalette")
            }

            Button(action: {
                // Toggle favorite
                if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                    folders[index].isFavorite.toggle()

                }
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
                    // Delete folder functionality would go here
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
                // Move note functionality
                // This would open a move to folder dialog
            }) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: {
                // Move note functionality
                // This would open a move to folder dialog
            }) {
                Label("Move to Folder", systemImage: "folder")
            }

            Button(action: {
                // Toggle favorite
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index].isFavorite.toggle()

                }
            }) {
                Label(
                    note.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: note.isFavorite ? "star.slash" : "star"
                )
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    // Delete note functionality would go here
                }
            ) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func createItemButton(inGrid: Bool) -> some View {
        Menu {
            // Note creation options
            Button {
                let newNote = Note(
                    title: "New Note",
                    color: .matchalight_dark,
                    dateCreated: Date(),
                    dateModified: Date(),
                    noteType: .written
                )
                // Add to current folder if we're in one
                if let currentFolderID = currentFolderID,
                    let index = folders.firstIndex(where: { $0.id == currentFolderID })
                {
                    folders[index].addNote(noteID: newNote.id)
                }
                notes.append(newNote)
                TabManager.shared.openTab(note: newNote)
            } label: {
                Label("Note", systemImage: "pencil")
            }

            // Folder creation option
            Button {
                let newFolder = Folder(
                    name: "New Folder",
                    color: .blue,
                    parentID: currentFolderID,
                    dateCreated: Date()
                )
                folders.append(newFolder)
            } label: {
                Label("Folder", systemImage: "folder")
            }

            Button {
                let newNote = Note(
                    title: "New Text Note",
                    color: .matchalight_light,
                    dateCreated: Date(),
                    dateModified: Date(),
                    noteType: .text
                )
                // Add to current folder if we're in one
                if let currentFolderID = currentFolderID,
                    let index = folders.firstIndex(where: { $0.id == currentFolderID })
                {
                    folders[index].addNote(noteID: newNote.id)
                }
                notes.append(newNote)
                TabManager.shared.openTab(note: newNote)
            } label: {
                Label("Text", systemImage: "text.alignleft")
            }

            Button {
                print("Upload action triggered")
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
    }

    private var listNewButton: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .font(.title2)

            Text("New...")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.03))
                )
        )
        .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }

    private var gridNewButton: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        style: StrokeStyle(lineWidth: 2, dash: [5])
                    )
                    .frame(width: 160, height: 200)
                Image(systemName: "plus")
                    .font(.largeTitle)
            }
            .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)


            Text("New...")
                .padding(.top, 5)
                .foregroundColor(
                    colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light
                )
                .frame(width: 160)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .font(.subheadline)

     
            Text(" ")
                .padding(.bottom, 5)
                .font(.caption)
                .frame(width: 160)
        }
        .frame(width: 160)
    }

    // Helper to find the UISplitViewController in the view controller hierarchy
    private func findSplitViewController(in viewController: UIViewController)
        -> UISplitViewController?
    {
        if let splitViewController = viewController as? UISplitViewController {
            return splitViewController
        }

        for child in viewController.children {
            if let splitViewController = findSplitViewController(in: child) {
                return splitViewController
            }
        }

        return nil
    }

}


#Preview {
    HomeView()
        .environmentObject(AIAssistantState())
}
