import SwiftUI


// Tab Bar View
struct TabBarView: View {
  @ObservedObject private var tabManager = TabManager.shared
    @Environment(\.colorScheme) private var colorScheme
  var dismiss: DismissAction
  var clearPageAction: (() -> Void)?

  var body: some View {
    HStack(spacing: 8) {
      // Static Home Button (outside ScrollView)
      Button(action: {
        dismiss()
      }) {
        Image(systemName: "house")
          .foregroundColor(.gray)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Scrollable Tabs Section
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
          // Existing tabs
          ForEach(tabManager.tabs) { tab in
            TabItemView(tab: tab)
          }
        }
        .padding(.horizontal, 4) // Add some padding inside scroll view
      }
      
      // Static Action Buttons (outside ScrollView)
      HStack(spacing: 4) {
        // Add button
        Button(action: {
          // Add functionality
        }) {
          Image(systemName: "plus.circle")
            .foregroundColor(.gray)
            .padding(4)
        }
        
        //Share Button
        Button(action: {
          // Share functionality
        }) {
          Image(systemName: "square.and.arrow.up")
            .foregroundColor(.gray)
            .padding(4)
        }

        // More options dropdown menu
        Menu {
          Button(action: {
            // TODO: Implement rotate page functionality
          }) {
            Label("Rotate Page", systemImage: "rotate.right")
          }
          
          Button(action: {
            // TODO: Implement change template functionality
          }) {
            Label("Change Template", systemImage: "doc.text")
          }
          
          Button(action: {
            clearPageAction?()
          }) {
            Label("Clear Page", systemImage: "trash")
          }
          
          Divider()
          
          Button(action: {
            // TODO: Implement move page to trash functionality
          }) {
            Label("Move Page to Trash", systemImage: "trash.fill")
          }
          .foregroundColor(.red)
        } label: {
          Image(systemName: "ellipsis")
            .foregroundColor(.gray)
            .padding(4)
        }
      }
    }
    .padding(.top, 6)
    .padding(.horizontal, 12)
    .frame(height: 40)
    .frame(maxWidth: .infinity)
    .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.15))
  }

}

// Individual Tab Item
struct TabItemView: View {
  let tab: NoteTab
  @ObservedObject private var tabManager = TabManager.shared
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      // Tab Content
      HStack {
        RoundedRectangle(cornerRadius: 2)
          .fill(tab.note.color)
          .frame(width: 12, height: 12)
        Spacer()
        Text(tab.note.title)
          .font(.caption)
          .lineLimit(1)
          .foregroundColor(
            tab.isActive
              ? (colorScheme == .dark ? Color.white : Color.black)
              : (colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8)))
        Spacer()
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
      .frame(height: tab.isActive ? 34 : 32)
      .frame(minWidth: tab.isActive ? 140 : 135)
      .background(
        tab.isActive
          ? colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white
          : colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.2)
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
    @Environment(\.colorScheme) private var colorScheme
    
  var body: some View {
    VStack(spacing: 20) {


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
    .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
  }
}
