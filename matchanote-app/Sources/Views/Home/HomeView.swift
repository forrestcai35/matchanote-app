
import SwiftUI
import Combine
import PencilKit

struct HomeView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var documentHandler: DocumentHandler
    @StateObject private var authManager = LocalAuthManager.shared
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @ObservedObject private var statusManager = AppStatusManager.shared
    @State var searchText = ""
    @State var selectedNote: Note? = nil
    @State var selectedItem = "documents"
    @State var showingSettings = false
    @State var currentFolderID: UUID? = nil
    @State var folderPath: [Folder] = []
    @State var dragItem: (type: DragItemType, id: UUID)? = nil
    @State var dropTargetFolderID: UUID? = nil
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
    @State var showBulkTagMenu = false
    
    // Session validation state
    @State var hasValidatedSession = false

    // Progress feedback for bulk operations
    @State var isDeleting = false
    @State var deletionProgress: Double = 0.0
    @State var deletionStatus = ""

    // Sidebar state for mobile/split view
    @State var isSidebarVisible = true

    // Maintenance mode dismissal state
    @State var isMaintenanceDismissed = false

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
        return isCompactWidth ? 12 : 24
    }

    // Dynamic grid item spacing based on screen size
    var gridItemSpacing: CGFloat {
        return isCompactWidth ? 12 : 24
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

        let searchFiltered: [Note]
        if searchText.isEmpty {
            searchFiltered = folderNotes
        } else {
            searchFiltered = folderNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        if preferencesManager.homeViewSortOption == "Name" {
            return searchFiltered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            // Sort by date (most recent first)
            return searchFiltered.sorted { $0.dateModified > $1.dateModified }
        }
    }
    // Filtered Folders
    var filteredFolders: [Folder] {
        let folderItems = storageManager.folders.filter { folder in
            if let currentFolderID = currentFolderID {
                return folder.parentID == currentFolderID
            } else {
                return folder.parentID == nil
            }
        }

        let searchFiltered: [Folder]
        if searchText.isEmpty {
            searchFiltered = folderItems
        } else {
            searchFiltered = folderItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        if preferencesManager.homeViewSortOption == "Name" {
            return searchFiltered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            // Sort by date (most recent first)
            return searchFiltered.sorted { $0.dateModified > $1.dateModified }
        }
    }

    var filteredFavoriteNotes: [Note] {
        let favoriteNotes = storageManager.notes.filter { $0.isFavorite }

        let searchFiltered: [Note]
        if searchText.isEmpty {
            searchFiltered = favoriteNotes
        } else {
            searchFiltered = favoriteNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        if preferencesManager.homeViewSortOption == "Name" {
            return searchFiltered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            // Sort by date (most recent first)
            return searchFiltered.sorted { $0.dateModified > $1.dateModified }
        }
    }

    var filteredFavoriteFolders: [Folder] {
        let favoriteFolders = storageManager.folders.filter { $0.isFavorite }

        let searchFiltered: [Folder]
        if searchText.isEmpty {
            searchFiltered = favoriteFolders
        } else {
            searchFiltered = favoriteFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sorting
        if preferencesManager.homeViewSortOption == "Name" {
            return searchFiltered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            // Sort by date (most recent first)
            return searchFiltered.sorted { $0.dateModified > $1.dateModified }
        }
    }

    // MARK: - Bulk Selection Analysis

    /// Analyzes the subjects of currently selected items
    var selectedItemsSubjectInfo: (hasSubjects: Bool, subjects: Set<String>, displayText: String) {
        var subjects: Set<String> = []

        // Collect subjects from selected notes
        for noteID in selectedNotes {
            if let note = storageManager.notes.first(where: { $0.id == noteID }),
               !note.subject.isEmpty {
                subjects.insert(note.subject)
            }
        }

        // Collect subjects from selected folders
        for folderID in selectedFolders {
            if let folder = storageManager.folders.first(where: { $0.id == folderID }),
               !folder.subject.isEmpty {
                subjects.insert(folder.subject)
            }
        }

        let hasSubjects = !subjects.isEmpty
        let displayText: String

        if subjects.isEmpty {
            displayText = "No subject"
        } else if subjects.count == 1 {
            displayText = subjects.first!
        } else {
            displayText = "Mixed (\(subjects.count))"
        }

        return (hasSubjects, subjects, displayText)
    }
    var body: some View {
        ZStack {
            // Authentication check - redirect to sign in if not authenticated
            if !authManager.isLoggedIn {
                SignInView()
                    .environmentObject(authManager)
            } else {
                mainContent
            }

            // Overlay for maintenance mode ONLY (blocks entire app unless dismissed)
            // WARNING: Use maintenance mode only for critical issues!
            if statusManager.currentMessageMode == .maintenance,
               let maintenance = statusManager.appStatus?.maintenance,
               !isMaintenanceDismissed {
                MaintenanceOverlay(maintenance: maintenance, isDismissed: $isMaintenanceDismissed)
            }
        }
    }

    private var mainContent: some View {
        geometryBasedLayout
            .modifier(LifecycleModifiers(
                hasValidatedSession: $hasValidatedSession,
                authManager: authManager,
                preloadAction: preloadVisiblePreviews
            ))
            .modifier(PreloadingModifiers(
                selectedItem: selectedItem,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject,
                homeViewIsGridView: preferencesManager.homeViewIsGridView,
                preloadAction: preloadVisiblePreviews
            ))
            .modifier(SheetModifiers(
                showingSettings: $showingSettings,
                pendingImport: $documentHandler.pendingImport,
                storageManager: storageManager,
                isSelectionMode: $isSelectionMode,
                selectedNotes: $selectedNotes,
                selectedFolders: $selectedFolders
            ))
            .modifier(ImportHandlingModifiers(
                pendingImport: documentHandler.pendingImport,
                importedNote: documentHandler.importedNote,
                selectedNote: $selectedNote,
                selectedItem: $selectedItem,
                selectedSubject: $selectedSubject,
                currentFolderID: $currentFolderID,
                storageManager: storageManager,
                documentHandler: documentHandler
            ))
            .onChange(of: currentFolderID) { _, newValue in
                documentHandler.currentFolderID = newValue
            }
            .onChange(of: selectedSubject) { _, newValue in
                documentHandler.selectedSubject = newValue
            }
            .accentColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
    }

    private var geometryBasedLayout: some View {
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
                                        .ignoresSafeArea(.container, edges: [.top, .bottom])
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
                                    .ignoresSafeArea(.container, edges: [.top, .bottom])
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
            // App status banner (web API + App Store updates)
            AppStatusBanner(statusManager: statusManager)

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
                    .font(.jost(isCompactWidth ? .title2() : .largeTitle()))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(0)

                Spacer()

                // Header controls
                HStack(spacing: isCompactWidth ? 6 : 12) {
                    if isSelectionMode && (selectedNotes.count > 0 || selectedFolders.count > 0) {
                        bulkActionButtons
                    }
                    if !isSelectionMode {
                        sortButton
                    }
                    viewToggleButton
                    if !isSelectionMode {
                        headerNewButton
                    }
                }
                .layoutPriority(1)
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
            Button(action: { preferencesManager.homeViewIsGridView.toggle() }) {
                Label(
                    preferencesManager.homeViewIsGridView ? "Grid View" : "List View",
                    systemImage: preferencesManager.homeViewIsGridView ? "square.grid.2x2" : "list.bullet"
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
            .help(preferencesManager.homeViewIsGridView ? "Switch to List View" : "Switch to Grid View")
            
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

    private var sortButton: some View {
        Button(action: {
            preferencesManager.homeViewSortOption = preferencesManager.homeViewSortOption == "Date" ? "Name" : "Date"
        }) {
            Image(systemName: preferencesManager.homeViewSortOption == "Date" ? "calendar" : "textformat.abc")
                .fontWeight(.medium)
                .font(.system(size: isCompactWidth ? 14 : 16))
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .padding(isCompactWidth ? 6 : 8)
                .cornerRadius(8)
        }
        .help("Sort by \(preferencesManager.homeViewSortOption == "Date" ? "Name" : "Date")")
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
    
    // Portrait: Adaptive layout that scales with screen width
    private var portraitBulkActionButtons: some View {
        // Determine if we should use compact or regular sizing based on width
        let useRegularSize = screenSize.width >= 500 // iPad in portrait
        let buttonSpacing: CGFloat = useRegularSize ? 8 : 6
        let iconSize: CGFloat = useRegularSize ? 16 : 14
        let iconPadding: CGFloat = useRegularSize ? 8 : 6
        let cornerRadius: CGFloat = useRegularSize ? 6 : 4

        return HStack(spacing: buttonSpacing) {
            // Selection count
            Text("\(selectedNotes.count + selectedFolders.count)")
                .font(.jost(useRegularSize ? .caption() : .caption2()))
                .foregroundColor(.secondary)
                .padding(.horizontal, useRegularSize ? 8 : 6)
                .padding(.vertical, useRegularSize ? 5 : 3)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.1))
                )

            // Tag button menu
            Menu {
                // Current subjects indicator (if any)
                if selectedItemsSubjectInfo.hasSubjects {
                    Section {
                        Label {
                            Text("Currently tagged:")
                                .font(.jost(.caption()))
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                        .disabled(true)

                        ForEach(Array(selectedItemsSubjectInfo.subjects).sorted(), id: \.self) { subjectName in
                            if let subject = storageManager.subjects.first(where: { $0.name == subjectName }) {
                                Label {
                                    Text(subjectName)
                                        .font(.jost(.caption()))
                                } icon: {
                                    Circle()
                                        .fill(subject.color)
                                        .frame(width: 12, height: 12)
                                }
                                .disabled(true)
                            }
                        }
                    }

                    Divider()

                    // Clear subjects option
                    Button(action: {
                        bulkTagSelectedItems(with: "")
                    }) {
                        Label("Clear Subject", systemImage: "xmark.circle")
                            .font(.jost(.body()))
                    }
                }

                // All available subjects
                Section {
                    ForEach(storageManager.subjects.filter { !$0.name.isEmpty }.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { subject in
                        Button(action: {
                            bulkTagSelectedItems(with: subject.name)
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(subject.color)
                                    .frame(width: 12, height: 12)

                                Text(subject.name)
                                    .font(.jost(.body()))

                                Spacer()

                                // Show checkmark if this is the only current subject
                                if selectedItemsSubjectInfo.subjects.count == 1 && selectedItemsSubjectInfo.subjects.contains(subject.name) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(
                                            colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                                        )
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "tag.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.orange.opacity(0.9)
                            : Color.orange.opacity(0.8)
                    )
                    .padding(iconPadding)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            .menuStyle(.borderlessButton)
            .disabled(isDeleting)

            // Move button
            Button(action: {
                showBulkMoveSheet = true
            }) {
                Image(systemName: "folder")
                    .font(.system(size: iconSize))
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.blue.opacity(0.9)
                            : Color.blue.opacity(0.8)
                    )
                    .padding(iconPadding)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDeleting)

            // Delete button
            Button(action: {
                deleteSelectedItems()
            }) {
                if isDeleting {
                    ProgressView()
                        .scaleEffect(useRegularSize ? 0.8 : 0.6)
                        .padding(iconPadding)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: iconSize))
                        .foregroundColor(.red)
                        .padding(iconPadding)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDeleting)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
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
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    )

                // Tag button with menu
                Menu {
                    // Current subjects indicator (if any)
                    if selectedItemsSubjectInfo.hasSubjects {
                        Section {
                            Label {
                                Text("Currently tagged:")
                                    .font(.jost(.caption()))
                            } icon: {
                                Image(systemName: "info.circle")
                            }
                            .disabled(true)

                            ForEach(Array(selectedItemsSubjectInfo.subjects).sorted(), id: \.self) { subjectName in
                                if let subject = storageManager.subjects.first(where: { $0.name == subjectName }) {
                                    Label {
                                        Text(subjectName)
                                            .font(.jost(.caption()))
                                    } icon: {
                                        Circle()
                                            .fill(subject.color)
                                            .frame(width: 12, height: 12)
                                    }
                                    .disabled(true)
                                }
                            }
                        }

                        Divider()

                        // Clear subjects option
                        Button(action: {
                            bulkTagSelectedItems(with: "")
                        }) {
                            Label("Clear Subject", systemImage: "xmark.circle")
                                .font(.jost(.body()))
                        }
                    }

                    // All available subjects
                    Section {
                        ForEach(storageManager.subjects.filter { !$0.name.isEmpty }.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { subject in
                            Button(action: {
                                bulkTagSelectedItems(with: subject.name)
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(subject.color)
                                        .frame(width: 12, height: 12)

                                    Text(subject.name)
                                        .font(.jost(.body()))

                                    Spacer()

                                    // Show checkmark if this is the only current subject
                                    if selectedItemsSubjectInfo.subjects.count == 1 && selectedItemsSubjectInfo.subjects.contains(subject.name) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(
                                                colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                                            )
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                        Text("Tag")
                    }
                    .font(.jost(.caption()))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 60)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .menuStyle(.borderlessButton)
                .disabled(isDeleting)

                // Move button
                Button(action: {
                    showBulkMoveSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Move")
                    }
                    .font(.jost(.caption()))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 60)
                    .fixedSize(horizontal: true, vertical: false)
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
                    .font(.jost(.caption()))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: isDeleting ? 80 : 60)
                    .fixedSize(horizontal: true, vertical: false)
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
                            .font(.jost(.caption2()))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(deletionProgress * 100))%")
                            .font(.jost(.caption2()))
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
        ZStack {
            ScrollView {
                if filteredNotes.isEmpty && filteredFolders.isEmpty {
                    EmptyDocumentsView(showNewWrittenNoteView: $showNewWrittenNoteView)
                } else if preferencesManager.homeViewIsGridView {
                    gridView
                } else {
                    listView
                }
            }

            // Top fade effect
            VStack {
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                Spacer()
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



    // Helper to apply common modifiers for items (both notes and folders)
    private func applyCommonItemModifiers<T: View, U: Identifiable>(
        view: T,
        for item: U,
        isTargeted: Binding<Bool>,
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
            .onDrop(of: ["public.text"], isTargeted: isTargeted) { _, _ in
                dropHandler()
            }
    }

    // Helper to add consistent shadow styling
    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }


    // MARK: - Drag and Drop Handling
    // Generic drag preview function that works for both folders and notes
    private func dragPreview(for item: Any, isGridView: Bool) -> some View {
        if let folder = item as? Folder {
            return AnyView(
                FolderDragPreview(folder: folder, isGridView: isGridView)
            )
        } else if let note = item as? Note {
            return AnyView(
                NoteDragPreview(note: note, isGridView: isGridView)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // Helper function to create a folder grid item
    private func folderGridItem(for folder: Folder) -> some View {
        let isSelected = selectedFolders.contains(folder.id)
        let isDropTarget = dropTargetFolderID == folder.id

        return applyCommonItemModifiers(
            view: GridFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode, isDropTarget: isDropTarget),
            for: folder,
            isTargeted: Binding(
                get: { dropTargetFolderID == folder.id },
                set: { isTargeted in
                    dropTargetFolderID = isTargeted ? folder.id : nil
                }
            ),
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
                dragPreview(for: folder, isGridView: true)
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
            dragPreview(for: note, isGridView: true)
        }
    }

    private var listView: some View {
        VStack(spacing: isCompactWidth ? 8 : 12) {
            listContent
        }
        .padding(.horizontal, isCompactWidth ? 12 : 16)
        .padding(.vertical, isCompactWidth ? 12 : 16)
        .id(refreshID)
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
        let isDropTarget = dropTargetFolderID == folder.id

        return applyCommonItemModifiers(
            view: ListFolderItemView(folder: folder, isSelected: isSelected, isSelectionMode: isSelectionMode, isDropTarget: isDropTarget),
            for: folder,
            isTargeted: Binding(
                get: { dropTargetFolderID == folder.id },
                set: { isTargeted in
                    dropTargetFolderID = isTargeted ? folder.id : nil
                }
            ),
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
                dragPreview(for: folder, isGridView: false)
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
            dragPreview(for: note, isGridView: false)
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
        // Batch move all selected notes - modify folder state in memory first
        for noteID in selectedNotes {
            guard storageManager.notes.contains(where: { $0.id == noteID }) else { continue }

            // Remove note from all folders
            for i in 0..<storageManager.folders.count {
                if storageManager.folders[i].noteIDs.contains(noteID) {
                    storageManager.folders[i].noteIDs.removeAll { $0 == noteID }
                    storageManager.folders[i].dateModified = Date()
                }
            }

            // Add note to destination folder (if specified)
            if let destID = destinationFolderID,
               let index = storageManager.folders.firstIndex(where: { $0.id == destID }) {
                storageManager.folders[index].noteIDs.append(noteID)
                storageManager.folders[index].dateModified = Date()
            }
        }

        // Move selected folders
        for folderID in selectedFolders {
            if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folderID }) {
                storageManager.folders[folderIndex].parentID = destinationFolderID
                storageManager.folders[folderIndex].dateModified = Date()
            }
        }

        // Save folder changes once for all modifications
        storageManager.saveFoldersState()

        // Clear selections
        selectedNotes.removeAll()
        selectedFolders.removeAll()

        // Exit selection mode
        isSelectionMode = false

        // Refresh UI once
        DispatchQueue.main.async {
            self.refreshID = UUID()
        }
    }

    private func bulkTagSelectedItems(with subject: String) {
        // Tag selected notes
        for noteID in selectedNotes {
            if let noteIndex = storageManager.notes.firstIndex(where: { $0.id == noteID }) {
                storageManager.notes[noteIndex].subject = subject
                let savedNote = storageManager.saveNote(storageManager.notes[noteIndex])
                TabManager.shared.updateNote(savedNote)
            }
        }

        // Tag selected folders
        for folderID in selectedFolders {
            if let folderIndex = storageManager.folders.firstIndex(where: { $0.id == folderID }) {
                storageManager.folders[folderIndex].subject = subject
                _ = storageManager.saveFolder(storageManager.folders[folderIndex])
            }
        }

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
        ImportManager.shared.handleDocumentImport(
            url: url,
            type: type,
            storageManager: storageManager,
            currentFolderID: currentFolderID,
            selectedSubject: selectedSubject
        ) { note in
            if let note = note {
                selectedNote = note
            }
        }
    }

    func handleImportedFiles(_ urls: [URL]) {
        ImportManager.shared.handleImportedFiles(
            urls,
            storageManager: storageManager,
            currentFolderID: currentFolderID,
            selectedSubject: selectedSubject
        ) { note in
            if let note = note {
                selectedNote = note
            }
        }
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
        ZStack {
            ScrollView {
                if filteredFavoriteNotes.isEmpty && filteredFavoriteFolders.isEmpty {
                    EmptyFavoritesView(
                        selectedItem: $selectedItem,
                        currentFolderID: $currentFolderID,
                        folderPath: $folderPath
                    )
                } else if preferencesManager.homeViewIsGridView {
                    favoritesGridView
                } else {
                    favoritesListView
                }
            }

            // Top fade effect
            VStack {
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                Spacer()
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
        ZStack {
            ScrollView {
                if recentNotes.isEmpty {
                    EmptyRecentsView(
                        selectedItem: $selectedItem,
                        currentFolderID: $currentFolderID,
                        folderPath: $folderPath
                    )
                } else if preferencesManager.homeViewIsGridView {
                    recentsGridView
                } else {
                    recentsListView
                }
            }

            // Top fade effect
            VStack {
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                Spacer()
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
        if preferencesManager.homeViewSortOption == "Name" {
            return recents.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else if preferencesManager.homeViewSortOption == "Type" {
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
                    dragPreview(for: note, isGridView: true)
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
                    dragPreview(for: note, isGridView: false)
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
                    dragPreview(for: folder, isGridView: true)
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
                    dragPreview(for: note, isGridView: true)
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
                    dragPreview(for: folder, isGridView: false)
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
                    dragPreview(for: note, isGridView: false)
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
        ZStack {
            ScrollView {
                if filteredSubjectNotes.isEmpty && filteredSubjectFolders.isEmpty {
                    EmptySubjectView(
                        showNewWrittenNoteView: $showNewWrittenNoteView,
                        subject: selectedSubject
                    )
                } else if preferencesManager.homeViewIsGridView {
                    subjectGridView
                } else {
                    subjectListView
                }
            }

            // Top fade effect
            VStack {
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)

                Spacer()
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
                    dragPreview(for: folder, isGridView: true)
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
                    dragPreview(for: note, isGridView: true)
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
                    dragPreview(for: folder, isGridView: false)
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
                    dragPreview(for: note, isGridView: false)
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
        let previewSize: PreviewGenerator.PreviewSize = preferencesManager.homeViewIsGridView ? .grid : .list
        PreviewCache.shared.preloadPreviews(for: notesToPreload, size: previewSize)
    }
}

// MARK: - View Modifiers for HomeView

struct LifecycleModifiers: ViewModifier {
    @Binding var hasValidatedSession: Bool
    let authManager: LocalAuthManager
    let preloadAction: () -> Void

    func body(content: Content) -> some View {
        content
            .task {
                guard !hasValidatedSession else { return }
                hasValidatedSession = true
                Task.detached(priority: .background) {
                    await authManager.validateSession()
                }
            }
            .onAppear {
                preloadAction()

                // Check app status in background (non-blocking)
                Task(priority: .userInitiated) {
                    await AppStatusManager.shared.checkAppStatus()
                }
            }
    }
}

struct PreloadingModifiers: ViewModifier {
    let selectedItem: String
    let currentFolderID: UUID?
    let selectedSubject: String?
    let homeViewIsGridView: Bool
    let preloadAction: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedItem) { _, _ in
                preloadAction()
            }
            .onChange(of: currentFolderID) { _, _ in
                preloadAction()
            }
            .onChange(of: selectedSubject) { _, _ in
                preloadAction()
            }
            .onChange(of: homeViewIsGridView) { _, _ in
                preloadAction()
            }
    }
}

struct SheetModifiers: ViewModifier {
    @Binding var showingSettings: Bool
    @Binding var pendingImport: PendingImport?
    let storageManager: StorageManager
    @Binding var isSelectionMode: Bool
    @Binding var selectedNotes: Set<UUID>
    @Binding var selectedFolders: Set<UUID>

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationSizing(.page)
            }
            .sheet(item: $pendingImport) { pendingImport in
                ImportPreviewView(pendingImport: pendingImport)
                    .environmentObject(storageManager)
            }
            .onChange(of: showingSettings) { oldValue, newValue in
                if newValue {
                    isSelectionMode = false
                    selectedNotes.removeAll()
                    selectedFolders.removeAll()
                }
            }
    }
}

struct ImportHandlingModifiers: ViewModifier {
    let pendingImport: PendingImport?
    let importedNote: Note?
    @Binding var selectedNote: Note?
    @Binding var selectedItem: String
    @Binding var selectedSubject: String?
    @Binding var currentFolderID: UUID?
    let storageManager: StorageManager
    let documentHandler: DocumentHandler

    func body(content: Content) -> some View {
        content
            .onChange(of: pendingImport?.id) { _, _ in
                if pendingImport != nil {
                    selectedNote = nil
                    selectedItem = "documents"
                }
            }
            .onChange(of: importedNote?.id) { _, _ in
                if let note = importedNote {
                    selectedItem = "documents"
                    // Keep current folder context instead of resetting to home
                    // selectedSubject and currentFolderID remain unchanged

                    var opened = note
                    opened.lastOpenedAt = Date()
                    let saved = storageManager.saveNote(opened)
                    TabManager.shared.updateNote(saved)
                    TabManager.shared.openTab(note: saved)
                    selectedNote = saved

                    documentHandler.importedNote = nil
                }
            }
    }
}

