import SwiftUI

enum PagePlacement {
  case before, after, end
}

// Tab Bar View
struct TabBarView: View {
  @ObservedObject private var tabManager = TabManager.shared
  @Environment(\.colorScheme) private var colorScheme
  
  var dismiss: DismissAction
  var clearPageAction: (() -> Void)?
  var deletePageAction: (() -> Void)?
  var exportCurrentPageAction: (() -> Void)?
  var exportAllPagesAction: (() -> Void)?
  var printCurrentPageAction: (() -> Void)?
  var printAllPagesAction: (() -> Void)?
  var onAddPage: ((PagePlacement) -> Void)?
  var onUpload: ((PagePlacement) -> Void)?

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
        // Universal Add/Upload Menu
        Menu {
          // Before Current options
          Menu {
            Button(action: { onAddPage?(.before) }) {
              Label("Add Page", systemImage: "doc.badge.plus")
            }
            Button(action: { onUpload?(.before) }) {
              Label("Upload", systemImage: "square.and.arrow.up")
            }
          } label: {
            Label("Before Current", systemImage: "arrow.up")
          }
          
          // After Current options
          Menu {
            Button(action: { onAddPage?(.after) }) {
              Label("Add Page", systemImage: "doc.badge.plus")
            }
            Button(action: { onUpload?(.after) }) {
              Label("Upload", systemImage: "square.and.arrow.up")
            }
          } label: {
            Label("After Current", systemImage: "arrow.down")
          }
          
          // At End options
          Menu {
            Button(action: { onAddPage?(.end) }) {
              Label("Add Page", systemImage: "doc.badge.plus")
            }
            Button(action: { onUpload?(.end) }) {
              Label("Upload", systemImage: "square.and.arrow.up")
            }
          } label: {
            Label("At End", systemImage: "plus.rectangle.portrait")
          }
        } label: {
          Image(systemName: "plus.circle")
            .foregroundColor(.gray)
            .padding(4)
        }
        
        // Share Menu
        Menu {
          Button(action: { exportCurrentPageAction?() }) {
            Label("Export this page", systemImage: "doc")
          }
          Button(action: { exportAllPagesAction?() }) {
            Label("Export all pages", systemImage: "doc.on.doc")
          }
          Divider()
          Button(action: { printCurrentPageAction?() }) {
            Label("Print this page", systemImage: "printer")
          }
          Button(action: { printAllPagesAction?() }) {
            Label("Print all pages", systemImage: "printer.fill")
          }
        } label: {
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
            clearPageAction?()
          }) {
            Label("Clear Page", systemImage: "trash")
            .foregroundColor(.red)
            
          }
          
          Divider()
          
          Button(action: {
            deletePageAction?()
          }) {
            Label("Delete Page", systemImage: "trash.fill")
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

