

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PendingImport: Identifiable, Equatable {
    let id = UUID()
    let fileData: Data
    let type: String
    let fileName: String
    let currentFolderID: UUID?
    let selectedSubject: String?

    static func == (lhs: PendingImport, rhs: PendingImport) -> Bool {
        lhs.id == rhs.id
    }
}

class DocumentHandler: ObservableObject {
    static let shared = DocumentHandler()

    @Published var pendingImport: PendingImport?
    @Published var importedNote: Note?

    // Store current folder context for imports
    var currentFolderID: UUID?
    var selectedSubject: String?

    private init() {}

    func handleDocumentURL(_ url: URL) {
        print("DocumentHandler: Received document URL: \(url)")

        // Read file data immediately while we have access (before sandboxing blocks us)
        guard let fileData = try? Data(contentsOf: url) else {
            print("DocumentHandler: Could not read file data")
            return
        }

        print("DocumentHandler: Successfully read \(fileData.count) bytes")
        handleDocumentData(fileData, fileName: url.lastPathComponent)
    }

    func handleDocumentData(_ fileData: Data, fileName: String) {
        print("DocumentHandler: Received document data: \(fileName) (\(fileData.count) bytes)")

        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let type: String

        switch fileExtension {
        case "pdf":
            type = "pdf"
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff":
            type = "image"
        case "matcha":
            type = "matcha"
        default:
            print("DocumentHandler: Unsupported file type: \(fileExtension)")
            return
        }

        // Show preview with current folder context
        DispatchQueue.main.async {
            self.pendingImport = PendingImport(
                fileData: fileData,
                type: type,
                fileName: fileName,
                currentFolderID: self.currentFolderID,
                selectedSubject: self.selectedSubject
            )
        }
    }

    func clearPendingImport() {
        pendingImport = nil
    }
}
