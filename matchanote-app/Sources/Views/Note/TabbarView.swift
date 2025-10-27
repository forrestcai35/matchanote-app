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

  var body: some View {
    HStack(spacing: 8) {
      // Static Home Button (outside ScrollView)
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

      // Scrollable Tabs Section
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
          // Existing tabs
          ForEach(tabManager.tabs) { tab in
            TabItemView(tab: tab, onTabSwitch: onTabSwitch)
          }
        }
        .padding(.horizontal, 4)
      }

      // Static Action Buttons (outside ScrollView)
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
            // Vertical scroll mode toggle
            Button(action: {
              preferencesManager.noteEditorVerticalScrollMode.toggle()
            }) {
              HStack {
                Label(
                  preferencesManager.noteEditorVerticalScrollMode ? "Page Mode" : "Vertical Scroll",
                  systemImage: preferencesManager.noteEditorVerticalScrollMode 
                    ? "rectangle.split.2x1" 
                    : "rectangle.portrait.split.2x1"
                )
                .font(.jost(.body()))
                Spacer()

              }
            }
            .foregroundColor(
              colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
            )

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

            Button(action: {
              onOrientationToggle?()
              showMorePopover = false
            }) {
              Label("Switch Orientation", systemImage: "rotate.right")
                .font(.jost(.body()))
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
              deletePageAction?()
              showMorePopover = false
            }) {
              Label("Delete Page", systemImage: "trash.fill")
                .font(.jost(.body()))
            }
            .foregroundColor(.red)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .frame(minWidth: 240)
        }
      }
    }
    .padding(.top, 6)
    .padding(.horizontal, 12)
    .frame(height: 40)
    .frame(maxWidth: .infinity, alignment: .center)
    .background(
      colorScheme == .dark ? Color.tabbar_background_dark : Color.tabbar_background_light
    )
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
  @State private var newTitle: String = ""

  var body: some View {
    HStack {
      // Tab Content
      HStack {
        // Title left-aligned; rename available only when active
        if tab.isActive {
          Button(action: {
            newTitle = tab.note.title
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
            VStack(spacing: 12) {
              Text("Rename Note")
                .font(.jost(.headline()))
              TextField("Note name", text: $newTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
              HStack {
                Button("Cancel") {
                  showRenamePopover = false
                }
                .font(.jost(.body()))
                .foregroundColor(.red)
                Spacer()
                Button("Save") {
                  var updatedNote = tab.note
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
            .padding(4)
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
      .onTapGesture {
        activateTab()
      }

    }
  }

  // Activate this tab
  private func activateTab() {
    // Save current canvas data before switching tabs
    onTabSwitch?()

    // Make all tabs inactive first
    for i in 0..<tabManager.tabs.count {
      tabManager.tabs[i].isActive = false
    }

    // Then activate the selected tab
    if let index = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
      tabManager.tabs[index].isActive = true
    }
  }

  // Close this tab
  private func closeTab() {
    tabManager.closeTab(id: tab.id)
  }
}
