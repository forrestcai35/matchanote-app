

import SwiftUI

// MARK: - Empty State Views
struct EmptyDocumentsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showNewWrittenNoteView: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Mascot with context
            MatchaMascotWithContext(
                emotion: .happy,
                size: .large,
                title: "No Documents Yet",
                subtitle: "Create your first note or folder to get started",
                actionTitle: "Create Note",
                action: {
                    showNewWrittenNoteView = true
                }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptyFavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedItem: String
    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Mascot with context
            MatchaMascotWithContext(
                emotion: .star,
                size: .large,
                title: "No Favorites Yet",
                subtitle: "Mark notes as favorites to see them here",
                actionTitle: "Browse Documents",
                action: {
                    selectedItem = "documents"
                    currentFolderID = nil
                    folderPath = []
                }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptyRecentsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedItem: String
    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Mascot with context
            MatchaMascotWithContext(
                emotion: .happy,
                size: .large,
                title: "No Recent Notes",
                subtitle: "Recently opened notes will appear here",
                actionTitle: "Browse Documents",
                action: {
                    selectedItem = "documents"
                    currentFolderID = nil
                    folderPath = []
                }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptySubjectView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showNewWrittenNoteView: Bool
    var subject: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Mascot with context
            MatchaMascotWithContext(
                emotion: .happy,
                size: .large,
                title: "No Items in This Subject",
                subtitle: "Create your first note for this subject or tag existing notes",
                actionTitle: "Create Note",
                action: {
                    showNewWrittenNoteView = true
                }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
