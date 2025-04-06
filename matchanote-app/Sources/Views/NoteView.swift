//
//  NoteView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import PencilKit
import SwiftUI
import matchanote_app

struct NoteView: View {
  var note: Note
  @Environment(\.dismiss) var dismiss
  @State private var isAssistantVisible = false
  @ObservedObject private var tabManager = TabManager.shared
  @State private var isEdited = false

  init(note: Note) {
    self.note = note
  }

  // Ensure the note appears in the tab bar when view appears
  private func openNoteInTab() {
    tabManager.openTab(note: note)
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        // Tab bar
        TabBarView(dismiss: dismiss)

        // Top Tool bar - only visible when tabs exist
        if let activeTab = tabManager.getActiveTab() {
          HStack {
            // Bookmark button
            Button(action: {
              // Bookmark functionality
            }) {
              Image(systemName: "bookmark")
                .foregroundColor(.blue)
            }
            Spacer()

            //Share Button
            Button(action: {
              // Share functionality
            }) {
              Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
            }

            Button(action: {
              isAssistantVisible.toggle()
            }) {
              Image(systemName: "wand.and.rays")
                .foregroundColor(isAssistantVisible ? .blue : .gray)
            }

          }
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .background(Color.white)
          Divider()

          // Decide which contextual toolbar to show
          switch activeTab.note.noteType {
          case .written:
            WrittenNoteToolbar()
          case .text:
            TextNoteToolbar()  // Placeholder
          case .markdown:
            EmptyView()  // Use EmptyView to show nothing
          }
          Divider()  // Add a divider below the contextual toolbar

        } else if !tabManager.tabs.isEmpty {
          // Handle case where tabs exist but none are active (should ideally not happen with current logic)
          Text("Error: No active tab found")
            .foregroundColor(.red)
        }  // No top bar or contextual toolbar if tabs are empty

        // Content area with conditional AI assistant
        HStack(spacing: 0) {
          // Main note content - show the active tab
          VStack {
            if let activeTab = tabManager.getActiveTab() {
              // Switch view based on note type
              switch activeTab.note.noteType {
              case .written:
                WrittenNoteView(note: activeTab.note, isEdited: $isEdited)
              case .text:
                TextNoteView(note: activeTab.note, isEdited: $isEdited)
              case .markdown:
                MarkdownNoteView(note: activeTab.note, isEdited: $isEdited)
              }

              // Fallback if no tab is marked as active but tabs exist
            } else if !tabManager.tabs.isEmpty {
              let firstTab = tabManager.tabs[0]
              // Switch view based on note type for fallback
              switch firstTab.note.noteType {
              case .written:
                WrittenNoteView(note: firstTab.note, isEdited: $isEdited)
              case .text:
                TextNoteView(note: firstTab.note, isEdited: $isEdited)
              case .markdown:
                MarkdownNoteView(note: firstTab.note, isEdited: $isEdited)
              }
            } else {
              // Show empty state when no tabs exist
              EmptyStateView()
            }
          }
          .frame(maxWidth: .infinity)
          .background(Color.white)

          // AI Assistant panel (conditionally visible)
          if isAssistantVisible {
            AIAssistantView()
              .frame(width: 300)
              .transition(.move(edge: .trailing))
          }
        }
        .animation(.spring(), value: isAssistantVisible)
      }
      .edgesIgnoringSafeArea(.all)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .onAppear {
        openNoteInTab()
      }
    }
    .navigationBarHidden(true)
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

// Tab Bar View
struct TabBarView: View {
  @ObservedObject private var tabManager = TabManager.shared
  var dismiss: DismissAction

  var body: some View {
    HStack {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
          // Home button
          Button(action: {
            // Check if there are unsaved changes before dismissing
            // In a real app, you might show a confirmation dialog here
            dismiss()
          }) {
            Image(systemName: "house")
              .foregroundColor(.blue)
          }
          .buttonStyle(PlainButtonStyle())

          // New tab button
          Button(action: {

          }) {
            HStack {
              Image(systemName: "plus")
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 10)
            .padding(.leading, 4)

            .cornerRadius(6)
          }
          .buttonStyle(PlainButtonStyle())

          // Existing tabs
          ForEach(tabManager.tabs) { tab in
            TabItemView(tab: tab)
          }
        }
      }

      // More options button
      Button(action: {
        // More options
      }) {
        Image(systemName: "ellipsis")
          .foregroundColor(.blue)

      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity)
    .background(Color.gray.opacity(0.05))
  }

}

// Individual Tab Item
struct TabItemView: View {
  let tab: NoteTab
  @ObservedObject private var tabManager = TabManager.shared

  var body: some View {
    HStack(spacing: 6) {
      // Tab content
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
      .background(tab.isActive ? Color.white : Color.gray.opacity(0.1))
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

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  var body: some View {
    HStack {
      Spacer()
      Button(action: {}) { Image(systemName: "arrow.uturn.backward") }
      Button(action: {}) { Image(systemName: "arrow.uturn.forward") }
      Divider()
        .frame(height: 20)

      Button(action: {}) { Image(systemName: "pencil.tip.crop.circle") }
      Button(action: {}) { Image(systemName: "eraser") }
      Button(action: {}) { Image(systemName: "highlighter") }
      Button(action: {}) { Image(systemName: "lasso") }
      Button(action: {}) { Image(systemName: "photo]") }
      Divider()
        .frame(height: 20)

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
  }
}

// Placeholder Toolbar for Text Notes
struct TextNoteToolbar: View {
  var body: some View {
    HStack {
      Spacer()
      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
  }
}

struct NoteView_Previews: PreviewProvider {
  static var previews: some View {
    NoteView(note: Note.samples[0])  // Written
    NoteView(note: Note.samples[1])  // Markdown
    NoteView(note: Note.samples[2])  // Text
  }
}
