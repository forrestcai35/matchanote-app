

import SwiftUI

struct TrashView: View {
    @ObservedObject private var trashManager = TrashManager.shared
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmptyConfirmation = false
    @State private var sortMostRecentFirst = true

    private var sortedTrashItems: [TrashItem] {
        trashManager.trashItems.sorted { item1, item2 in
            if sortMostRecentFirst {
                return item1.daysSinceDeletion < item2.daysSinceDeletion
            } else {
                return item1.daysSinceDeletion > item2.daysSinceDeletion
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Trash")
                    .font(.jost(.largeTitle()))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)
            
            if trashManager.trashItems.isEmpty {
                emptyTrashView
            } else {
                // Trash list
                ZStack {
                    List {
                    Section {
                        ForEach(sortedTrashItems) { trashItem in
                            trashItemRow(trashItem)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(
                                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                .font(.system(size: 14))
                            Text("Deleted Items")
                                .font(.jost(.subheadline()))
                                .foregroundColor(
                                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                            Spacer()

                            Button {
                                sortMostRecentFirst.toggle()
                            } label: {
                                Image(systemName: sortMostRecentFirst ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(
                                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                colorScheme == .dark
                                                    ? Color.matchalight_dark.opacity(0.1)
                                                    : Color.matchalight_light.opacity(0.1)
                                            )
                                    )
                            }

                            Button("Empty Trash") {
                                showingEmptyConfirmation = true
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    } footer: {
                        if trashManager.trashItems.contains(where: { $0.shouldAutoDelete }) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                
                                Text("Some items are scheduled for automatic deletion after 30 days")
                                    .font(.jost(.caption2()))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)

                    // Top fade effect
                    VStack {
                        (colorScheme == .dark
                            ? Color.matchabackground_dark
                            : Color.matchabackground_light)
                            .mask(
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 20)
                            .allowsHitTesting(false)

                        Spacer()
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .confirmationDialog(
            "Empty Trash",
            isPresented: $showingEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) {
                trashManager.emptyTrash()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all items in the trash. This action cannot be undone.")
        }
    }

    private var emptyTrashView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("Trash is Empty")
                    .font(.jost(.headline()))
                    .foregroundColor(.primary)

                Text("Items you delete will appear here and will be removed after 30 days")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }


    private func trashItemRow(_ trashItem: TrashItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        trashItem.type == .note
                            ? Color.blue.opacity(0.1)
                            : Color.orange.opacity(0.1)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: trashItem.type == .note ? "doc.text" : "folder")
                    .foregroundColor(trashItem.type == .note ? .blue : .orange)
                    .font(.system(size: 14))
            }

            // Content
            VStack(alignment: .leading, spacing: 1) {
                Text(trashItem.title)
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack {
                    Text(trashItem.type == .note ? "Note" : "Folder")
                        .font(.jost(.caption2()))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.jost(.caption2()))
                        .foregroundColor(.secondary)

                    Text("Deleted \(formatDaysAgo(trashItem.daysSinceDeletion))")
                        .font(.jost(.caption2()))
                        .foregroundColor(trashItem.shouldAutoDelete ? .orange : .secondary)

                    if trashItem.shouldAutoDelete {
                        Text("•")
                            .font(.jost(.caption2()))
                            .foregroundColor(.orange)

                        Text("Auto-delete soon")
                            .font(.jost(.caption2()))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                Button {
                    restoreTrashItem(trashItem)
                } label: {
                    Text("Restore")
                        .font(.jost(.caption2()))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color.matchalight_dark.opacity(0.2)
                                : Color.matchalight_light.opacity(0.2)
                        )
                        .foregroundColor(
                            colorScheme == .dark
                                ? Color.matchalight_dark
                                : Color.matchalight_light
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    trashManager.permanentlyDeleteItem(trashItem)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                        .padding(4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func formatDaysAgo(_ days: Int) -> String {
        switch days {
        case 0:
            return "today"
        case 1:
            return "yesterday"
        default:
            return "\(days) days ago"
        }
    }

    private func restoreTrashItem(_ trashItem: TrashItem) {
        let restored = trashManager.restoreItem(trashItem)

        if let note = restored.note {
            storageManager.restoreNoteFromTrash(note)
        } else if let folder = restored.folder {
            storageManager.restoreFolderFromTrash(folder)
        }
    }
}

// MARK: - Preview
#Preview {
    TrashView()
        .environmentObject(StorageManager())
}