
import SwiftUI
import PencilKit

// MARK: - Import Type Enum
enum ImportType: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case image = "Image"
    case matcha = "Matcha File"
    case text = "Text"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .matcha: return "leaf.fill"
        case .text: return "text.alignleft"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .pdf: return ["pdf"]
        case .image: return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]
        case .matcha: return ["matcha"]
        case .text: return ["txt"]
        }
    }
}

class ImportManager {
    static let shared = ImportManager()

    private init() {}

    // MARK: - Main Import Handler
    func handleImportedFiles(
        _ urls: [URL],
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?,
        completion: @escaping (Note?) -> Void
    ) {
        var lastImportedNote: Note? = nil

        for url in urls {
            #if canImport(UIKit)
            if url.startAccessingSecurityScopedResource() {
                lastImportedNote = createNoteFromImportedFile(
                    url,
                    storageManager: storageManager,
                    currentFolderID: currentFolderID,
                    selectedSubject: selectedSubject
                )
                url.stopAccessingSecurityScopedResource()
            }
            #else
            lastImportedNote = createNoteFromImportedFile(
                url,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
            #endif
        }

        completion(lastImportedNote)
    }

    // MARK: - Document Import Handler
    func handleDocumentImport(
        url: URL,
        type: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?,
        completion: @escaping (Note?) -> Void
    ) {
        print("ImportManager: Handling document import - URL: \(url), Type: \(type)")

        let note: Note?
        let fileName = url.deletingPathExtension().lastPathComponent

        switch type {
        case "pdf":
            note = createNoteFromPDF(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        case "image":
            note = createNoteFromImage(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        case "matcha":
            note = createNoteFromMatchaFile(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        default:
            print("ImportManager: Unknown document type: \(type)")
            note = nil
        }

        completion(note)
    }

    // MARK: - Create Note from Imported File
    private func createNoteFromImportedFile(
        _ url: URL,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?
    ) -> Note? {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent

        // Check if it's a PDF, image, or matcha file
        if fileExtension == "pdf" {
            return createNoteFromPDF(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"].contains(fileExtension) {
            return createNoteFromImage(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        } else if fileExtension == "matcha" {
            return createNoteFromMatchaFile(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: currentFolderID,
                selectedSubject: selectedSubject
            )
        } else {
            // Ignore unsupported file types for uploads
            print("Unsupported upload file type: \(fileExtension)")
            return nil
        }
    }

    // MARK: - Create Note from PDF
    func createNoteFromPDF(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?
    ) -> Note? {
        guard let pdf = CGPDFDocument(url as CFURL) else {
            print("Error: Could not load PDF from \(url)")
            return nil
        }

        let pageCount = pdf.numberOfPages
        var imageDataByPage: [String: [Data]] = [:]

        // Extract each page as an image at native page size
        for pageIndex in 1...pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: pageRect.size))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page)
                context.cgContext.restoreGState()
            }

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                imageDataByPage[String(pageIndex - 1)] = [imageData]
            }
        }

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "PDF")

