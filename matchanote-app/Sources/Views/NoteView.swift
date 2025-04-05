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

          // --- Contextual Toolbar ---
          if activeTab.note.isWritten {
            WrittenNoteToolbar()
          } else {
            TextNoteToolbar()
          }
          Divider()  // Add a divider below the contextual toolbar
          // --- End Contextual Toolbar ---

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
              if activeTab.note.isWritten {

                WrittenNoteView(note: activeTab.note, isEdited: $isEdited)
              } else {
                TextNoteView(note: activeTab.note, isEdited: $isEdited)
              }

              // Fallback if no tab is marked as active but tabs exist
            } else if !tabManager.tabs.isEmpty {
              let firstTab = tabManager.tabs[0]
              if firstTab.note.isWritten {
                WrittenNoteView(note: firstTab.note, isEdited: $isEdited)
              } else {
                TextNoteView(note: firstTab.note, isEdited: $isEdited)
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
            addNewTab()
          }) {
            HStack {
              Image(systemName: "plus")
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 10)
            .padding(.leading, 5)

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
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity)
    .background(Color.gray.opacity(0.05))
  }

  // Add a new tab with a sample note
  private func addNewTab() {
    let newNote = Note(
      title: "New Note \(tabManager.tabs.count + 1)",
      color: [.blue, .green, .orange, .purple, .pink].randomElement() ?? .blue,
      dateCreated: Date(),
      dateModified: Date(),
      isWritten: Bool.random()
    )

    tabManager.openTab(note: newNote)
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

struct WrittenNoteView: View {
  var note: Note
  @Binding var isEdited: Bool

  var body: some View {
    VStack {
      Canvas { context, size in
        // Simple canvas view as a placeholder for PencilKit
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(note.color.opacity(0.1)))
      }
      .background(note.color.opacity(0.1))
      .cornerRadius(10)
      .padding()
      .onTapGesture {
        // When canvas is drawn on, mark as edited
        isEdited = true
      }
    }
  }
}

struct TextNoteView: View {
  var note: Note
  @State private var textContent: String
  @Binding var isEdited: Bool

  init(note: Note, isEdited: Binding<Bool>) {
    self.note = note
    _textContent = State(initialValue: note.content)
    _isEdited = isEdited
  }

  var body: some View {
    VStack {
      TextEditor(text: $textContent)
        .padding()
        .background(note.color.opacity(0.1))
        .cornerRadius(10)
        .padding()
        .onChange(of: textContent) { oldValue, newValue in
          if oldValue != newValue {
            isEdited = true
          }
        }
    }
  }
}

// AI Assistant View
struct AIAssistantView: View {
  @State private var assistantText = ""
  @State private var userInput = ""

  var body: some View {
    VStack(spacing: 0) {
      // Assistant header
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(.blue)

        Text("Matcha Assistant")
          .font(.headline)

        Spacer()
      }
      .padding()
      .background(Color.gray.opacity(0.1))

      // Chat history area
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          // Sample messages
          AssistantMessageView(
            message: "Hi! I'm your Matcha assistant. How can I help you with your notes today?")

        }
        .padding()
      }

      // Input area
      HStack {
        TextField("Ask Matcha Assistant...", text: $userInput)
          .textFieldStyle(RoundedBorderTextFieldStyle())

        Button(action: {
          // Send message functionality would go here
          userInput = ""
        }) {
          Image(systemName: "arrow.up.circle.fill")
            .foregroundColor(.blue)
            .font(.title2)
        }
      }
      .padding()
    }
    .background(Color(.systemBackground))
    .cornerRadius(10)
    .shadow(radius: 2)
    .padding(.trailing)
  }
}

struct AssistantMessageView: View {
  var message: String

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "sparkles")
        .foregroundColor(.blue)
        .padding(.top, 4)

      Text(message)
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
  }
}

struct UserMessageView: View {
  var message: String

  var body: some View {
    HStack {
      Spacer()

      Text(message)
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
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

// MARK: - Contextual Toolbars

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

struct TextNoteToolbar: View {
  var body: some View {
    HStack {
      Spacer()

      Button(action: {}) { Image(systemName: "bold") }
      Button(action: {}) { Image(systemName: "italic") }
      Button(action: {}) { Image(systemName: "underline") }
      Button(action: {}) { Image(systemName: "list.bullet") }
      Button(action: {}) { Image(systemName: "list.number") }
      Button(action: {}) { Image(systemName: "textformat.size") }
      Button(action: {}) { Image(systemName: "character.textbox") }
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
    NoteView(note: Note.samples[0])
    NoteView(
      note: Note(
        title: "Text Note", color: .blue, dateCreated: Date(), dateModified: Date(),
        isWritten: false))
  }
}
