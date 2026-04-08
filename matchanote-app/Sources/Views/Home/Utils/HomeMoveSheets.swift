import SwiftUI

// MARK: - Move Destination Row
/// Reusable row component for folder selection in move sheets
struct MoveDestinationRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let indentLevel: Int
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var indentPadding: CGFloat {
        CGFloat(indentLevel) * 24
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Indentation spacer
                if indentLevel > 0 {
                    Spacer()
                        .frame(width: indentPadding)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(
                        isDisabled
                            ? .secondary.opacity(0.4)
                            : (isSelected
                                ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                                : (colorScheme == .dark ? Color.matchabrown_dark.opacity(0.7) : Color.matchabrown_light.opacity(0.7)))
                    )
                    .frame(width: 24)

                Text(title)
                    .font(.jost(.body()))
                    .foregroundColor(
                        isDisabled
                            ? .secondary.opacity(0.4)
                            : (isSelected
                                ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                : .primary)
                    )
                    .strikethrough(isDisabled, color: .secondary.opacity(0.4))

                Spacer()

                if isSelected && !isDisabled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isDisabled
                            ? Color.clear
                            : (isSelected
                                ? (colorScheme == .dark
                                    ? Color.matchalight_dark.opacity(0.12)
                                    : Color.matchalight_light.opacity(0.12))
                                : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isDisabled
                            ? Color.clear
                            : (isSelected
                                ? (colorScheme == .dark ? Color.matchalight_dark.opacity(0.3) : Color.matchalight_light.opacity(0.3))
                                : Color.clear),
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Move Sheet Header
/// Reusable header component for move sheets
struct MoveSheetHeader: View {
    let title: String
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.jost(.title2()))
                .foregroundColor(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.02 : 0.02)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
}

// MARK: - Move Sheet Actions
/// Reusable action buttons for move sheets
struct MoveSheetActions: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.jost(.body()))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onConfirm) {
                Text("Move")
                    .font(.jost(.body()))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.02 : 0.02)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
}

// MARK: - Helper Types & Functions

/// Represents a folder with its hierarchy depth for display
struct FolderWithDepth: Identifiable {
    let folder: Folder
    let depth: Int

    var id: UUID { folder.id }
}

