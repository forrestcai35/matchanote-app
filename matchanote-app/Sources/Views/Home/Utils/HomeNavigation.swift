import SwiftUI

// Extension to handle folder navigation for HomeView
extension HomeView {
    // Helper function to navigate into a folder
    func navigateToFolder(_ folder: Folder) {
        currentFolderID = folder.id

        // Update the folder path
        if let index = folderPath.firstIndex(where: { $0.id == folder.id }) {
            // This folder is already in our path, truncate to this point
            folderPath = Array(folderPath.prefix(through: index))
        } else {
            // Add this folder to our path
            folderPath.append(folder)
        }
    }

    // Helper function to navigate to a folder from favorites
    func navigateToFolderFromFavorites(_ folder: Folder) {
        // Switch to documents view
        selectedItem = "documents"

        // Build the folder path from the folder up to the root
        var path: [Folder] = []
        var currentFolder: Folder? = folder

        // Traverse up to build the path
        while let folder = currentFolder {
            path.insert(folder, at: 0)

            // Find parent folder if it exists
            if let parentID = folder.parentID {
                currentFolder = storageManager.folders.first(where: { $0.id == parentID })
            } else {
                currentFolder = nil
            }
        }

        // Set the current folder and path
        folderPath = path
        currentFolderID = folder.id
    }

    // Helper function to navigate to a folder from subject view
    func navigateToFolderFromSubject(_ folder: Folder) {
        // Switch to documents view
        selectedItem = "documents"
        selectedSubject = nil

        // Build the folder path from the folder up to the root
        var path: [Folder] = []
        var currentFolder: Folder? = folder

        // Traverse up to build the path
        while let folder = currentFolder {
            path.insert(folder, at: 0)

            // Find parent folder if it exists
            if let parentID = folder.parentID {
                currentFolder = storageManager.folders.first(where: { $0.id == parentID })
            } else {
                currentFolder = nil
            }
        }

        // Set the current folder and path
        folderPath = path
        currentFolderID = folder.id
    }
}
