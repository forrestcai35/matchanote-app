//
//  Trash.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 9/23/25.
//

import SwiftUI
import Foundation

public enum TrashItemType: String, Codable, CaseIterable {
    case note
    case folder
}

public struct TrashItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var type: TrashItemType
    public var itemId: UUID
    public var title: String
    public var deletedAt: Date
    public var originalData: Data

    public init(type: TrashItemType, itemId: UUID, title: String, deletedAt: Date, originalData: Data) {
        self.type = type
        self.itemId = itemId
        self.title = title
        self.deletedAt = deletedAt
        self.originalData = originalData
    }

    // Helper computed property to get days since deletion
    public var daysSinceDeletion: Int {
        Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
    }

    // Check if item should be auto-deleted (after 30 days)
    public var shouldAutoDelete: Bool {
        daysSinceDeletion >= 30
    }
}

class TrashManager: ObservableObject {
    @Published var trashItems: [TrashItem] = []

    private let localStorageURL: URL
    private let trashFileName = "trash.json"

    static let shared = TrashManager()

    private init() {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could not access document directory")
        }
        self.localStorageURL = documentDirectory
        loadTrashItems()

        // Clean up old items on initialization
        cleanupOldItems()
    }

    // MARK: - Public Methods

    func moveNoteToTrash(_ note: Note) {
        do {
            let encoder = JSONEncoder()
            let noteData = try encoder.encode(StorageNote(from: note))

            let trashItem = TrashItem(
                type: .note,
                itemId: note.id,
                title: note.title,
                deletedAt: Date(),
                originalData: noteData
            )

            trashItems.append(trashItem)
            saveTrashItems()
        } catch {
            print("Error moving note to trash: \(error)")
        }
    }

    func moveFolderToTrash(_ folder: Folder) {
        do {
            let encoder = JSONEncoder()
            let folderData = try encoder.encode(StorageFolder(from: folder))

            let trashItem = TrashItem(
                type: .folder,
                itemId: folder.id,
                title: folder.name,
                deletedAt: Date(),
                originalData: folderData
            )

            trashItems.append(trashItem)
            saveTrashItems()
        } catch {
            print("Error moving folder to trash: \(error)")
        }
    }
    
    // MARK: - Optimized Bulk Operations
    
    /// Move multiple notes to trash efficiently in a single batch
    func moveNotesToTrashBulk(_ notes: [Note]) {
        guard !notes.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let currentDate = Date()
            
            let trashItemsToAdd = try notes.map { note in
                let noteData = try encoder.encode(StorageNote(from: note))
                return TrashItem(
                    type: .note,
                    itemId: note.id,
                    title: note.title,
                    deletedAt: currentDate,
                    originalData: noteData
                )
            }
            
            trashItems.append(contentsOf: trashItemsToAdd)
            saveTrashItems()
        } catch {
            print("Error moving notes to trash in bulk: \(error)")
        }
    }
    
    /// Move multiple folders to trash efficiently in a single batch
    func moveFoldersToTrashBulk(_ folders: [Folder]) {
        guard !folders.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let currentDate = Date()
            
            let trashItemsToAdd = try folders.map { folder in
                let folderData = try encoder.encode(StorageFolder(from: folder))
                return TrashItem(
                    type: .folder,
                    itemId: folder.id,
                    title: folder.name,
                    deletedAt: currentDate,
                    originalData: folderData
                )
            }
            
            trashItems.append(contentsOf: trashItemsToAdd)
            saveTrashItems()
        } catch {
            print("Error moving folders to trash in bulk: \(error)")
        }
    }

    func restoreItem(_ trashItem: TrashItem) -> (note: Note?, folder: Folder?) {
        do {
            let decoder = JSONDecoder()

            switch trashItem.type {
            case .note:
                let storageNote = try decoder.decode(StorageNote.self, from: trashItem.originalData)
                let note = storageNote.toNote()
                removeFromTrash(trashItem)
                return (note, nil)

            case .folder:
                let storageFolder = try decoder.decode(StorageFolder.self, from: trashItem.originalData)
                let folder = storageFolder.toFolder()
                removeFromTrash(trashItem)
                return (nil, folder)
            }
        } catch {
            print("Error restoring item from trash: \(error)")
            return (nil, nil)
        }
    }

    func permanentlyDeleteItem(_ trashItem: TrashItem) {
        removeFromTrash(trashItem)
    }

    func emptyTrash() {
        trashItems.removeAll()
        saveTrashItems()
    }

    func cleanupOldItems() {
        let itemsToRemove = trashItems.filter { $0.shouldAutoDelete }
        trashItems.removeAll { $0.shouldAutoDelete }

        if !itemsToRemove.isEmpty {
            saveTrashItems()
            print("Auto-deleted \(itemsToRemove.count) items older than 30 days")
        }
    }

    // MARK: - Private Methods

    private func removeFromTrash(_ trashItem: TrashItem) {
        trashItems.removeAll { $0.id == trashItem.id }
        saveTrashItems()
    }

    private func loadTrashItems() {
        let trashURL = localStorageURL.appendingPathComponent(trashFileName)

        guard FileManager.default.fileExists(atPath: trashURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: trashURL)
            let decoder = JSONDecoder()
            self.trashItems = try decoder.decode([TrashItem].self, from: data)
        } catch {
            print("Error loading trash items: \(error)")
        }
    }

    private func saveTrashItems() {
        let trashURL = localStorageURL.appendingPathComponent(trashFileName)

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(self.trashItems)
                try data.write(to: trashURL)
            } catch {
                await MainActor.run {
                    print("Error saving trash items: \(error)")
                }
            }
        }
    }
}