/// Helper functions for folder hierarchy management
extension Array where Element == Folder {
    /// Flattens the folder hierarchy into a sorted list with depth levels
    /// - Returns: Array of folders with their depth in the hierarchy
    func flattenHierarchy() -> [FolderWithDepth] {
        var result: [FolderWithDepth] = []
        let rootFolders = self.filter { $0.parentID == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for folder in rootFolders {
            flattenFolder(folder, depth: 0, into: &result)
        }

        return result
    }

    /// Recursively flattens a folder and its children
    private func flattenFolder(_ folder: Folder, depth: Int, into result: inout [FolderWithDepth]) {
        result.append(FolderWithDepth(folder: folder, depth: depth))

        // Get child folders from the main array (by parentID)
        let children = self
            .filter { $0.parentID == folder.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for child in children {
            flattenFolder(child, depth: depth + 1, into: &result)
        }
    }

    /// Checks if moving sourceID into targetID would create a circular reference
    /// - Parameters:
    ///   - sourceID: The folder being moved
    ///   - targetID: The destination folder
    /// - Returns: True if this would create a circular reference
    func wouldCreateCircularReference(sourceID: UUID, targetID: UUID?) -> Bool {
        // Can't move folder into itself
        if sourceID == targetID {
            return true
        }

        // Moving to root is always safe
        guard let targetID = targetID else {
            return false
        }

        // Check if target is a descendant of source
        // (i.e., traverse up from target - if we reach source, it's circular)
        var currentID = targetID

        while let folder = self.first(where: { $0.id == currentID }) {
            if folder.id == sourceID {
                return true // Target is descendant of source!
            }

            if let parentID = folder.parentID {
                currentID = parentID
            } else {
                break // Reached root
            }
        }

        return false
    }

    /// Gets all descendant folder IDs for a given folder
    /// - Parameter folderID: The parent folder ID
    /// - Returns: Set of all descendant folder IDs
    func getAllDescendantIDs(of folderID: UUID) -> Set<UUID> {
        var descendants: Set<UUID> = []

        let children = self.filter { $0.parentID == folderID }
        for child in children {
            descendants.insert(child.id)
            descendants.formUnion(getAllDescendantIDs(of: child.id))
        }

        return descendants
    }
}

// MARK: - Move Note Sheet
struct MoveNoteSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID?
    @Binding var selectedDestinationFolderID: UUID?
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var flattenedFolders: [FolderWithDepth] {
        folders.flattenHierarchy()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MoveSheetHeader(title: "Move to", onDismiss: onCancel)

            // Content
            ScrollView {
                VStack(spacing: 8) {
                    // Home option
                    MoveDestinationRow(
                        icon: "house.fill",
                        title: "Home",
                        isSelected: selectedDestinationFolderID == nil,
                        indentLevel: 0,
                        isDisabled: false,
                        action: {
                            selectedDestinationFolderID = nil
                        }
                    )

                    // All folders with hierarchy indentation
                    ForEach(flattenedFolders) { folderWithDepth in
                        MoveDestinationRow(
                            icon: "folder.fill",
                            title: folderWithDepth.folder.name,
                            isSelected: selectedDestinationFolderID == folderWithDepth.folder.id,
                            indentLevel: folderWithDepth.depth,
                            isDisabled: false,
                            action: {
                                selectedDestinationFolderID = folderWithDepth.folder.id
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light
            )

            // Actions
            MoveSheetActions(onCancel: onCancel, onConfirm: onConfirm)
        }
        .frame(minWidth: 450, minHeight: 500)
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light
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

    private var flattenedFolders: [FolderWithDepth] {
        folders.flattenHierarchy()
    }

    private var totalItems: Int {
        selectedNotes.count + selectedFolders.count
    }

    /// Set of all folder IDs that cannot be used as destinations
    /// (selected folders and their descendants)
    private var invalidDestinations: Set<UUID> {
        var invalid: Set<UUID> = selectedFolders

        // Add all descendants of selected folders
        for folderID in selectedFolders {
            invalid.formUnion(folders.getAllDescendantIDs(of: folderID))
        }

        return invalid
    }

    /// Checks if a folder should be disabled as a destination
    private func isFolderDisabled(_ folderID: UUID) -> Bool {
        // If we're moving folders, check for invalid destinations
        guard !selectedFolders.isEmpty else {
            return false
        }

        return invalidDestinations.contains(folderID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MoveSheetHeader(title: "Move Selected Items", onDismiss: onCancel)

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Selection summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Moving \(totalItems) item\(totalItems == 1 ? "" : "s")")
                            .font(.jost(.body()))
                            .fontWeight(.medium)
                            .foregroundColor(
                                colorScheme == .dark
                                    ? Color.matchabrown_dark
                                    : Color.matchabrown_light
                            )

                        HStack(spacing: 20) {
                            if selectedNotes.count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("\(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")")
                                        .font(.jost(.caption()))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if selectedFolders.count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("\(selectedFolders.count) folder\(selectedFolders.count == 1 ? "" : "s")")
                                        .font(.jost(.caption()))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                colorScheme == .dark
                                    ? Color.matchalight_dark.opacity(0.08)
                                    : Color.matchalight_light.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.matchalight_dark.opacity(0.15)
                                    : Color.matchalight_light.opacity(0.15),
                                lineWidth: 1
                            )
                    )

                    // Destinations
                    VStack(spacing: 8) {
                        // Home option
                        MoveDestinationRow(
                            icon: "house.fill",
                            title: "Home",
                            isSelected: selectedDestinationFolderID == nil,
                            indentLevel: 0,
                            isDisabled: false,
                            action: {
                                selectedDestinationFolderID = nil
                            }
                        )

                        // All folders with hierarchy indentation
                        ForEach(flattenedFolders) { folderWithDepth in
                            let disabled = isFolderDisabled(folderWithDepth.folder.id)

                            MoveDestinationRow(
                                icon: "folder.fill",
                                title: folderWithDepth.folder.name,
                                isSelected: selectedDestinationFolderID == folderWithDepth.folder.id,
                                indentLevel: folderWithDepth.depth,
                                isDisabled: disabled,
                                action: {
                                    if !disabled {
                                        selectedDestinationFolderID = folderWithDepth.folder.id
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light
            )

            // Actions
            MoveSheetActions(onCancel: onCancel, onConfirm: onConfirm)
        }
        .frame(minWidth: 450, minHeight: 550)
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light
        )
    }
}

// MARK: - Bulk Tag Menu
/// Dropdown menu for bulk subject tagging
struct BulkTagMenu: View {
    let subjects: [Subject]
    let currentSubjects: Set<String>
    let hasSubjects: Bool
    let onSelectSubject: (String) -> Void
    let onClearSubjects: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var sortedSubjects: [Subject] {
        subjects
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Menu {
            // Current subjects indicator (if any)
            if hasSubjects {
                Section {
                    Label {
                        Text("Currently tagged:")
                            .font(.jost(.caption()))
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .disabled(true)

                    ForEach(Array(currentSubjects).sorted(), id: \.self) { subjectName in
                        if let subject = subjects.first(where: { $0.name == subjectName }) {
                            Label {
                                Text(subjectName)
                                    .font(.jost(.caption()))
                            } icon: {
                                Circle()
                                    .fill(subject.color)
                                    .frame(width: 12, height: 12)
                            }
                            .disabled(true)
                        }
                    }
                }

                Divider()

                // Clear subjects option
                Button(action: onClearSubjects) {
                    Label("Clear Subject", systemImage: "xmark.circle")
                        .font(.jost(.body()))
                }
            }

            // All available subjects
            Section {
                ForEach(sortedSubjects) { subject in
                    Button(action: {
                        onSelectSubject(subject.name)
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 12, height: 12)

                            Text(subject.name)
                                .font(.jost(.body()))

                            Spacer()

                            // Show checkmark if this is the only current subject
                            if currentSubjects.count == 1 && currentSubjects.contains(subject.name) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(
                                        colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                                    )
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "tag.fill")
                .font(.caption)
                .foregroundColor(.primary)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.1))
                )
        }
        .menuStyle(.borderlessButton)
    }
}