        let newNote = Note(
            title: noteTitle,
            subject: selectedSubject ?? "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return saveAndOpenNote(
            newNote,
            storageManager: storageManager,
            currentFolderID: currentFolderID
        )
    }

    // MARK: - Create Note from Image
    func createNoteFromImage(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?
    ) -> Note? {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Could not load image data from \(url)")
            return nil
        }

        // Create a note with the image as background on the first page
        let imageDataByPage: [String: [Data]] = ["0": [imageData]]

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "Image")

        let newNote = Note(
            title: noteTitle,
            subject: selectedSubject ?? "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return saveAndOpenNote(
            newNote,
            storageManager: storageManager,
            currentFolderID: currentFolderID
        )
    }

    // MARK: - Create Note from Matcha File
    func createNoteFromMatchaFile(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?
    ) -> Note? {
        do {
            // Read the Matcha note data
            let matchaData = try Data(contentsOf: url)

            // Decode the note from JSON with proper date decoding strategy
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedNote = try decoder.decode(Note.self, from: matchaData)

            // Create a new note with the imported data but with a new ID and current timestamp
            // Use the imported subject if it exists, otherwise use the current subject context
            let noteSubject = importedNote.subject.isEmpty ? (selectedSubject ?? "") : importedNote.subject

            let newNote = Note(
                title: importedNote.title,
                subject: noteSubject,
                color: importedNote.color,
                dateCreated: Date(),
                dateModified: Date(),
                lastOpenedAt: nil,
                isFavorite: false,
                content: importedNote.content,
                noteType: importedNote.noteType,
                paperColor: importedNote.paperColor,
                paperStyle: importedNote.paperStyle,
                paperSize: importedNote.paperSize,
                drawingDataByPage: importedNote.drawingDataByPage,
                imageDataByPage: importedNote.imageDataByPage,
                textBoxDataByPage: importedNote.textBoxDataByPage,
                bookmarkedPages: importedNote.bookmarkedPages
            )

            let savedNote = saveAndOpenNote(
                newNote,
                storageManager: storageManager,
                currentFolderID: currentFolderID
            )
            print("Success: Imported Matcha note '\(newNote.title)' from \(url.lastPathComponent)")
            return savedNote
        } catch {
            print("Error: Could not load Matcha note from \(url): \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Create Text Note from File
    func createTextNoteFromFile(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?
    ) -> Note? {
        let newNote = Note(
            title: fileName,
            subject: selectedSubject ?? "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            content: "Imported from \(fileName)",
            noteType: .written
        )

        return saveAndOpenNote(
            newNote,
            storageManager: storageManager,
            currentFolderID: currentFolderID
        )
    }

    // MARK: - Helper Functions
    private func createNoteTitle(from fileName: String, type: String) -> String {
        // Clean up the filename and create a better title
        let cleanName = fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized

        // If the name is too long, truncate it
        if cleanName.count > 30 {
            let truncated = String(cleanName.prefix(27))
            return "\(truncated)..."
        }

        return cleanName.isEmpty ? "Imported \(type)" : cleanName
    }

    private func saveAndOpenNote(
        _ newNote: Note,
        storageManager: StorageManager,
        currentFolderID: UUID?
    ) -> Note {
        // Add to current folder if we're in one
        if let currentFolderID = currentFolderID,
           let folderIndex = storageManager.folders.firstIndex(where: { $0.id == currentFolderID }) {
            var updatedFolder = storageManager.folders[folderIndex]
            updatedFolder.addNote(noteID: newNote.id)
            _ = storageManager.saveFolder(updatedFolder)
        }

        let savedNote = storageManager.saveNote(newNote)

        // Open the imported note in TabManager
        TabManager.shared.openTab(note: savedNote)

        return savedNote
    }
    
    // MARK: - Save Note Without Opening Tab (for importing into current note)
    private func saveNoteWithoutOpening(
        _ newNote: Note,
        storageManager: StorageManager,
        currentFolderID: UUID?
    ) -> Note {
        // Add to current folder if we're in one
        if let currentFolderID = currentFolderID,
           let folderIndex = storageManager.folders.firstIndex(where: { $0.id == currentFolderID }) {
            var updatedFolder = storageManager.folders[folderIndex]
            updatedFolder.addNote(noteID: newNote.id)
            _ = storageManager.saveFolder(updatedFolder)
        }

        let savedNote = storageManager.saveNote(newNote)
        // Note: We don't open a new tab here since we're importing into current note

        return savedNote
    }
    
    // MARK: - Create Note for Import Into Current Note
    func createNoteForImportIntoCurrent(
        url: URL,
        storageManager: StorageManager,
        completion: @escaping (Note?) -> Void
    ) {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent
        
        let note: Note?
        
        switch fileExtension {
        case "pdf":
            note = createNoteFromPDFForImportWithoutSaving(
                url: url,
                fileName: fileName
            )
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            note = createNoteFromImageForImportWithoutSaving(
                url: url,
                fileName: fileName
            )
        case "matcha":
            note = createNoteFromMatchaFileForImportWithoutSaving(
                url: url,
                fileName: fileName
            )
        default:
            print("ImportManager: Unsupported file type for import into current note: \(fileExtension)")
            note = nil
        }
        
        completion(note)
    }
    
    // MARK: - Create Note from PDF for Import Into Current
    private func createNoteFromPDFForImport(
        url: URL,
        fileName: String,
        storageManager: StorageManager
    ) -> Note? {
        guard let pdf = CGPDFDocument(url as CFURL) else {
            print("Error: Could not load PDF from \(url)")
            return nil
        }

        let pageCount = pdf.numberOfPages
        var imageDataByPage: [String: [Data]] = [:]

        // Extract each page as an image at native page size
        for pageIndex in 1...pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: pageRect.size))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page)
                context.cgContext.restoreGState()
            }

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                imageDataByPage[String(pageIndex - 1)] = [imageData]
            }
        }

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "PDF")

        let newNote = Note(
            title: noteTitle,
            subject: "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return saveNoteWithoutOpening(
            newNote,
            storageManager: storageManager,
            currentFolderID: nil
        )
    }
    
    // MARK: - Create Note from Image for Import Into Current
    private func createNoteFromImageForImport(
        url: URL,
        fileName: String,
        storageManager: StorageManager
    ) -> Note? {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Could not load image data from \(url)")
            return nil
        }

        // Create a note with the image as background on the first page
        let imageDataByPage: [String: [Data]] = ["0": [imageData]]

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "Image")

        let newNote = Note(
            title: noteTitle,
            subject: "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return saveNoteWithoutOpening(
            newNote,
            storageManager: storageManager,
            currentFolderID: nil
        )
    }
    
    // MARK: - Create Note from Matcha File for Import Into Current
    private func createNoteFromMatchaFileForImport(
        url: URL,
        fileName: String,
        storageManager: StorageManager
    ) -> Note? {
        do {
            // Read the Matcha note data
            let matchaData = try Data(contentsOf: url)

            // Decode the note from JSON with proper date decoding strategy
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedNote = try decoder.decode(Note.self, from: matchaData)

            // Create a new note with the imported data but with a new ID and current timestamp
            let newNote = Note(
                title: importedNote.title,
                subject: importedNote.subject,
                color: importedNote.color,
                dateCreated: Date(),
                dateModified: Date(),
                lastOpenedAt: nil,
                isFavorite: false,
                content: importedNote.content,
                noteType: importedNote.noteType,
                paperColor: importedNote.paperColor,
                paperStyle: importedNote.paperStyle,
                paperSize: importedNote.paperSize,
                drawingDataByPage: importedNote.drawingDataByPage,
                imageDataByPage: importedNote.imageDataByPage,
                textBoxDataByPage: importedNote.textBoxDataByPage,
                bookmarkedPages: importedNote.bookmarkedPages
            )

            let savedNote = saveNoteWithoutOpening(
                newNote,
                storageManager: storageManager,
                currentFolderID: nil
            )
            print("Success: Created Matcha note for import '\(newNote.title)' from \(url.lastPathComponent)")
            return savedNote
        } catch {
            print("Error: Could not load Matcha note from \(url): \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Create Note Without Saving (for importing into current note)
    private func createNoteFromPDFForImportWithoutSaving(
        url: URL,
        fileName: String
    ) -> Note? {
        guard let pdf = CGPDFDocument(url as CFURL) else {
            print("Error: Could not load PDF from \(url)")
            return nil
        }

        let pageCount = pdf.numberOfPages
        var imageDataByPage: [String: [Data]] = [:]

        // Extract each page as an image at native page size
        for pageIndex in 1...pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: pageRect.size))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page)
                context.cgContext.restoreGState()
            }

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                imageDataByPage[String(pageIndex - 1)] = [imageData]
            }
        }

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "PDF")

        let newNote = Note(
            title: noteTitle,
            subject: "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return newNote // Return without saving
    }
    
    private func createNoteFromImageForImportWithoutSaving(
        url: URL,
        fileName: String
    ) -> Note? {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Could not load image data from \(url)")
            return nil
        }

        // Create a note with the image as background on the first page
        let imageDataByPage: [String: [Data]] = ["0": [imageData]]

        // Create a better title from the filename
        let noteTitle = createNoteTitle(from: fileName, type: "Image")

        let newNote = Note(
            title: noteTitle,
            subject: "",
            color: .matchalight_light,
            dateCreated: Date(),
            dateModified: Date(),
            noteType: .written,
            paperColor: .white,
            paperStyle: .blank,
            paperSize: .a4,
            imageDataByPage: imageDataByPage
        )

        return newNote // Return without saving
    }
    
    private func createNoteFromMatchaFileForImportWithoutSaving(
        url: URL,
        fileName: String
    ) -> Note? {
        do {
            // Read the Matcha note data
            let matchaData = try Data(contentsOf: url)

            // Decode the note from JSON with proper date decoding strategy
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedNote = try decoder.decode(Note.self, from: matchaData)

            // Create a new note with the imported data but with a new ID and current timestamp
            let newNote = Note(
                title: importedNote.title,
                subject: importedNote.subject,
                color: importedNote.color,
                dateCreated: Date(),
                dateModified: Date(),
                lastOpenedAt: nil,
                isFavorite: false,
                content: importedNote.content,
                noteType: importedNote.noteType,
                paperColor: importedNote.paperColor,
                paperStyle: importedNote.paperStyle,
                paperSize: importedNote.paperSize,
                drawingDataByPage: importedNote.drawingDataByPage,
                imageDataByPage: importedNote.imageDataByPage,
                textBoxDataByPage: importedNote.textBoxDataByPage,
                bookmarkedPages: importedNote.bookmarkedPages
            )

            // Debug logging for matcha import
            print("Matcha Import Debug - Drawing pages: \(importedNote.drawingDataByPage.keys)")
            print("Matcha Import Debug - Image pages: \(importedNote.imageDataByPage.keys)")
            print("Matcha Import Debug - TextBox pages: \(importedNote.textBoxDataByPage.keys)")
            print("Matcha Import Debug - New note drawing pages: \(newNote.drawingDataByPage.keys)")
            print("Success: Created Matcha note for import '\(newNote.title)' from \(url.lastPathComponent)")
            return newNote // Return without saving
        } catch {
            print("Error: Could not load Matcha note from \(url): \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
}
