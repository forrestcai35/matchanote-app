//
//  TrashView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 9/23/25.
//

import SwiftUI

struct TrashView: View {
    @ObservedObject private var trashManager = TrashManager.shared
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmptyConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            MatchaPageHeader(
                "Trash",
                subtitle: trashManager.trashItems.isEmpty
                    ? "No items in trash"
                    : "\(trashManager.trashItems.count) item\(trashManager.trashItems.count == 1 ? "" : "s") in trash"
            )

            if trashManager.trashItems.isEmpty {
                emptyTrashView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Empty Trash") {
                            showingEmptyConfirmation = true
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    
                    trashItemsSection
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
        .padding(.horizontal)
        .padding(.vertical, 20)
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
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Items you delete will appear here and will be removed after 30 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var trashItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MatchaSectionHeader(
                title: "Deleted Items",
                icon: "trash"
            )

            MatchaCard {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(trashManager.trashItems) { trashItem in
                            trashItemRow(trashItem)

                            if trashItem != trashManager.trashItems.last {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.trailing, 16)
                }
                .frame(maxHeight: 400)
            }

            if trashManager.trashItems.contains(where: { $0.shouldAutoDelete }) {
                MatchaCard {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Delete Notice")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Some items are scheduled for automatic deletion after 30 days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private func trashItemRow(_ trashItem: TrashItem) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        trashItem.type == .note
                            ? Color.blue.opacity(0.1)
                            : Color.orange.opacity(0.1)
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: trashItem.type == .note ? "doc.text" : "folder")
                    .foregroundColor(trashItem.type == .note ? .blue : .orange)
                    .font(.system(size: 18))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(trashItem.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack {
                    Text(trashItem.type == .note ? "Note" : "Folder")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Deleted \(formatDaysAgo(trashItem.daysSinceDeletion))")
                        .font(.caption)
                        .foregroundColor(trashItem.shouldAutoDelete ? .orange : .secondary)

                    if trashItem.shouldAutoDelete {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("Auto-delete soon")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    restoreTrashItem(trashItem)
                } label: {
                    Text("Restore")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    trashManager.permanentlyDeleteItem(trashItem)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
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