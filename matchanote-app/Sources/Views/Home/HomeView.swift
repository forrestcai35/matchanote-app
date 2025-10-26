
import SwiftUI
import Combine
import PencilKit

struct HomeView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var documentHandler: DocumentHandler
    @StateObject private var authManager = LocalAuthManager.shared
    @State var searchText = ""
    @State var selectedNote: Note? = nil
    @State var selectedItem = "documents"
    @State var sortOption = "Date"
    @State var isGridView = true
    @State var showingSettings = false
    @State var currentFolderID: UUID? = nil
    @State var folderPath: [Folder] = []
    @State var dragItem: (type: DragItemType, id: UUID)? = nil
    @State var refreshID = UUID()
    @ObservedObject var tabManager = TabManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State var screenSize: CGSize = .zero
    @State var showNewWrittenNoteView = false
    @State var showNewFolderView = false
    @State var showingFileImporter = false
    @State var showMoveSheet = false
    @State var notePendingMove: Note? = nil
    @State var selectedDestinationFolderID: UUID? = nil


    // Subject state
    @State var selectedSubject: String? = nil
    @State var editingSubjectID: UUID? = nil
    @State var editingSubjectName: String = ""
    @State var isNewSubject: Bool = false
    @State var showDuplicateSubjectAlert: Bool = false
    @FocusState var subjectNameFieldFocused: Bool

    // Selection state
    @State var isSelectionMode = false
    @State var selectedNotes: Set<UUID> = []
    @State var selectedFolders: Set<UUID> = []
    @State var showBulkMoveSheet = false
    
    // Session validation state
    @State var hasValidatedSession = false

    // Progress feedback for bulk operations
    @State var isDeleting = false
    @State var deletionProgress: Double = 0.0
    @State var deletionStatus = ""

    // Sidebar state for mobile/split view
    @State var isSidebarVisible = true

    enum DragItemType {
        case folder
        case note
    }
    let sidebarItems = [
        SidebarItem(id: "documents", title: "Documents", icon: "folder"),
        SidebarItem(id: "recents", title: "Recents", icon: "clock.arrow.circlepath"),
        SidebarItem(id: "favorites", title: "Favorites", icon: "star"),
    ]
    
    // Screen size detection
    var isCompactWidth: Bool {
        return screenSize.width < 600 // Compact when width is less than 600
    }
    
    var isSmallScreen: Bool {
        return screenSize.width < 800 // Small screen when width is less than 800
    }
    
    // Dynamic sidebar width based on screen size
    var sidebarWidth: CGFloat {
        if isCompactWidth {
            return min(screenSize.width * 0.75, 280) // 75% of screen or max 280 on compact
        } else if isSmallScreen {
            return 260
        } else {
            return screenSize.width > screenSize.height ? 350 : 300
        }
    }
    
    // Should sidebar overlay content on small screens
    var shouldOverlaySidebar: Bool {
        return isCompactWidth || isSmallScreen
    }
    
    // Dynamic grid spacing based on screen size
    var gridSpacing: CGFloat {
        return isCompactWidth ? 12 : 20
    }
    
    // Dynamic grid item spacing based on screen size
    var gridItemSpacing: CGFloat {
        return isCompactWidth ? 12 : 20
    }
    
    // Dynamic minimum grid item size based on screen size
    var gridItemMinSize: CGFloat {
        if isCompactWidth {
            return 140 // Smaller on compact screens
        } else if isSmallScreen {
            return 150
        } else {
            return 160
        }
    }
    // Filtered notes based on search text and current folder
    var filteredNotes: [Note] {
        // Optimize: Create set once for O(1) lookup instead of O(n*m) for each note
        let allFolderNoteIDs: Set<UUID> = currentFolderID == nil 
            ? Set(storageManager.folders.flatMap { $0.noteIDs })
            : []
        
        let folderNotes = storageManager.notes.filter { note in
            if let currentFolderID = currentFolderID {
                // Get the folder to check its noteIDs
                if let folder = storageManager.folders.first(where: { $0.id == currentFolderID }) {
                    return folder.noteIDs.contains(note.id)
                }
                return false
            } else {
                // Root level - show notes that don't belong to any folder
                return !allFolderNoteIDs.contains(note.id)
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
        // Authentication check - redirect to sign in if not authenticated
        if !authManager.isLoggedIn {
            SignInView()
                .environmentObject(authManager)
        } else {
            GeometryReader { geometry in
                if isCompactWidth {
                    // Bottom tab view for compact screens
                    ZStack {
                        VStack(spacing: 0) {
                            contentViewWithHeader
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            bottomTabBar
                        }
                    }
                    .onAppear {
                        screenSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        screenSize = newSize
                    }
                } else if shouldOverlaySidebar {
                    // Overlay sidebar for medium screens
                    ZStack(alignment: .leading) {
                        // Main content area - full width
                        contentViewWithHeader
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Overlay dimming when sidebar is open
                        if isSidebarVisible {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation {
                                        isSidebarVisible = false
                                    }
                                }
                                .zIndex(1)
                        }
                        
                        // Sidebar - overlays on medium screens
                        if isSidebarVisible {
                            sidebarView
                                .frame(width: sidebarWidth)
                                .frame(maxHeight: .infinity)
                                .background(
                                    (colorScheme == .dark
                                        ? Color.matchabackground_dark
                                        : Color.matchabackground_light)
                                        .brightness(colorScheme == .dark ? -0.05 : 0.05)
                                        .ignoresSafeArea(.container, edges: .top)
                                )
                                .offset(x: isSidebarVisible ? 0 : -sidebarWidth)
                                .animation(.easeInOut(duration: 0.25), value: isSidebarVisible)
                                .shadow(color: Color.black.opacity(0.2), radius: 8)
                                .zIndex(2)
                        }
                    }
                    .onAppear {
                        screenSize = geometry.size
                        isSidebarVisible = false
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        screenSize = newSize
                        // Auto-hide sidebar when transitioning to overlay mode
                        if shouldOverlaySidebar && isSidebarVisible {
                            isSidebarVisible = false
                        }
                    }
                } else {
                    // Inline sidebar for large screens - use HStack
                    HStack(spacing: 0) {
                        sidebarView
                            .frame(width: sidebarWidth)
                            .frame(maxHeight: .infinity)
                            .background(
                                (colorScheme == .dark
                                    ? Color.matchabackground_dark
                                    : Color.matchabackground_light)
                                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
                                    .ignoresSafeArea(.container, edges: .top)
                            )

                        contentViewWithHeader
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onAppear {
                        screenSize = geometry.size
                        isSidebarVisible = true
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        screenSize = newSize
                        // Auto-show sidebar on large screens
                        if !shouldOverlaySidebar {
                            isSidebarVisible = true
                        }
                    }
                }
            }
            .task {
                // Only validate session once per app session, not on every navigation
                // This was causing major slowdown by making network calls every time HomeView appeared
                guard !hasValidatedSession else { return }
                hasValidatedSession = true
                
                Task.detached(priority: .background) {
                    await authManager.validateSession()
                }
            }
            .onAppear {
                // Preload previews for better performance
                // This prevents the loading spinners by generating previews in advance
                preloadVisiblePreviews()
            }
            .onChange(of: selectedItem) { _, _ in
                // Preload previews when switching between Documents/Recents/Favorites
                preloadVisiblePreviews()
            }
            .onChange(of: currentFolderID) { _, _ in
                // Preload previews when navigating folders
                preloadVisiblePreviews()
            }
            .onChange(of: selectedSubject) { _, _ in
                // Preload previews when switching subjects
                preloadVisiblePreviews()
            }
            .onChange(of: isGridView) { _, _ in
                // Preload previews when toggling grid/list view
                // (different preview sizes are needed)
                preloadVisiblePreviews()
            }
            .accentColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        HomeSidebarView(
            searchText: $searchText,
            selectedItem: $selectedItem,
            selectedSubject: $selectedSubject,
            showingSettings: $showingSettings,
            currentFolderID: $currentFolderID,
            folderPath: $folderPath,
            isSidebarVisible: $isSidebarVisible,
            editingSubjectID: $editingSubjectID,
            editingSubjectName: $editingSubjectName,
            isNewSubject: $isNewSubject,
            showDuplicateSubjectAlert: $showDuplicateSubjectAlert,
            subjectNameFieldFocused: $subjectNameFieldFocused,
            isCompactWidth: isCompactWidth,
            shouldOverlaySidebar: shouldOverlaySidebar,
            sidebarItems: sidebarItems
        )
    }
    
    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(sidebarItems) { item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedItem = item.id
                        if item.id == "documents" {
                            currentFolderID = nil
                            folderPath = []
                        }
                    }
                }) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(
                            selectedItem == item.id
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : Color.secondary
                        )
                        .frame(width: 50, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    selectedItem == item.id
                                        ? (colorScheme == .dark 
                                            ? Color.matchalight_dark.opacity(0.15) 
                                            : Color.matchalight_light.opacity(0.15))
                                        : Color.clear
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedItem == item.id
                                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.03 : 0.03)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    // MARK: - Content View with Header
    private var contentViewWithHeader: some View {
        VStack(spacing: 0) {
            // Header with title and controls
            HStack(spacing: isCompactWidth ? 8 : 12) {
                // Hamburger menu button for small screens (not compact, only for overlay sidebar)
                if shouldOverlaySidebar && !isCompactWidth {
                    Button(action: {
                        withAnimation {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                            )
                            .padding(8)
                    }
                }
                
                // Settings button for compact screens (replaces hamburger)
                if isCompactWidth {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(
                                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                            )
                            .padding(8)
                    }
                }
                
                Text(currentViewTitle)
                    .font(.system(isCompactWidth ? .title2 : .largeTitle, design: .serif))
                    .bold()
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer()

                // Header controls
                HStack(spacing: isCompactWidth ? 6 : 12) {
                    if isSelectionMode && (selectedNotes.count > 0 || selectedFolders.count > 0) {
                        bulkActionButtons
                    }
                    viewToggleButton
                    if !isSelectionMode {
                        headerNewButton
                    }
                }
            }
            .padding(.horizontal, isCompactWidth ? 12 : 16)
            .padding(.vertical, isCompactWidth ? 8 : 12)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)

            // Main content
            if selectedSubject != nil {
                subjectView
            } else if selectedItem == "documents" {
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
        if let subject = selectedSubject {
            return subject
        }

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
        FolderNavigationView(
            currentFolderID: $currentFolderID,
            folderPath: $folderPath,
            onDropToFolder: { folder in
                return handleDrop(onto: folder)
            },
            onDropToRoot: {
                return handleDrop(onto: nil)
            }
        )
    }
   
    private var viewToggleButton: some View {
        HStack(spacing: isCompactWidth ? 4 : 8) {
            // Grid/List toggle
            Button(action: { isGridView.toggle() }) {
                Label(
                    isGridView ? "Grid View" : "List View",
                    systemImage: isGridView ? "square.grid.2x2" : "list.bullet"
                )
                .fontWeight(.medium)
                .font(.system(size: isCompactWidth ? 14 : 16))
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .labelStyle(.iconOnly)
                .padding(isCompactWidth ? 6 : 8)
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
                    .font(.system(size: isCompactWidth ? 14 : 16))
                    .foregroundColor(
                        isSelectionMode 
                            ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                            : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    )
                    .padding(isCompactWidth ? 6 : 8)
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
            columns: [GridItem(.adaptive(minimum: gridItemMinSize), spacing: gridItemSpacing)],
            spacing: gridSpacing
        ) {
            // Break grid content into separate views
            foldersGridContent
            notesGridContent
        }
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.top, isCompactWidth ? 12 : 16)
        .padding(.bottom, isCompactWidth ? 12 : 16)
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

    // resetDragState moved to HomeView+DragDrop.swift

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
        .scaleEffect(1.0)
        .animation(.none, value: isSelectionMode)
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
        .scaleEffect(1.0)
        .animation(.none, value: isSelectionMode)
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
        VStack(spacing: isCompactWidth ? 8 : 12) {
            listContent
        }
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.vertical, isCompactWidth ? 12 : 16)
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

    // Drag-and-drop and navigation functions moved to extensions:
    // - HomeView+DragDrop.swift
    // - HomeView+Navigation.swift

    private func folderContextMenu(_ folder: Folder) -> some View {
        Group {
            // Subject tagging menu
            Menu {
                if !folder.subject.isEmpty {
                    Button(action: {
                        var updatedFolder = folder
                        updatedFolder.subject = ""
                        _ = storageManager.saveFolder(updatedFolder)
                    }) {
                        Label("Clear Subject", systemImage: "xmark.circle")
                    }

                    Divider()
                }

                ForEach(storageManager.subjects.filter { !$0.name.isEmpty }.sorted(by: { $0.name < $1.name })) { subject in
                    Button(action: {
                        var updatedFolder = folder
                        updatedFolder.subject = subject.name
                        _ = storageManager.saveFolder(updatedFolder)
                    }) {
                        HStack {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 12, height: 12)
                            Text(subject.name)
                            if folder.subject == subject.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                if !folder.subject.isEmpty {
                    Label("Subject: \(folder.subject)", systemImage: "tag.fill")
                } else {
                    Label("Add Subject", systemImage: "tag")
                }
            }

            Button(action: {
                // Toggle favorite
                var updatedFolder = folder
                updatedFolder.toggleFavorite()
                _ = storageManager.saveFolder(updatedFolder)
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

            // Subject tagging menu
            Menu {
                if !note.subject.isEmpty {
                    Button(action: {
                        var updatedNote = note
                        updatedNote.subject = ""
                        let savedNote = storageManager.saveNote(updatedNote)
                        TabManager.shared.updateNote(savedNote)
                    }) {
                        Label("Clear Subject", systemImage: "xmark.circle")
                    }

                    Divider()
                }

                ForEach(storageManager.subjects.filter { !$0.name.isEmpty }.sorted(by: { $0.name < $1.name })) { subject in
                    Button(action: {
                        var updatedNote = note
                        updatedNote.subject = subject.name
                        let savedNote = storageManager.saveNote(updatedNote)
                        TabManager.shared.updateNote(savedNote)
                    }) {
                        HStack {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 12, height: 12)
                            Text(subject.name)
                            if note.subject == subject.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                if !note.subject.isEmpty {
                    Label("Subject: \(note.subject)", systemImage: "tag.fill")
                } else {
                    Label("Add Subject", systemImage: "tag")
                }
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
                
                // Exit selection mode
                isSelectionMode = false
                
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
        
        // Exit selection mode
        isSelectionMode = false
        
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

    func handleImportedFiles(_ urls: [URL]) {
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

        // Check if it's a PDF, image, or matcha file
        if fileExtension == "pdf" {
            createNoteFromPDF(url: url, fileName: fileName)
        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"].contains(fileExtension) {
            createNoteFromImage(url: url, fileName: fileName)
        } else if fileExtension == "matcha" {
            createNoteFromMatchaFile(url: url, fileName: fileName)
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
            subject: selectedSubject ?? "",
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
            subject: selectedSubject ?? "",
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
            
            // Decode the note from JSON with proper date decoding strategy
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedNote = try decoder.decode(Note.self, from: matchaData)
            
            // Create a new note with the imported data but with a new ID and current timestamp
            // Use the imported subject if it exists, otherwise use the current subject context
            let noteSubject = importedNote.subject.isEmpty ? (selectedSubject ?? "") : importedNote.subject
            
            let newNote = Note(
                title: importedNote.title,
                subject: noteSubject,
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
            print("Success: Imported Matcha note '\(newNote.title)' from \(url.lastPathComponent)")
        } catch {
            print("Error: Could not load Matcha note from \(url): \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }

    private func createTextNoteFromFile(url: URL, fileName: String) {
        let newNote = Note(
            title: fileName,
            subject: selectedSubject ?? "",
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
            columns: [GridItem(.adaptive(minimum: gridItemMinSize), spacing: gridItemSpacing)],
            spacing: gridSpacing
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
                .scaleEffect(1.0)
                .animation(.none, value: isSelectionMode)
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.top, isCompactWidth ? 12 : 16)
        .padding(.bottom, isCompactWidth ? 12 : 16)
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.vertical, isCompactWidth ? 12 : 16)
        .id(refreshID)
    }

    private var favoritesGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: gridItemMinSize), spacing: gridItemSpacing)],
            spacing: gridSpacing
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
                .scaleEffect(1.0)
                .animation(.none, value: isSelectionMode)
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
                .scaleEffect(1.0)
                .animation(.none, value: isSelectionMode)
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.top, isCompactWidth ? 12 : 16)
        .padding(.bottom, isCompactWidth ? 12 : 16)
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.vertical, isCompactWidth ? 12 : 16)
        .id(refreshID)
    }

    // MARK: - Subject view
    private var subjectView: some View {
        VStack(alignment: .leading, spacing: 0) {
            subjectContent
        }
        .fullScreenCover(item: $selectedNote) { note in
            NoteView(note: note)
        }
    }

    private var subjectContent: some View {
        ScrollView {
            if filteredSubjectNotes.isEmpty && filteredSubjectFolders.isEmpty {
                EmptySubjectView(
                    showNewWrittenNoteView: $showNewWrittenNoteView,
                    subject: selectedSubject
                )
            } else if isGridView {
                subjectGridView
            } else {
                subjectListView
            }
        }
    }

    var filteredSubjectNotes: [Note] {
        guard let subject = selectedSubject else { return [] }
        let subjectNotes = storageManager.notes.filter { $0.subject == subject }
        if searchText.isEmpty {
            return subjectNotes
        } else {
            return subjectNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var filteredSubjectFolders: [Folder] {
        guard let subject = selectedSubject else { return [] }
        let subjectFolders = storageManager.folders.filter { $0.subject == subject }
        if searchText.isEmpty {
            return subjectFolders
        } else {
            return subjectFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var subjectGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: gridItemMinSize), spacing: gridItemSpacing)],
            spacing: gridSpacing
        ) {
            // Show folders first
            ForEach(filteredSubjectFolders) { folder in
                let isSelected = selectedFolders.contains(folder.id)
                Button(action: {
                    if isSelectionMode {
                        toggleFolderSelection(folder.id)
                    } else {
                        // Navigate to folder from subject
                        navigateToFolderFromSubject(folder)
                    }
                }) {
                    GridFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.none, value: isSelectionMode)
                .contextMenu {
                    folderContextMenu(folder)
                }
                .onDrag {
                    startDragging(folder: folder)
                } preview: {
                    dragPreview(for: folder)
                }
            }

            // Then show notes
            ForEach(filteredSubjectNotes) { note in
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
                .scaleEffect(1.0)
                .animation(.none, value: isSelectionMode)
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.top, isCompactWidth ? 12 : 16)
        .padding(.bottom, isCompactWidth ? 12 : 16)
        .id(refreshID)
    }

    private var subjectListView: some View {
        LazyVStack(spacing: 8) {
            // Show folders first
            ForEach(filteredSubjectFolders) { folder in
                let isSelected = selectedFolders.contains(folder.id)
                Button(action: {
                    if isSelectionMode {
                        toggleFolderSelection(folder.id)
                    } else {
                        // Navigate to folder from subject
                        navigateToFolderFromSubject(folder)
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

            // Then show notes
            ForEach(filteredSubjectNotes) { note in
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
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.vertical, isCompactWidth ? 12 : 16)
        .id(refreshID)
    }

    // Helper function to navigate to a folder from subject
    // navigateToFolderFromSubject moved to HomeView+Navigation.swift
    
    // MARK: - Preview Preloading
    
    /// Preload previews for visible notes to avoid loading spinners
    private func preloadVisiblePreviews() {
        // Determine which notes to preload based on current view
        let notesToPreload: [Note]
        if selectedSubject != nil {
            notesToPreload = Array(filteredSubjectNotes.prefix(20))
        } else if selectedItem == "recents" {
            notesToPreload = Array(recentNotes.prefix(20))
        } else if selectedItem == "favorites" {
            notesToPreload = Array(filteredFavoriteNotes.prefix(20))
        } else {
            notesToPreload = Array(filteredNotes.prefix(20))
        }
        
        // Skip if no notes to preload
        guard !notesToPreload.isEmpty else { return }
        
        // Preload in background with appropriate size for current view
        let previewSize: PreviewGenerator.PreviewSize = isGridView ? .grid : .list
        PreviewCache.shared.preloadPreviews(for: notesToPreload, size: previewSize)
    }
}

