import SwiftUI

struct FolderNavigationView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]

    let onDropToFolder: (Folder) -> Bool
    let onDropToRoot: () -> Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            folderPathContent
        }
        .frame(height: folderPath.isEmpty ? 0 : 36)
    }

    private var folderPathContent: some View {
        HStack {
            if !folderPath.isEmpty {
                // Root folder navigation
                rootFolderButton

                // Chevron between path items
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Show path of folders
                folderPathLinks
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var rootFolderButton: some View {
        Button(action: {
            currentFolderID = nil
            folderPath = []
        }) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.caption)
                Text("Home")
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onDrop(of: ["public.text"], isTargeted: nil) { _, _ in
            // Drop to root level (no parent folder)
            return onDropToRoot()
        }
    }

    private var folderPathLinks: some View {
        ForEach(0..<folderPath.count, id: \.self) { index in
            folderPathLink(for: index)

            // Add chevron between path items, but not after the last one
            if index < folderPath.count - 1 {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private func folderPathLink(for index: Int) -> some View {
        Button(action: {
            // Navigate to this folder in the path
            if index == folderPath.count - 1 {
                // Already in this folder, do nothing
                return
            }

            // Navigate to the selected folder
            currentFolderID = folderPath[index].id
            folderPath = Array(folderPath.prefix(index + 1))
        }) {
            HStack(spacing: 4) {
                Text(folderPath[index].name)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                index == folderPath.count - 1
                    ? (colorScheme == .dark
                        ? Color.matchalight_dark.opacity(0.2)
                        : Color.matchalight_light.opacity(0.2)) : Color.gray.opacity(0.1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onDrop(of: ["public.text"], isTargeted: nil) { _, _ in
            // Get the target folder from the path
            let targetFolder = folderPath[index]
            return onDropToFolder(targetFolder)
        }
    }
}
