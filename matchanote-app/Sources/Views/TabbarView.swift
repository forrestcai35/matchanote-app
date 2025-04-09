import SwiftUI
import matchanote_app

// Tab Bar View
struct TabBarView: View {
  @ObservedObject private var tabManager = TabManager.shared
  var dismiss: DismissAction

  var body: some View {
    HStack {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
          Button(action: {
            // TODO: Check if there are unsaved changes before dismissing BUT SHOULD AUTO SAVE
            dismiss()
          }) {
            Image(systemName: "house")
              .foregroundColor(.gray)
          }
          .padding(.trailing, 6)
          .buttonStyle(PlainButtonStyle())

          // Existing tabs
          ForEach(tabManager.tabs) { tab in
            TabItemView(tab: tab)
          }
        }
      }

      // 3 DOTS MORE OPTIIONS
      Button(action: {
        // TODO: Add more options
      }) {
        Image(systemName: "ellipsis")
          .foregroundColor(.green)

      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.top, 6)
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity)
    .background(Color.green.opacity(0.1))
  }

}

// Individual Tab Item
struct TabItemView: View {
  let tab: NoteTab
  @ObservedObject private var tabManager = TabManager.shared

  var body: some View {
    HStack(spacing: 6) {
      // Tab Content
      HStack {
        RoundedRectangle(cornerRadius: 2)
          .fill(tab.note.color)
          .frame(width: 12, height: 12)

        Text(tab.note.title)
          .font(.caption)
          .lineLimit(1)

        // Close button
        Button(action: {
          closeTab()
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 10))
            .foregroundColor(.gray)
            .padding(4)
        }
        .buttonStyle(PlainButtonStyle())

      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(tab.isActive ? Color.white : Color.gray.opacity(0.15))
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

// Empty state view when no tabs are open
struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "doc.text")
        .font(.system(size: 60))
        .foregroundColor(.gray.opacity(0.6))

      Text("No Note Selected")
        .font(.title2)
        .foregroundColor(.gray)

      Text("Create a new note or select an existing one to get started")
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
  }
}
