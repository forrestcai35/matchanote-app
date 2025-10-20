

import SwiftUI
import PencilKit

// MARK: - Export Type Enum
enum ExportType: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case matcha = "Matcha File"
    case image = "Image (PNG)"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .matcha: return "leaf.fill"
        case .image: return "photo.fill"
        }
    }
}

class ExportManager {
    static let shared = ExportManager()
    
    private var isPresenting = false
    private var lastExportTime: Date = Date.distantPast
    
    private init() {}
    
    // MARK: - Title Sanitization Helper
    static func sanitizeTitle(_ title: String) -> String {
        return title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
    }
    
    // MARK: - Main Export Function with Type Selection
    func exportNote(_ note: Note, selectedPages: [Int]? = nil, exportType: ExportType = .pdf) -> URL? {
        switch exportType {
        case .pdf:
            return exportNoteAsPDF(note, selectedPages: selectedPages)
        case .matcha:
            return exportNoteAsMatcha(note, selectedPages: selectedPages)
        case .image:
            return exportNoteAsImage(note, selectedPages: selectedPages)
        }
    }
    
    // MARK: - Export as Matcha File
    func exportNoteAsMatcha(_ note: Note, selectedPages: [Int]? = nil) -> URL? {
        do {
            // Create a note with selected pages if specified
            let noteToExport = selectedPages != nil ? createNoteWithSelectedPages(note, selectedPages: selectedPages!) : note
            
            // Encode the note as JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let noteData = try encoder.encode(noteToExport)
            
            // Create a temporary file with .matcha extension
            let sanitizedTitle = ExportManager.sanitizeTitle(noteToExport.title)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).matcha")
            
            try noteData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to export Matcha note: \(error)")
            return nil
        }
    }
    
    // MARK: - Export as Image (PNG)
    func exportNoteAsImage(_ note: Note, selectedPages: [Int]? = nil) -> URL? {
        // If no specific pages selected, export all pages
        let pagesToExport = selectedPages ?? getAllPagesForNote(note)
        
        // Create a temporary note with only the selected pages if needed
        let noteToExport = selectedPages != nil ? createNoteWithSelectedPages(note, selectedPages: selectedPages!) : note
        
        let sanitizedTitle = ExportManager.sanitizeTitle(noteToExport.title)
        
        // If exporting a single page, create a single PNG
        if pagesToExport.count == 1 {
            let page = pagesToExport[0]
            let pageKey = String(page)
            var size = PaperUtilities.paperSize(for: noteToExport.paperSize)
            if let imageData = noteToExport.imageDataByPage[pageKey]?.first, let uiImage = UIImage(data: imageData) {
                size = uiImage.size
            }
            
            let bounds = CGRect(origin: .zero, size: size)
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            
            let image = renderer.image { context in
                // Fill background
                UIColor(PaperUtilities.getPaperBackgroundColor(for: noteToExport.paperColor)).setFill()
                UIRectFill(bounds)
                
                // Draw background images
                var overlayCanvasImages: [CanvasImage] = []
                if let imageDataArray = noteToExport.imageDataByPage[pageKey] {
                    for data in imageDataArray {
                        if let bg = UIImage(data: data) {
                            bg.draw(in: bounds)
                        } else if let canvasImage = try? JSONDecoder().decode(CanvasImage.self, from: data) {
                            overlayCanvasImages.append(canvasImage)
                        }
                    }
                }
                
                // Draw paper pattern
                PaperUtilities.drawPaperPattern(context: context.cgContext, paperStyle: noteToExport.paperStyle, size: bounds.size)
                
                // Draw strokes
                if let drawing = drawingForPage(page, note: noteToExport) {
                    let drawingImage = drawing.image(from: bounds, scale: 2)
                    drawingImage.draw(in: bounds)
                }
                
                // Draw overlay canvas images
                if !overlayCanvasImages.isEmpty {
                    let sorted = overlayCanvasImages.sorted { $0.zIndex < $1.zIndex }
                    for item in sorted {
                        if let uiImage = ImageUtilities.dataToImage(item.imageData) {
                            let rect = CGRect(origin: item.position, size: item.size)
                            uiImage.draw(in: rect)
                        }
                    }
                }
            }
            
            // Save as PNG
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle)_page_\(page + 1).png")
            if let pngData = image.pngData() {
                do {
                    try pngData.write(to: tempURL)
                    return tempURL
                } catch {
                    print("Failed to write PNG: \(error)")
                    return nil
                }
            }
        } else {
            // Export multiple pages as separate PNGs in a zip file
            // For now, we'll export the first page as the representative image
            // You could enhance this to create a zip file or combine pages
            if let firstPage = pagesToExport.first {
                return exportNoteAsImage(noteToExport, selectedPages: [firstPage])
            }
        }
        
        return nil
    }
    
    // MARK: - Export as PDF function    
    func exportNoteAsPDF(_ note: Note, selectedPages: [Int]? = nil) -> URL? {
        // If no specific pages selected, export all pages
        let pagesToExport = selectedPages ?? getAllPagesForNote(note)
        
        // Create a temporary note with only the selected pages if needed
        let noteToExport = selectedPages != nil ? createNoteWithSelectedPages(note, selectedPages: selectedPages!) : note
        
        // Use the same export logic for all exports
        let pageBounds = CGRect(origin: .zero, size: PaperUtilities.paperSize(for: noteToExport.paperSize))
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let sanitizedTitle = ExportManager.sanitizeTitle(noteToExport.title)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                for page in pagesToExport {
                    // Determine per-page size using background image when available
                    let pageKey = String(page)
                    var size = PaperUtilities.paperSize(for: noteToExport.paperSize)
                    if let imageData = noteToExport.imageDataByPage[pageKey]?.first, let uiImage = UIImage(data: imageData) {
                        size = uiImage.size
                    }

                    let bounds = CGRect(origin: .zero, size: size)
                    context.beginPage(withBounds: bounds, pageInfo: [:])

                    // Fill background
                    UIColor(PaperUtilities.getPaperBackgroundColor(for: noteToExport.paperColor)).setFill()
                    UIRectFill(bounds)

                    // Separate raw background images and encoded CanvasImage overlays
                    var overlayCanvasImages: [CanvasImage] = []
                    if let imageDataArray = noteToExport.imageDataByPage[pageKey] {
                        for data in imageDataArray {
                            if let bg = UIImage(data: data) {
                                // Raw background image – draw full-bleed
                                bg.draw(in: bounds)
                            } else if let canvasImage = try? JSONDecoder().decode(CanvasImage.self, from: data) {
                                overlayCanvasImages.append(canvasImage)
                            }
                        }
                    }

                    // Draw paper pattern on top of background images
                    PaperUtilities.drawPaperPattern(context: context.cgContext, paperStyle: noteToExport.paperStyle, size: bounds.size)

                    // Draw strokes next (under overlays to match UI layering)
                    if let drawing = drawingForPage(page, note: noteToExport) {
                        let image = drawing.image(from: bounds, scale: 2)
                        image.draw(in: bounds)
                    }

                    // Draw overlay canvas images (positioned and z-ordered)
                    if !overlayCanvasImages.isEmpty {
                        // Sort by zIndex ascending so higher zIndex draws later (on top)
                        let sorted = overlayCanvasImages.sorted { $0.zIndex < $1.zIndex }
                        for item in sorted {
                            if let uiImage = ImageUtilities.dataToImage(item.imageData) {
                                let rect = CGRect(origin: item.position, size: item.size)
                                uiImage.draw(in: rect)
                            }
                        }
                    }
                }
            }
            return tempURL
        } catch {
            print("Failed to write PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Export with Save
    func saveAndExportNote(_ note: Note, storageManager: StorageManager, selectedPages: [Int]? = nil, completion: @escaping (URL?) -> Void) {
        // Save note synchronously to ensure latest data is persisted
        storageManager.saveNoteSync(note) { savedNote in
            // Export the saved note
            let url = self.exportNoteAsPDF(savedNote, selectedPages: selectedPages)
            completion(url)
        }
    }
    
    // MARK: - Present Export Share Sheet with Type
    func presentExportShareSheet(for note: Note, selectedPages: [Int]? = nil, exportType: ExportType = .pdf) {
        // Prevent multiple simultaneous presentations
        guard !isPresenting else {
            print("Export already in progress, skipping...")
            return
        }
        
        // Prevent rapid-fire export attempts (minimum 1 second between exports)
        let timeSinceLastExport = Date().timeIntervalSince(lastExportTime)
        guard timeSinceLastExport >= 1.0 else {
            print("Export too soon after last export, skipping...")
            return
        }
        
        guard let url = exportNote(note, selectedPages: selectedPages, exportType: exportType) else { return }
        
        isPresenting = true
        lastExportTime = Date()
        
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Configure popover for iPad
        if let popover = controller.popoverPresentationController {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the share sheet with completion handler
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            topController.present(controller, animated: true) { [weak self] in
                self?.isPresenting = false
            }
        } else {
            isPresenting = false
        }
    }
    
    // MARK: - Present Export Share Sheet (Legacy PDF-only version)
    func presentExportShareSheet(for note: Note, selectedPages: [Int]? = nil) {
        // Prevent multiple simultaneous presentations
        guard !isPresenting else {
            print("Export already in progress, skipping...")
            return
        }
        
        // Prevent rapid-fire export attempts (minimum 1 second between exports)
        let timeSinceLastExport = Date().timeIntervalSince(lastExportTime)
        guard timeSinceLastExport >= 1.0 else {
            print("Export too soon after last export, skipping...")
            return
        }
        
        guard let url = exportNoteAsPDF(note, selectedPages: selectedPages) else { return }
        
        isPresenting = true
        lastExportTime = Date()
        
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Configure popover for iPad
        if let popover = controller.popoverPresentationController {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the share sheet with completion handler
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            topController.present(controller, animated: true) { [weak self] in
                self?.isPresenting = false
            }
        } else {
            isPresenting = false
        }
    }
    
    // MARK: - Reset Presentation State
    func resetPresentationState() {
        isPresenting = false
    }
    
    // MARK: - Helper Functions
    private func getAllPagesForNote(_ note: Note) -> [Int] {
        // Get all pages that have content (drawings or images)
        let maxDrawingPage = note.drawingDataByPage.keys.compactMap { Int($0) }.max() ?? -1
        let maxImagePage = note.imageDataByPage.keys.compactMap { Int($0) }.max() ?? -1
        let maxPage = max(maxDrawingPage, maxImagePage)
        
        // Return at least page 0, or all pages up to the maximum
        return Array(0...max(0, maxPage))
    }
    
    private func createNoteWithSelectedPages(_ note: Note, selectedPages: [Int]) -> Note {
        var tempNote = note
        var newDrawingData: [String: Data] = [:]
        var newImageData: [String: [Data]] = [:]
        var newTextBoxData: [String: [Data]] = [:]
        
        // Copy only selected pages
        for (newIndex, originalIndex) in selectedPages.enumerated() {
            if let drawingData = note.drawingDataByPage[String(originalIndex)] {
                newDrawingData[String(newIndex)] = drawingData
            }
            if let imageData = note.imageDataByPage[String(originalIndex)] {
                newImageData[String(newIndex)] = imageData
            }
            if let textBoxData = note.textBoxDataByPage[String(originalIndex)] {
                newTextBoxData[String(newIndex)] = textBoxData
            }
        }
        
        tempNote.drawingDataByPage = newDrawingData
        tempNote.imageDataByPage = newImageData
        tempNote.textBoxDataByPage = newTextBoxData
        tempNote.bookmarkedPages = Set(0..<selectedPages.count)
        
        return tempNote
    }
    
    private func drawingForPage(_ index: Int, note: Note) -> PKDrawing? {
        // Get drawing data for a specific page from the note
        if let data = note.drawingDataByPage[String(index)], let drawing = try? PKDrawing(data: data) {
            return drawing
        }
        return nil
    }
    
        
  
    
}
