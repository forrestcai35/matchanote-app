import SwiftUI
// MARK: - Move Note Sheet
struct MoveNoteSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID?
    @Binding var selectedDestinationFolderID: UUID?
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Move to")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Destination list
            List {
                // Home (no folder)
                HStack {
                    Image(systemName: "house")
                    Text("Home")
                    Spacer()
                    if selectedDestinationFolderID == nil { 
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDestinationFolderID = nil
                }

                // Top-level folders only (no parent)
                ForEach(folders.filter { $0.parentID == nil }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.name)
                        Spacer()
                        if selectedDestinationFolderID == folder.id { 
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDestinationFolderID = folder.id
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Button("Cancel") { 
                    onCancel() 
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Move") { 
                    onConfirm() 
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .background(
            colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
        )
    }
}

// MARK: - Bulk Move Sheet
struct BulkMoveSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID?
    @Binding var selectedDestinationFolderID: UUID?
    let selectedNotes: Set<UUID>
    let selectedFolders: Set<UUID>
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Move Selected Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Selection summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Moving \(selectedNotes.count + selectedFolders.count) items:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if selectedNotes.count > 0 {
                    Text("• \(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if selectedFolders.count > 0 {
                    Text("• \(selectedFolders.count) folder\(selectedFolders.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )

            // Destination list
            List {
                // Home (no folder)
                HStack {
                    Image(systemName: "house")
                    Text("Home")
                    Spacer()
                    if selectedDestinationFolderID == nil { 
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDestinationFolderID = nil
                }

                // Top-level folders only (no parent)
                ForEach(folders.filter { $0.parentID == nil }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.name)
                        Spacer()
                        if selectedDestinationFolderID == folder.id { 
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDestinationFolderID = folder.id
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Button("Cancel") { 
                    onCancel() 
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Move") { 
                    onConfirm() 
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .background(
            colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light
        )
    }
}
