import SwiftUI

enum PagePlacement: String, CaseIterable, Hashable {
  case before, after, end

  var title: String {
    switch self {
    case .before: return "Before"
    case .after: return "After"
    case .end: return "Last Page"
    }
  }
}

// Tab Bar View
struct TabBarView: View {
  @ObservedObject private var tabManager = TabManager.shared
  @ObservedObject private var preferencesManager = PreferencesManager.shared
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager

  var dismiss: DismissAction
  var clearPageAction: (() -> Void)?
  var deletePageAction: (() -> Void)?
  var quickExportAction: (() -> Void)?
  var exportOptionsAction: (() -> Void)?
  var printCurrentPageAction: (() -> Void)?
  var printAllPagesAction: (() -> Void)?
  var onAddPage: ((PagePlacement) -> Void)?
  var onUpload: ((PagePlacement) -> Void)?
  var onTabSwitch: (() -> Void)?
  var onOrientationToggle: (() -> Void)?

  // Placement selection for add/upload actions
  @State private var selectedPlacement: PagePlacement = .after
  @State private var showAddPopover: Bool = false
  @State private var showExportPopover: Bool = false
  @State private var showMorePopover: Bool = false
  @State private var showDeleteNoteAlert: Bool = false
  @State private var pendingDeleteNoteId: UUID?
  @State private var showDeletePageAlert: Bool = false
  @State private var showSingleTabRenamePopover: Bool = false

  // Computed bindings for note properties
  private var orientationBinding: Binding<PaperOrientation> {
    Binding(
      get: {
        tabManager.getActiveTab()?.note.paperOrientation ?? .portrait
      },
      set: { newValue in
        guard var note = tabManager.getActiveTab()?.note else { return }
        note.paperOrientation = newValue
        note.dateModified = Date()
        let saved = storageManager.saveNote(note)
        tabManager.updateNote(saved)
        onOrientationToggle?()
      }
    )
  }

  private var paperColorBinding: Binding<PaperColor> {
    Binding(
      get: {
        tabManager.getActiveTab()?.note.paperColor ?? .white
      },
      set: { newValue in
        guard var note = tabManager.getActiveTab()?.note else { return }
        note.paperColor = newValue
        note.dateModified = Date()
        let saved = storageManager.saveNote(note)
        tabManager.updateNote(saved)
      }
    )
  }

