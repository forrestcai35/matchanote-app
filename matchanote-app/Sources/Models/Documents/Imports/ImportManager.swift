
import SwiftUI
import PencilKit
import UIKit

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
    
    // MARK: - Save Option Enum
    private enum SaveOption {
        case saveAndOpen
        case saveOnly
        case doNotSave
    }

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
    private func createNoteFromPDF(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?,
        saveOption: SaveOption = .saveAndOpen
    ) -> Note? {
        // Store original PDF as attachment and reference pages as vector backgrounds
        guard let pdfData = try? Data(contentsOf: url) else {
            print("Error: Could not read PDF data from \(url)")
            return nil
        }

        var imageDataByPage: [String: [Data]] = [:]
        do {
            let relativePath = try AttachmentManager.save(data: pdfData, preferredFileName: fileName, fileExtension: "pdf")
            guard let pdf = CGPDFDocument(AttachmentManager.fileURL(for: relativePath) as CFURL) else {
                print("Error: Could not load saved PDF document")
                return nil
            }
            let pageCount = pdf.numberOfPages
            for pageIndex in 1...pageCount {
                guard let page = pdf.page(at: pageIndex) else { continue }
                let pageRect = page.getBoxRect(.mediaBox)
                let bg = PDFPageBackground(
                    relativePath: relativePath,
                    pageIndex: pageIndex,
                    width: pageRect.size.width,
                    height: pageRect.size.height
                )
                if let data = try? JSONEncoder().encode(bg) {
                    imageDataByPage[String(pageIndex - 1)] = [data]
                }
            }
        } catch {
            print("Error saving PDF attachment: \(error)")
            return nil
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

        switch saveOption {
        case .saveAndOpen:
            return saveAndOpenNote(
                newNote,
                storageManager: storageManager,
                currentFolderID: currentFolderID
            )
        case .saveOnly:
            return saveNoteWithoutOpening(
                newNote,
                storageManager: storageManager,
                currentFolderID: currentFolderID
            )
        case .doNotSave:
            return newNote
        }
    }

    // MARK: - Create Note from Image
    private func createNoteFromImage(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?,
        saveOption: SaveOption = .saveAndOpen
    ) -> Note? {
        guard let imageData = try? Data(contentsOf: url) else {
            print("Error: Could not load image data from \(url)")
            return nil
        }

        guard let image = UIImage(data: imageData) else {
            print("Error: Could not create UIImage from data")
            return nil
        }

        // Get original image dimensions
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height

        // Determine best paper size and orientation based on image dimensions
        // This is used as a fallback, but the actual canvas size will be determined by the image itself
        let (paperSize, orientation) = determinePaperSizeForImage(imageSize: imageSize, aspectRatio: imageAspectRatio)

        // Store the original image data without normalization
        // The canvas will automatically use the image's actual dimensions (see perPageSize in PaperStyles.swift)
        let imageDataByPage: [String: [Data]]
        if saveOption == .saveAndOpen {
            // Keep original image at its native size - canvas will match exactly
            imageDataByPage = ["0": [imageData]]
        } else {
            // When importing into current note, keep original data
            // The merging logic will handle normalization to the target note's paper size
            imageDataByPage = ["0": [imageData]]
        }

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
            paperSize: paperSize,
            paperOrientation: orientation,
            imageDataByPage: imageDataByPage
        )

        switch saveOption {
        case .saveAndOpen:
            return saveAndOpenNote(
                newNote,
                storageManager: storageManager,
                currentFolderID: currentFolderID
            )
        case .saveOnly:
            return saveNoteWithoutOpening(
                newNote,
                storageManager: storageManager,
                currentFolderID: currentFolderID
            )
        case .doNotSave:
            return newNote
        }
    }

    // MARK: - Create Note from Matcha File
    private func createNoteFromMatchaFile(
        url: URL,
        fileName: String,
        storageManager: StorageManager,
        currentFolderID: UUID?,
        selectedSubject: String?,
        saveOption: SaveOption = .saveAndOpen
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
            let noteSubject: String
            if saveOption == .doNotSave {
                // When importing into current note, use imported subject as-is
                noteSubject = importedNote.subject
            } else {
                // Use the imported subject if it exists, otherwise use the current subject context
                noteSubject = importedNote.subject.isEmpty ? (selectedSubject ?? "") : importedNote.subject
            }

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

            let result: Note?
            switch saveOption {
            case .saveAndOpen:
                result = saveAndOpenNote(
                    newNote,
                    storageManager: storageManager,
                    currentFolderID: currentFolderID
                )
                print("Success: Imported Matcha note '\(newNote.title)' from \(url.lastPathComponent)")
            case .saveOnly:
                result = saveNoteWithoutOpening(
                    newNote,
                    storageManager: storageManager,
                    currentFolderID: currentFolderID
                )
                print("Success: Created Matcha note for import '\(newNote.title)' from \(url.lastPathComponent)")
            case .doNotSave:
                // Debug logging for matcha import
                print("Matcha Import Debug - Drawing pages: \(importedNote.drawingDataByPage.keys)")
                print("Matcha Import Debug - Image pages: \(importedNote.imageDataByPage.keys)")
                print("Matcha Import Debug - TextBox pages: \(importedNote.textBoxDataByPage.keys)")
                print("Matcha Import Debug - New note drawing pages: \(newNote.drawingDataByPage.keys)")
                print("Success: Created Matcha note for import '\(newNote.title)' from \(url.lastPathComponent)")
                result = newNote
            }
            return result
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
    private func determinePaperSizeForImage(imageSize: CGSize, aspectRatio: CGFloat) -> (PaperSize, PaperOrientation) {
        // Determine orientation based on aspect ratio
        let orientation: PaperOrientation = aspectRatio >= 1.0 ? .landscape : .portrait

        // Choose paper size based on image aspect ratio
        // We'll compare against standard paper sizes and choose the best fit
        let paperSizes: [PaperSize] = [.letter, .a4, .legal, .tabloid]
        var bestSize: PaperSize = .a4
        var bestDifference: CGFloat = .infinity

        for size in paperSizes {
            let paperWidth = PaperUtilities.getPaperWidth(for: size, orientation: orientation)
            let paperHeight = PaperUtilities.getPaperHeight(for: size, orientation: orientation)
            let paperAspectRatio = paperWidth / paperHeight

            // Calculate how well this paper size matches the image aspect ratio
            let aspectDifference = abs(paperAspectRatio - aspectRatio)

            if aspectDifference < bestDifference {
                bestDifference = aspectDifference
                bestSize = size
            }
        }

        return (bestSize, orientation)
    }

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
            note = createNoteFromPDF(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: nil,
                selectedSubject: nil,
                saveOption: .doNotSave
            )
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            note = createNoteFromImage(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: nil,
                selectedSubject: nil,
                saveOption: .doNotSave
            )
        case "matcha":
            note = createNoteFromMatchaFile(
                url: url,
                fileName: fileName,
                storageManager: storageManager,
                currentFolderID: nil,
                selectedSubject: nil,
                saveOption: .doNotSave
            )
        default:
            print("ImportManager: Unsupported file type for import into current note: \(fileExtension)")
            note = nil
        }
        
        completion(note)
    }
    
}

// MARK: - Image Normalization Utilities
extension ImportManager {
    /// Resample and letterbox an image Data to a given target size at 1.0 scale.
    /// - Parameters:
    ///   - data: Original image data
    ///   - targetSize: Target canvas size in points (72 dpi base)
    /// - Returns: JPEG data of the normalized image, or nil on failure
    static func normalizeImageDataToSize(_ data: Data, targetSize: CGSize) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            // Aspect-fit the image within the target size
            let sourceSize = image.size
            guard sourceSize.width > 0 && sourceSize.height > 0 else { return }
            let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.jpegData(compressionQuality: 0.9)
    }

    // Vector PDF generation helper removed per request.
}
