

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
    // Returns one or more URLs depending on export type
    func exportNote(_ note: Note, selectedPages: [Int]? = nil, exportType: ExportType = .pdf) -> [URL]? {
        switch exportType {
        case .pdf:
            if let url = exportNoteAsPDF(note, selectedPages: selectedPages) { return [url] }
            return nil
        case .matcha:
            if let url = exportNoteAsMatcha(note, selectedPages: selectedPages) { return [url] }
            return nil
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
    // Creates a PNG per selected page; returns all URLs (or nil on failure)
    func exportNoteAsImage(_ note: Note, selectedPages: [Int]? = nil) -> [URL]? {
        // Determine pages and construct note with only selected pages when applicable
        let noteToExport: Note
        let pagesToExport: [Int]
        if let selected = selectedPages, !selected.isEmpty {
            noteToExport = createNoteWithSelectedPages(note, selectedPages: selected)
            pagesToExport = Array(0..<selected.count)
        } else {
            noteToExport = note
            pagesToExport = getAllPagesForNote(noteToExport)
        }

        let sanitizedTitle = ExportManager.sanitizeTitle(noteToExport.title)
        var urls: [URL] = []

        for page in pagesToExport {
            let pageKey = String(page)
            var size = PaperUtilities.paperSize(for: noteToExport.paperSize, orientation: noteToExport.paperOrientation)
            var pdfBackground: PDFPageBackground?
            if let firstData = noteToExport.imageDataByPage[pageKey]?.first {
                if let bg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
                    pdfBackground = bg
                    size = CGSize(width: bg.width, height: bg.height)
                } else if let uiImage = UIImage(data: firstData) {
                    size = uiImage.size
                }
            }

            let bounds = CGRect(origin: .zero, size: size)
            let renderer = UIGraphicsImageRenderer(bounds: bounds)

            let image = renderer.image { context in
                // Fill background
                UIColor(PaperUtilities.getPaperBackgroundColor(for: noteToExport.paperColor)).setFill()
                UIRectFill(bounds)

                // Separate raw background images and encoded CanvasImage overlays
                var overlayCanvasImages: [CanvasImage] = []
                if let imageDataArray = noteToExport.imageDataByPage[pageKey] {
                    for data in imageDataArray {
                        if let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: data) {
                            let fileURL = AttachmentManager.fileURL(for: pdfBg.relativePath)
                            PDFDrawingUtils.draw(pdf: fileURL, pageIndex: pdfBg.pageIndex, in: context.cgContext, bounds: bounds, backgroundColor: .white)
                        } else if let bg = UIImage(data: data) {
                            bg.draw(in: bounds)
                        } else if let canvasImage = try? JSONDecoder().decode(CanvasImage.self, from: data) {
                            overlayCanvasImages.append(canvasImage)
                        }
                    }
                }

                // Paper pattern
                drawExportPaperPattern(context: context.cgContext,
                                       paperStyle: noteToExport.paperStyle,
                                       paperColor: noteToExport.paperColor,
                                       size: bounds.size)

                // Strokes in light mode
                if let drawing = drawingForPage(page, note: noteToExport) {
                    let lightTrait = UITraitCollection(userInterfaceStyle: .light)
                    var drawingImage: UIImage!
                    lightTrait.performAsCurrent {
                        drawingImage = drawing.image(from: bounds, scale: 3.0)
                    }
                    drawingImage.draw(in: bounds)
                }

                // Overlay canvas images with rotation and z-order
                if !overlayCanvasImages.isEmpty {
                    let sorted = overlayCanvasImages.sorted { $0.zIndex < $1.zIndex }
                    for item in sorted {
                        if let uiImage = ImageUtilities.dataToImage(item.imageData) {
                            context.cgContext.saveGState()

                            if item.rotation != 0 {
                                let centerX = item.position.x + item.size.width / 2
                                let centerY = item.position.y + item.size.height / 2
                                context.cgContext.translateBy(x: centerX, y: centerY)
                                context.cgContext.rotate(by: item.rotation)
                                context.cgContext.translateBy(x: -centerX, y: -centerY)
                            }

                            let rect = CGRect(origin: item.position, size: item.size)
                            uiImage.draw(in: rect)

                            context.cgContext.restoreGState()
                        }
                    }
                }

                // Text boxes
                if let textBoxDataArray = noteToExport.textBoxDataByPage[pageKey] {
                    for data in textBoxDataArray {
                        if let textBox = try? JSONDecoder().decode(TextBox.self, from: data) {
                            let textRect = CGRect(origin: textBox.position, size: textBox.size)
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.alignment = .left

                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: textBox.fontSize),
                                .foregroundColor: UIColor(textBox.textColor),
                                .paragraphStyle: paragraphStyle
                            ]

                            textBox.text.draw(in: textRect, withAttributes: attributes)
                        }
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle)_page_\(page + 1).png")
            if let pngData = image.pngData() {
                do {
                    try pngData.write(to: tempURL)
                    urls.append(tempURL)
                } catch {
                    print("Failed to write PNG for page \(page): \(error)")
                }
            }
        }

        return urls.isEmpty ? nil : urls
    }

    
    // MARK: - Export as PDF function    
    // Now rasterizes each page: draws all content into a high-res image,
    // then embeds that image into the PDF page for consistent appearance.
    func exportNoteAsPDF(_ note: Note, selectedPages: [Int]? = nil) -> URL? {
        // If no specific pages selected, export all pages
        let pagesToExport = selectedPages ?? getAllPagesForNote(note)
        
        // Create a temporary note with only the selected pages if needed
        let noteToExport = selectedPages != nil ? createNoteWithSelectedPages(note, selectedPages: selectedPages!) : note

        // Use the same export logic for all exports - respect orientation
        let pageBounds = CGRect(origin: .zero, size: PaperUtilities.paperSize(for: noteToExport.paperSize, orientation: noteToExport.paperOrientation))
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let sanitizedTitle = ExportManager.sanitizeTitle(noteToExport.title)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedTitle).pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                // Choose a raster scale when rasterizing
                let rasterScale: CGFloat = 2.0

                for page in pagesToExport {
                    let pageKey = String(page)

                    // Detect PDF vector background (preferred)
                    var pdfBackground: PDFPageBackground?
                    var size = PaperUtilities.paperSize(for: noteToExport.paperSize, orientation: noteToExport.paperOrientation)
                    if let firstData = noteToExport.imageDataByPage[pageKey]?.first {
                        if let bg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
                            pdfBackground = bg
                            size = CGSize(width: bg.width, height: bg.height)
                        } else if let uiImage = UIImage(data: firstData) {
                            size = uiImage.size
                        }
                    }

                    let bounds = CGRect(origin: .zero, size: size)

                    if let pdfBackground = pdfBackground {
                        // Vector path: draw directly into PDF context
                        context.beginPage(withBounds: bounds, pageInfo: [:])
                        guard let cg = UIGraphicsGetCurrentContext() else { continue }

                        // Fill background
                        UIColor(PaperUtilities.getPaperBackgroundColor(for: noteToExport.paperColor)).setFill()
                        cg.fill(bounds)

                        // Draw the PDF page preserving aspect ratio
                        let fileURL = AttachmentManager.fileURL(for: pdfBackground.relativePath)
                        PDFDrawingUtils.draw(pdf: fileURL, pageIndex: pdfBackground.pageIndex, in: cg, bounds: bounds, backgroundColor: .white)

                        // Separate overlay CanvasImage objects from other image data
                        var overlayCanvasImages: [CanvasImage] = []
                        if let imageDataArray = noteToExport.imageDataByPage[pageKey] {
                            for data in imageDataArray {
                                if let canvasImage = try? JSONDecoder().decode(CanvasImage.self, from: data) {
                                    overlayCanvasImages.append(canvasImage)
                                }
                            }
                        }

                        // Paper pattern overlay (grid/dots/lines) on top of background
                        drawExportPaperPattern(context: cg, paperStyle: noteToExport.paperStyle, paperColor: noteToExport.paperColor, size: bounds.size)

                        // Strokes
                        if let drawing = drawingForPage(page, note: noteToExport) {
                            let lightTrait = UITraitCollection(userInterfaceStyle: .light)
                            var drawingImage: UIImage!
                            lightTrait.performAsCurrent {
                                drawingImage = drawing.image(from: bounds, scale: 3.0)
                            }
                            drawingImage.draw(in: bounds)
                        }

                        // Overlay images
                        if !overlayCanvasImages.isEmpty {
                            let sorted = overlayCanvasImages.sorted { $0.zIndex < $1.zIndex }
                            for item in sorted {
                                if let uiImage = ImageUtilities.dataToImage(item.imageData) {
                                    cg.saveGState()
                                    if item.rotation != 0 {
                                        let centerX = item.position.x + item.size.width / 2
                                        let centerY = item.position.y + item.size.height / 2
                                        cg.translateBy(x: centerX, y: centerY)
                                        cg.rotate(by: item.rotation)
                                        cg.translateBy(x: -centerX, y: -centerY)
                                    }
                                    let rect = CGRect(origin: item.position, size: item.size)
                                    uiImage.draw(in: rect)
                                    cg.restoreGState()
                                }
                            }
                        }

                        // Text boxes
                        if let textBoxDataArray = noteToExport.textBoxDataByPage[pageKey] {
                            for data in textBoxDataArray {
                                if let textBox = try? JSONDecoder().decode(TextBox.self, from: data) {
                                    let textRect = CGRect(origin: textBox.position, size: textBox.size)
                                    let paragraphStyle = NSMutableParagraphStyle()
                                    paragraphStyle.alignment = .left
                                    let attributes: [NSAttributedString.Key: Any] = [
                                        .font: UIFont.systemFont(ofSize: textBox.fontSize),
                                        .foregroundColor: UIColor(textBox.textColor),
                                        .paragraphStyle: paragraphStyle
                                    ]
                                    textBox.text.draw(in: textRect, withAttributes: attributes)
                                }
                            }
                        }
                    } else {
                        // Legacy raster path
                        let format = UIGraphicsImageRendererFormat.default()
                        format.opaque = true
                        format.scale = rasterScale
                        let imageRenderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
                        let pageImage = imageRenderer.image { imgContext in
                            // Fill background
                            UIColor(PaperUtilities.getPaperBackgroundColor(for: noteToExport.paperColor)).setFill()
                            UIRectFill(bounds)

                            // Separate raw background images and encoded CanvasImage overlays
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

                            // Paper pattern
                            drawExportPaperPattern(context: imgContext.cgContext, paperStyle: noteToExport.paperStyle, paperColor: noteToExport.paperColor, size: bounds.size)

                            // Strokes
                            if let drawing = drawingForPage(page, note: noteToExport) {
                                let lightTrait = UITraitCollection(userInterfaceStyle: .light)
                                var drawingImage: UIImage!
                                lightTrait.performAsCurrent {
                                    drawingImage = drawing.image(from: bounds, scale: 3.0)
                                }
                                drawingImage.draw(in: bounds)
                            }

                            // Overlay images
                            if !overlayCanvasImages.isEmpty {
                                let sorted = overlayCanvasImages.sorted { $0.zIndex < $1.zIndex }
                                for item in sorted {
                                    if let uiImage = ImageUtilities.dataToImage(item.imageData) {
                                        imgContext.cgContext.saveGState()
                                        if item.rotation != 0 {
                                            let centerX = item.position.x + item.size.width / 2
                                            let centerY = item.position.y + item.size.height / 2
                                            imgContext.cgContext.translateBy(x: centerX, y: centerY)
                                            imgContext.cgContext.rotate(by: item.rotation)
                                            imgContext.cgContext.translateBy(x: -centerX, y: -centerY)
                                        }
                                        let rect = CGRect(origin: item.position, size: item.size)
                                        uiImage.draw(in: rect)
                                        imgContext.cgContext.restoreGState()
                                    }
                                }
                            }

                            // Text boxes
                            if let textBoxDataArray = noteToExport.textBoxDataByPage[pageKey] {
                                for data in textBoxDataArray {
                                    if let textBox = try? JSONDecoder().decode(TextBox.self, from: data) {
                                        let textRect = CGRect(origin: textBox.position, size: textBox.size)
                                        let paragraphStyle = NSMutableParagraphStyle()
                                        paragraphStyle.alignment = .left
                                        let attributes: [NSAttributedString.Key: Any] = [
                                            .font: UIFont.systemFont(ofSize: textBox.fontSize),
                                            .foregroundColor: UIColor(textBox.textColor),
                                            .paragraphStyle: paragraphStyle
                                        ]
                                        textBox.text.draw(in: textRect, withAttributes: attributes)
                                    }
                                }
                            }
                        }
                        context.beginPage(withBounds: bounds, pageInfo: [:])
                        if let pngData = pageImage.pngData(), let pngImage = UIImage(data: pngData) {
                            pngImage.draw(in: bounds)
                        } else {
                            pageImage.draw(in: bounds)
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

    // MARK: - Editor-matched paper pattern for export
    private func drawExportPaperPattern(context: CGContext, paperStyle: PaperStyle, paperColor: PaperColor, size: CGSize) {
        switch paperStyle {
        case .blank:
            return
        case .grid:
            let gridSpacing: CGFloat = 20
            let lineWidth: CGFloat = 0.75
            let isDarkPaper = (paperColor == .dark)
            let uiColor = isDarkPaper ? UIColor.white.withAlphaComponent(0.3) : UIColor.gray.withAlphaComponent(0.3)

            context.saveGState()
            context.setStrokeColor(uiColor.cgColor)
            context.setLineWidth(lineWidth)

            // Horizontal lines
            for i in 0...Int(size.height / gridSpacing) {
                let y = CGFloat(i) * gridSpacing
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size.width, y: y))
            }

            // Vertical lines
            for i in 0...Int(size.width / gridSpacing) {
                let x = CGFloat(i) * gridSpacing
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: size.height))
            }

            context.strokePath()
            context.restoreGState()

        case .dotted:
            let baseSpacing: CGFloat = 18
            let dotRadius: CGFloat = 1
            let margin: CGFloat = baseSpacing
            let isDarkPaper = (paperColor == .dark)
            let uiColor = isDarkPaper ? UIColor.white.withAlphaComponent(0.35) : UIColor.gray.withAlphaComponent(0.35)

            context.saveGState()
            context.setFillColor(uiColor.cgColor)

            // Available space after margins
            let availableWidth = size.width - 2 * margin
            let availableHeight = size.height - 2 * margin

            // Intervals that fit
            let horizontalIntervals = max(1, Int(availableWidth / baseSpacing))
            let verticalIntervals = max(1, Int(availableHeight / baseSpacing))

            // Dynamic spacing to fill available width like the editor overlay
            let horizontalSpacing = availableWidth / CGFloat(horizontalIntervals)
            let verticalSpacing = availableHeight / CGFloat(verticalIntervals)

            for row in 0...verticalIntervals {
                for col in 0...horizontalIntervals {
                    let x = margin + CGFloat(col) * horizontalSpacing
                    let y = margin + CGFloat(row) * verticalSpacing
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fillEllipse(in: dotRect)
                }
            }

            context.restoreGState()

        case .lined:
            let lineSpacing: CGFloat = 24
            let marginTop: CGFloat = 30
            let lineWidth: CGFloat = 0.75
            let isDarkPaper = (paperColor == .dark)
            let uiColor = isDarkPaper ? UIColor.white.withAlphaComponent(0.3) : UIColor.gray.withAlphaComponent(0.3)

            context.saveGState()
            context.setStrokeColor(uiColor.cgColor)
            context.setLineWidth(lineWidth)

            let count = Int((size.height - marginTop) / lineSpacing)
            for i in 0...count {
                let y = marginTop + CGFloat(i) * lineSpacing
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.strokePath()
            context.restoreGState()
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
        
        guard let urls = exportNote(note, selectedPages: selectedPages, exportType: exportType), !urls.isEmpty else { return }
        
        isPresenting = true
        lastExportTime = Date()
        
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        
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
