import SwiftUI
import matchanote_app

public struct ListItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let note: Note

    public var body: some View {
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
                    Image(systemName: noteTypeIcon(note.noteType))
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
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
                .fill(Color.secondary.opacity(0.05))

        )
        .padding(.horizontal)
        .contentShape(Rectangle())
    }

    // Use the DocumentsView noteTypeIcon function
    private func noteTypeIcon(_ type: NoteType) -> String {
        switch type {
        case .written:
            return "pencil"
        case .text:
            return "text.page"
        }
    }
}

// Add a helper view for folder list items
public struct ListFolderItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let folder: Folder

    public var body: some View {
        HStack {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(folder.color)
                .frame(width: 6)
                .frame(maxHeight: .infinity)

            // Folder info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .font(.caption)
                    Text(folder.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Text(folder.dateModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)

            Spacer()

            // Star indicator
            Image(systemName: folder.isFavorite ? "star.fill" : "star")
                .foregroundColor(folder.isFavorite ? .yellow : .gray)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

// Add a helper view for folder grid items
public struct GridFolderItemView: View {
    let folder: Folder
    @Environment(\.colorScheme) private var colorScheme

    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Folder card
            ZStack {
                // Folder image instead of background
                Image("folder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 175, height: 140)
                    .clipped()

                // Favorite indicator
                Image(systemName: folder.isFavorite ? "star.fill" : "star")
                    .foregroundColor(folder.isFavorite ? .yellow : .gray)
                    .padding(8)
                    .frame(maxWidth: 165, maxHeight: 95, alignment: .topTrailing)
            }
            // Folder title
            Text(folder.name)
                .padding(.top, 5)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 160)
                .multilineTextAlignment(.center)
                .fontWeight(.medium)
                .font(.subheadline)
            // Date
            Text(folder.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .contentShape(Rectangle())
    }
}

// Add a helper view for grid items
public struct GridItemView: View {
    let note: Note
    @Environment(\.colorScheme) private var colorScheme

    private func itemShadow(in colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Note card
            ZStack {

                // Written note cover
                if note.noteType == .written {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(note.color)
                        .frame(width: 160, height: 200)
                        .shadow(
                            color: itemShadow(in: colorScheme),
                            radius: 5,
                            x: 0,
                            y: 2
                        )

                    Image(systemName: "pencil.tip")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.3))
                        .offset(x: 0, y: -30)
                    //Text note cover
                } else if note.noteType == .text {
                    // Background
                    RoundedRectangle(cornerRadius: 0)
                        .fill(note.color)
                        .frame(width: 160, height: 200)
                        .shadow(
                            color: itemShadow(in: colorScheme),
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.3))
                        .offset(x: 0, y: -30)
                }

                // Favorite indicator
                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .foregroundColor(note.isFavorite ? .yellow : .gray)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                // Type indicator badge
                Image(systemName: noteTypeIcon(note.noteType))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }

            // Note title
            Text(note.title)
                .padding(.top, 5)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 160)
                .multilineTextAlignment(.center)
                .fontWeight(.medium)
                .font(.subheadline)

            // Date
            Text(note.dateModified, style: .date)
                .padding(.bottom, 5)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .contentShape(Rectangle())

    }

    // Use the DocumentsView noteTypeIcon function
    private func noteTypeIcon(_ type: NoteType) -> String {
        switch type {
        case .written:
            return "pencil"
        case .text:
            return "text.page"
        }
    }
}

#Preview {
    DocumentsView()
        .environmentObject(AIAssistantState())
}