  private var paperStyleBinding: Binding<PaperStyle> {
    Binding(
      get: {
        tabManager.getActiveTab()?.note.paperStyle ?? .lined
      },
      set: { newValue in
        guard var note = tabManager.getActiveTab()?.note else { return }
        note.paperStyle = newValue
        note.dateModified = Date()
        let saved = storageManager.saveNote(note)
        tabManager.updateNote(saved)
      }
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Base HStack with buttons
        HStack(spacing: 8) {
          // Static Home Button
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "house")
              .foregroundColor(
                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
              )
              .font(.system(size: 18))
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())

          // Center Section - Show title when single tab, tabs when multiple
          if tabManager.tabs.count == 1 {
            // Empty spacer when single tab (title overlaid in ZStack)
            Spacer()
          } else {
          // Multiple tabs: show scrollable tabs
          GeometryReader { scrollGeometry in
            ScrollViewReader { proxy in
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                  // Existing tabs
                  ForEach(tabManager.tabs) { tab in
                    TabItemView(tab: tab, onTabSwitch: onTabSwitch)
                      .id(tab.id)
                      .onAppear {
                        // When a new tab appears and it's active, scroll to show it
                        if tab.isActive {
                          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                              proxy.scrollTo(tab.id, anchor: .trailing)
                            }
                          }
                        }
                      }
                  }
                }
                .frame(minWidth: scrollGeometry.size.width - 8) // Account for horizontal padding
                .padding(.horizontal, 4)
              }
            }
          }
          .frame(maxWidth: .infinity)
        }

        // Static Action Buttons
        HStack(spacing: 4) {
        // Add / Upload popover
        Button(action: { showAddPopover.toggle() }) {
          Image(systemName: "plus.circle")
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            .font(.system(size: 20))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showAddPopover) {
          VStack(spacing: 12) {
            // Inline placement selector with segmented style
            Picker("", selection: $selectedPlacement) {
              ForEach(PagePlacement.allCases, id: \.self) { placement in
                Text(placement.title)
                  .font(.jost(.caption()))
                  .tag(placement)
              }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 300)
            .padding(.horizontal, 6)
            .padding(.top, 8)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
              Button(action: {
                onAddPage?(selectedPlacement)
                showAddPopover = false
              }) {
                Label("Add Page", systemImage: "doc.badge.plus")
                  .font(.jost(.body()))
              }
              .foregroundColor(
                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
              )
              Button(action: {
                onUpload?(selectedPlacement)
                showAddPopover = false
              }) {
                Label("Upload", systemImage: "square.and.arrow.up")
                  .font(.jost(.body()))
              }
              .foregroundColor(
                colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
              )
            }
            .padding(.horizontal, 6)
          }
          .padding(.vertical, 12)
          .frame(minWidth: 320)
        }

        // Export button with dropdown options
        Button(action: { showExportPopover.toggle() }) {
          Image(systemName: "square.and.arrow.up")
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            .font(.system(size: 18))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showExportPopover) {
          VStack(alignment: .leading, spacing: 8) {
            Button(action: {
              quickExportAction?()
              showExportPopover = false
            }) {
              Label("Quick Export (PDF)", systemImage: "doc.fill")
                .font(.jost(.body()))
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            Button(action: {
              exportOptionsAction?()
              showExportPopover = false
            }) {
              Label("Export Options", systemImage: "slider.horizontal.3")
                .font(.jost(.body()))
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            Divider()
            Button(action: {
              printCurrentPageAction?()
              showExportPopover = false
            }) {
              Label("Print this page", systemImage: "printer")
                .font(.jost(.body()))
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            Button(action: {
              printAllPagesAction?()
              showExportPopover = false
            }) {
              Label("Print all pages", systemImage: "printer.fill")
                .font(.jost(.body()))
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .frame(minWidth: 260)
        }

        // More options popover
        Button(action: { showMorePopover.toggle() }) {
          Image(systemName: "ellipsis")
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            .font(.system(size: 18))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showMorePopover) {
          VStack(alignment: .leading, spacing: 8) {
            // Scroll mode picker
//            HStack {
//              Label("Scroll Mode", systemImage: "scroll")
//                .font(.jost(.body()))
//                .foregroundColor(
//                  colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
//                )
//              Spacer()
//              Picker("", selection: $preferencesManager.noteEditorVerticalScrollMode) {
//                Text("Page").tag(false)
//                Text("Vertical").tag(true)
//              }
//              .pickerStyle(.menu)
//              .font(.jost(.body()))
//            }

            // Orientation picker
            HStack {
              Label("Orientation", systemImage: "rotate.right")
                .font(.jost(.body()))
                .foregroundColor(
                  colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
              Spacer()
              Picker("", selection: orientationBinding) {
                Text("Portrait").tag(PaperOrientation.portrait)
                Text("Landscape").tag(PaperOrientation.landscape)
              }
              .pickerStyle(.menu)
              .font(.jost(.body()))
              .frame(minWidth: 100)
            }

            // Paper color picker
            HStack {
              Label("Paper Color", systemImage: "paintpalette")
                .font(.jost(.body()))
                .foregroundColor(
                  colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
              Spacer()
              Picker("", selection: paperColorBinding) {
                Text("White").tag(PaperColor.white)
                Text("Off-White").tag(PaperColor.offwhite)
                Text("Dark").tag(PaperColor.dark)
              }
              .pickerStyle(.menu)
              .font(.jost(.body()))
              .frame(minWidth: 100)
            }

            // Paper pattern picker
            HStack {
              Label("Paper Pattern", systemImage: "square.grid.2x2")
                .font(.jost(.body()))
                .foregroundColor(
                  colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
              Spacer()
              Picker("", selection: paperStyleBinding) {
                Text("Blank").tag(PaperStyle.blank)
                Text("Lined").tag(PaperStyle.lined)
                Text("Grid").tag(PaperStyle.grid)
                Text("Dotted").tag(PaperStyle.dotted)
              }
              .pickerStyle(.menu)
              .font(.jost(.body()))
              .frame(minWidth: 100)
            }

            // Dark mode for white paper toggle
            Button(action: {
              preferencesManager.noteEditorDarkModeForWhitePaper.toggle()
            }) {
              HStack {
                Label(
                  "Content matches theme",
                  systemImage: preferencesManager.noteEditorDarkModeForWhitePaper
                    ? "checkmark.circle.fill"
                    : "circle"
                )
                .font(.jost(.body()))
                Spacer()
              }
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            Divider()
            Button(action: {
              clearPageAction?()
              showMorePopover = false
            }) {
              Label("Clear Page", systemImage: "trash")
                .font(.jost(.body()))
            }
            .foregroundColor(.red)
            Button(action: {
              // Intercept delete to check if this would remove the final page
              if let activeTab = tabManager.getActiveTab() {
                let note = activeTab.note
                let total = totalPages(for: note)
                if total <= 1 {
                  pendingDeleteNoteId = note.id
                  showDeleteNoteAlert = true
                } else {
                  showDeletePageAlert = true
                }
              } else {
                showDeletePageAlert = true
              }
              showMorePopover = false
            }) {
              Label("Delete Page", systemImage: "trash.fill")
                .font(.jost(.body()))
            }
            .foregroundColor(.red)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .frame(minWidth: 280)
        }
      }
      }
      .padding(.top, 6)
      .padding(.horizontal, 12)
      .frame(width: geometry.size.width, height: 40)

      // Overlay centered title for single tab (positioned absolutely in center)
      if tabManager.tabs.count == 1, let singleTab = tabManager.tabs.first {
        Button(action: {
          showSingleTabRenamePopover = true
        }) {
          HStack(spacing: 4) {
            Text(singleTab.note.title)
              .font(.jost(.body()))
              .lineLimit(1)
            Image(systemName: "chevron.down")
              .font(.system(size: 10))
              .foregroundColor(.gray)
          }
          .foregroundColor(
            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showSingleTabRenamePopover) {
          RenameNotePopover(
            originalTitle: singleTab.note.title,
            isPresented: $showSingleTabRenamePopover,
            onSave: { newTitle in
              var updatedNote = singleTab.note
              updatedNote.title = newTitle
              updatedNote.dateModified = Date()
              let savedNote = storageManager.saveNote(updatedNote)
              TabManager.shared.updateNote(savedNote)
            }
          )
        }
        .frame(width: geometry.size.width, height: 40)
        .allowsHitTesting(true)
      }
      }
    }
    .frame(height: 40)
    .background(
      colorScheme == .dark ? Color.tabbar_background_dark : Color.tabbar_background_light
    )
    .alert("Delete Note", isPresented: $showDeleteNoteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete Note", role: .destructive) {
        if let id = pendingDeleteNoteId {
          storageManager.deleteNote(withID: id)
          pendingDeleteNoteId = nil
        }
      }
    } message: {
      Text("Deleting the last page will remove the entire note. This action cannot be undone. Continue?")
    }
    .alert("Delete Page", isPresented: $showDeletePageAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        deletePageAction?()
      }
    } message: {
      Text("Are you sure you want to delete this page? This action cannot be undone.")
    }
  }

  // MARK: - Helpers
  private func totalPages(for note: Note) -> Int {
    let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? 0
    let maxPage = max(maxDrawingPage, maxImagePage)
    return max(1, maxPage + 1)
  }

}

// Individual Tab Item
struct TabItemView: View {
  let tab: NoteTab
  var onTabSwitch: (() -> Void)?
  @ObservedObject private var tabManager = TabManager.shared
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var storageManager: StorageManager
  @State private var showRenamePopover: Bool = false
  @State private var isDropTarget: Bool = false

  var body: some View {
    HStack {
      // Tab Content
      HStack {
        // Title left-aligned; rename available only when active
        if tab.isActive {
          Button(action: {
            showRenamePopover = true
          }) {
            HStack(spacing: 4) {
              Text(tab.note.title)
                .font(.jost(.caption()))
                .lineLimit(1)
                .foregroundColor(
                  colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
              Image(systemName: "chevron.down")
                .foregroundColor(.gray)
                .font(.system(size: 10))
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())
          .popover(isPresented: $showRenamePopover) {
            RenameNotePopover(
              originalTitle: tab.note.title,
              isPresented: $showRenamePopover,
              onSave: { newTitle in
                var updatedNote = tab.note
                updatedNote.title = newTitle
                updatedNote.dateModified = Date()
                let savedNote = storageManager.saveNote(updatedNote)
                TabManager.shared.updateNote(savedNote)
              }
            )
          }
        } else {
          Text(tab.note.title)
            .font(.jost(.caption()))
            .lineLimit(1)
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark.opacity(0.8) : Color.matchabrown_light.opacity(0.8))
        }
        Spacer()
        // Close button
        Button(action: {
          closeTab()
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 10))
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )
            .padding(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())

      }
      .padding(.horizontal, 8)
      .frame(height: 34)
      .frame(minWidth: tab.isActive ? 160 : 155)
      .background(
        tab.isActive
          ? colorScheme == .dark ? Color.toolbar_background_dark : Color.toolbar_background_light
          : colorScheme == .dark ? Color.tab_inactive_dark : Color.tab_inactive_light
      )
      .clipShape(
        tab.isActive
          ? RoundedCorners(topLeft: 6, topRight: 6, bottomLeft: 0, bottomRight: 0)
          : RoundedCorners(topLeft: 7, topRight: 7, bottomLeft: 0, bottomRight: 0)
      )
      .overlay(
        // Visual indicator when this tab is a drop target
        isDropTarget
          ? RoundedRectangle(cornerRadius: 6)
              .stroke(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light, lineWidth: 2)
          : nil
      )
      .onTapGesture {
        activateTab()
      }
      .onDrag {
        startDragging()
      }
      .onDrop(of: ["public.text"], isTargeted: $isDropTarget) { providers, location in
        handleDrop()
      }

    }
  }

  // Activate this tab
  private func activateTab() {
    // Don't activate if already active
    guard !tab.isActive else { return }

    // Save current canvas data before switching tabs
    onTabSwitch?()

    // Use TabManager's openTab to properly switch tabs
    // This ensures proper state synchronization
    tabManager.openTab(note: tab.note)
  }

  // Close this tab
  private func closeTab() {
    tabManager.closeTab(id: tab.id)
  }

  // MARK: - Drag and Drop Helpers

  /// Initiates dragging this tab
  private func startDragging() -> NSItemProvider {
    return tabManager.startDraggingTab(tab)
  }

  /// Handles dropping another tab onto this tab
  private func handleDrop() -> Bool {
    guard let draggedID = tabManager.draggedTabID else { return false }
    return tabManager.handleTabDrop(sourceID: draggedID, targetID: tab.id)
  }
}
