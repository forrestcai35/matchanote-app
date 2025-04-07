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
  @State public var isAssistantVisible = false
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

        if let activeTab = tabManager.getActiveTab() {

          // Showcase Contextual Toolbars
          switch activeTab.note.noteType {
          case .written:
            WrittenNoteToolbar(isAssistantVisible: $isAssistantVisible)
          case .text:
            TextNoteToolbar(isAssistantVisible: $isAssistantVisible)
          case .markdown:
            MarkdownToolbar(isAssistantVisible: $isAssistantVisible)
          }
          Divider()

        } else if !tabManager.tabs.isEmpty {
          // Edge case for handling active tab + no tabs open
          Text("Error: No active tab found")
            .foregroundColor(.red)
        }

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

// Contextual Toolbars
struct WrittenNoteToolbar: View {
  @Binding var isAssistantVisible: Bool

  var body: some View {
    HStack {
      // Bookmark button
      Button(action: {
        // Bookmark functionality
      }) {
        Image(systemName: "bookmark")
          .foregroundColor(.gray)
      }

      //View Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(.gray)
      }
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
      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
  }
}

// Placeholder Toolbar for Text Notes
struct TextNoteToolbar: View {
  @Binding var isAssistantVisible: Bool

  var body: some View {
    HStack {

      // Bookmark button
      Button(action: {
        // Bookmark functionality
      }) {
        Image(systemName: "bookmark")
          .foregroundColor(.gray)
      }

      //View Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.grid.2x2")
          .foregroundColor(.gray)
      }
      Spacer()
      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Spacer()
      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .buttonStyle(PlainButtonStyle())
    .foregroundColor(.gray)
  }
}

// Placeholder Toolbar for Text Notes
struct MarkdownToolbar: View {
  @Binding var isAssistantVisible: Bool

  var body: some View {
    HStack {

      Spacer()
      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Spacer()
      //Share Button
      Button(action: {
        // Share functionality
      }) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(.gray)
      }

      // AI assistant toggle
      Button(action: {
        isAssistantVisible.toggle()
      }) {
        Image(systemName: "wand.and.rays")
          .foregroundColor(isAssistantVisible ? .green : .gray)
      }

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
