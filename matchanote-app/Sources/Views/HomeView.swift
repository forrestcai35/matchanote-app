//
//  HomeView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI
import matchanote_app

struct SidebarItem: Identifiable {
    var id: String
    var title: String
    var icon: String
}

// Full FavoritesView implementation
struct FavoritesView: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Favorites")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your favorite notes will appear here")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// Full StudyView implementation
struct StudyView: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Study")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your study notes will appear here")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct DocumentsView: View {
    @State private var notes = Note.samples
    @State private var searchText = ""
    @State private var selectedNote: Note? = nil
    @State private var selectedItem = "documents"
    @State private var sortOption = "Date"
    @State private var isGridView = true
    @EnvironmentObject var tabManager: TabManager

    let sidebarItems = [
        SidebarItem(id: "documents", title: "Documents", icon: "folder"),
        SidebarItem(id: "favorites", title: "Favorites", icon: "star"),
        SidebarItem(id: "study", title: "Study", icon: "rectangle.stack"),
    ]

    // Filtered notes based on search text
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            VStack(spacing: 0) {
                searchBar
                sidebarList
            }
            .navigationTitle("Matcha")

            // Main content area
            contentView
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    // MARK: - Component Views

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var sidebarList: some View {
        List {
            ForEach(sidebarItems) { item in
                HStack {
                    Image(systemName: item.icon)
                    Text(item.title)
                }
                .padding(.vertical, 8)
                .background(selectedItem == item.id ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .onTapGesture {
                    selectedItem = item.id
                }
            }
        }
        .listStyle(SidebarListStyle())
    }

    @ViewBuilder
    private var contentView: some View {
        if selectedItem == "documents" {
            documentsView
        } else if selectedItem == "favorites" {
            FavoritesView()
        } else if selectedItem == "study" {
            StudyView()
        }
    }

    // Document view as a computed property
    private var documentsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            documentHeader
            documentContent
        }
    }

    private var documentHeader: some View {
        HStack {
            Text("Documents")
                .font(.largeTitle)
                .bold()
            Spacer()
            sortMenu
            viewToggleButton
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private var sortMenu: some View {
        Menu {
            Button("Date", action: { sortOption = "Date" })
            Button("Name", action: { sortOption = "Name" })
            Button("Type", action: { sortOption = "Type" })
        } label: {
            Label(sortOption, systemImage: "arrow.up.arrow.down")
                .padding(8)
                .cornerRadius(8)
        }
    }

    private var viewToggleButton: some View {
        Button(action: { isGridView.toggle() }) {
            Label(
                isGridView ? "Grid View" : "List View",
                systemImage: isGridView ? "square.grid.2x2" : "list.bullet"
            )
            .labelStyle(.iconOnly)
            .padding(8)
            .cornerRadius(8)
        }
        .help(isGridView ? "Switch to List View" : "Switch to Grid View")
    }

    private var documentContent: some View {
        ScrollView {
            if isGridView {
                gridView
            } else {
                listView
            }
        }
    }

    private var gridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            spacing: 12
        ) {
            createNoteButton(inGrid: true)

            ForEach(filteredNotes) { note in
                NavigationLink(
                    destination: NoteView(note: note)
                        .navigationBarBackButtonHidden(true)
                        .environmentObject(tabManager)
                ) {
                    GridItemView(note: note)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        // When tapped, open the note in a tab
                        tabManager.openTab(note: note)
                    })
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var listView: some View {
        VStack(spacing: 12) {
            createNoteButton(inGrid: false)

            LazyVStack(spacing: 8) {
                ForEach(filteredNotes) { note in
                    NavigationLink(
                        destination: NoteView(note: note)
                            .navigationBarBackButtonHidden(true)
                            .environmentObject(tabManager)
                    ) {
                        ListItemView(note: note)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            // When tapped, open the note in a tab
                            tabManager.openTab(note: note)
                        })
                }
            }
        }
        .padding(.vertical)
    }

    private func createNoteButton(inGrid: Bool) -> some View {
        NavigationLink(destination: {
            let newNote = Note(
                title: "New Note",
                color: .blue,
                dateCreated: Date(),
                dateModified: Date()
            )
            // When creating a new note, open it in a tab
            tabManager.openTab(note: newNote)
            return NoteView(note: newNote)
                .navigationBarBackButtonHidden(true)
                .environmentObject(tabManager)
        }) {
            if inGrid {
                gridNewButton
            } else {
                listNewButton
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Add a helper view for the new button in list view
    private var listNewButton: some View {
        ListNewButtonView()
    }

    // Helper view with state for hover effect
    private struct ListNewButtonView: View {
        @State private var isHovered = false

        var body: some View {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("New...")
                    .foregroundColor(.blue)
                    .fontWeight(isHovered ? .medium : .regular)
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: isHovered ? 1.5 : 1, dash: [5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(isHovered ? 0.05 : 0))
                    )
            )
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
    }

    private var gridNewButton: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 1, dash: [5])
                    )
                    .frame(width: 160, height: 200)
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }
            Text("New...")
                .foregroundColor(.blue)
                .frame(width: 160)
                .multilineTextAlignment(.center)
                .font(.caption)
        }
        .frame(width: 160)
    }
}

// Add a helper view for list items
private struct ListItemView: View {
    let note: Note
    @State private var isHovered = false

    var body: some View {
        HStack {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(note.color)
                .frame(width: 6)
                .frame(maxHeight: .infinity)

            // Note info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    // Type icon next to title
                    Image(systemName: note.isWritten ? "pencil" : "text.alignleft")
                        .foregroundColor(.gray)
                        .font(.caption)

                    Text(note.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Text(note.dateModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)

            Spacer()

            // Star indicator
            Image(systemName: note.isFavorite ? "star.fill" : "star")
                .foregroundColor(note.isFavorite ? .yellow : .gray)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .padding(.horizontal)
        // Add hover and tap effects
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Add a helper view for grid items
private struct GridItemView: View {
    let note: Note
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            // Note card
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(note.color)
                    .frame(width: 160, height: 200)

                // Type overlay
                if !note.isWritten {
                    // Text note styling - add lined paper effect
                    VStack(spacing: 8) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 120, height: 1)
                        }
                    }
                } else {
                    // Handwritten note styling - add pencil icon
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.3))
                        .offset(x: 0, y: -30)
                }

                // Favorite indicator
                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .foregroundColor(note.isFavorite ? .white : .gray)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                // Type indicator badge
                Image(systemName: note.isWritten ? "pencil" : "text.alignleft")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
            .overlay(
                // Show a subtle overlay when hovered
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: isHovered ? 2 : 0)
                    .opacity(isHovered ? 0.7 : 0)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)

            // Note title
            Text(note.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 160)
                .multilineTextAlignment(.center)
                .fontWeight(.medium)
                .font(.subheadline)

            // Date
            Text(note.dateModified, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    DocumentsView()
        .environmentObject(TabManager())
}
