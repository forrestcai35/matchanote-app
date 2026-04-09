import Foundation
import UIKit
import PencilKit

/// Centralized provider for preparing note context for AI assistant
/// Handles PDF rendering, caching, page selection, and image generation
class NoteContextProvider {

    // MARK: - Singleton
    static let shared = NoteContextProvider()

    private let cache = PDFRenderCache.shared

    private init() {}

    // MARK: - Public API

    /// Generate media items from a note for AI analysis
    /// - Parameters:
    ///   - note: The note to analyze
    ///   - userQuery: User's question (used for intelligent page selection)
    ///   - maxPages: Maximum number of pages to include (default 10)
    ///   - scale: Image scale for rendering (default 0.6)
    /// - Returns: Array of media items ready to send to LLM
    func generateMediaItems(
        from note: Note,
        userQuery: String = "",
        maxPages: Int = 10,
        scale: CGFloat = 0.6
    ) async -> [MediaItem] {
        var mediaItems: [MediaItem] = []

        // Update cache modification time for this note
        cache.updateNoteModificationTime(
            noteId: note.id.uuidString,
            modificationDate: note.dateModified
        )

        // Select relevant pages based on user query
        let pageKeys: [String]
        if !userQuery.isEmpty {
            let selection = PageSelector.selectPages(userQuery: userQuery, note: note, maxPages: maxPages)
            pageKeys = selection.pageKeys
            print("📄 PageSelector: \(selection.reason)")
        } else {
            // Default: all pages sorted, up to maxPages
            let allPages = Array(note.drawingDataByPage.keys).sorted { key1, key2 in
                guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
                return page1 < page2
            }
            pageKeys = Array(allPages.prefix(maxPages))
        }

        // Render each selected page
        for pageKey in pageKeys {
            if let renderedImage = await renderPage(from: note, pageKey: pageKey, scale: scale) {
                // Convert to JPEG data with high quality for accurate text/handwriting recognition
                // 0.85 quality provides excellent clarity while keeping file sizes reasonable
                if let imageData = renderedImage.jpegData(compressionQuality: 0.85) {
                    let mediaItem = MediaItem(data: imageData, type: .image)
                    mediaItems.append(mediaItem)
                }
            }
        }

        return mediaItems
    }

    // MARK: - Page Rendering

    /// Render a single page with PDF-aware handling and caching
    private func renderPage(from note: Note, pageKey: String, scale: CGFloat) async -> UIImage? {
        guard let pageIndex = Int(pageKey),
              let drawingData = note.drawingDataByPage[pageKey],
              let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        let paperSize = PaperUtilities.paperSize(for: note.paperSize)
        let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: pageIndex)

        // Check if background is a PDF
        let backgroundImages = note.imageDataByPage[pageKey] ?? []
        var pdfBackground: PDFPageBackground?

        if let firstData = backgroundImages.first,
           let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
            pdfBackground = pdfBg
        }

        // Handle PDF background with caching
        if let pdfBg = pdfBackground {
            return await renderPDFPage(
                pdfBackground: pdfBg,
                drawing: drawing,
                overlayImages: overlayImages,
                paperSize: paperSize,
                paperColor: note.paperColor,
                noteId: note.id.uuidString,
                scale: scale
            )
        }

        // Handle regular image background
        return renderRegularPage(
            drawing: drawing,
            backgroundImages: backgroundImages,
            overlayImages: overlayImages,
            paperSize: paperSize,
            paperColor: note.paperColor,
            paperStyle: note.paperStyle,
            scale: scale
        )
    }

    /// Render a page with PDF background (with caching)
    private func renderPDFPage(
        pdfBackground: PDFPageBackground,
        drawing: PKDrawing,
        overlayImages: [CanvasImage],
        paperSize: CGSize,
        paperColor: PaperColor,
        noteId: String,
        scale: CGFloat
    ) async -> UIImage? {
        // Try to get from cache
        if let cachedImage = cache.get(
            pdfPath: pdfBackground.relativePath,
            pageIndex: pdfBackground.pageIndex,
            scale: scale,
            noteId: noteId
        ) {
            // Composite drawing and overlays on top of cached PDF
            return compositeDrawingOnImage(
                baseImage: cachedImage,
                drawing: drawing,
                overlayImages: overlayImages,
                paperSize: paperSize,
                scale: scale
            )
        }

        // Cache miss - render PDF
        let fileURL = AttachmentManager.fileURL(for: pdfBackground.relativePath)
        guard let pdfImage = renderPDFToImage(
            pdfURL: fileURL,
            pageIndex: pdfBackground.pageIndex,
            paperSize: paperSize,
            paperColor: paperColor,
            scale: scale
        ) else {
            return nil
        }

        // Save to cache
        cache.set(
            image: pdfImage,
            pdfPath: pdfBackground.relativePath,
            pageIndex: pdfBackground.pageIndex,
            scale: scale,
            noteId: noteId
        )

        // Composite drawing and overlays on top
        return compositeDrawingOnImage(
            baseImage: pdfImage,
            drawing: drawing,
            overlayImages: overlayImages,
            paperSize: paperSize,
            scale: scale
        )
    }

    /// Render a page with regular image background
    private func renderRegularPage(
        drawing: PKDrawing,
        backgroundImages: [Data],
        overlayImages: [CanvasImage],
        paperSize: CGSize,
        paperColor: PaperColor,
        paperStyle: PaperStyle,
        scale: CGFloat
    ) -> UIImage {
        return PreviewGenerator.generatePreviewFromComponents(
            drawing: drawing,
            paperSize: paperSize,
            paperColor: paperColor,
            paperStyle: paperStyle,
            scale: scale,
            backgroundImages: backgroundImages,
            overlayImages: overlayImages
        )
    }

    // MARK: - PDF Rendering Utilities

    /// Render a PDF page to an image
    private func renderPDFToImage(
        pdfURL: URL,
        pageIndex: Int,
        paperSize: CGSize,
        paperColor: PaperColor,
        scale: CGFloat
    ) -> UIImage? {
        let scaledSize = CGSize(width: paperSize.width * scale, height: paperSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let backgroundColor = UIColor(PaperUtilities.getPaperBackgroundColor(for: paperColor))
        let image = renderer.image { ctx in
            // Fill background
            backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: scaledSize))

            // Draw PDF
            PDFDrawingUtils.draw(
                pdf: pdfURL,
                pageIndex: pageIndex,
                in: ctx.cgContext,
                bounds: CGRect(origin: .zero, size: scaledSize),
                backgroundColor: backgroundColor,
                verticalAlignment: .top
            )
        }

        return image
    }

    /// Composite drawing and overlays on top of a base image
    private func compositeDrawingOnImage(
        baseImage: UIImage,
        drawing: PKDrawing,
        overlayImages: [CanvasImage],
        paperSize: CGSize,
        scale: CGFloat
    ) -> UIImage {
        let scaledSize = CGSize(width: paperSize.width * scale, height: paperSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let compositeImage = renderer.image { ctx in
            // Draw base image (PDF or regular background)
            baseImage.draw(in: CGRect(origin: .zero, size: scaledSize))

            // Draw PKDrawing
            let scaledDrawing = drawing.image(from: CGRect(origin: .zero, size: paperSize), scale: scale)
            scaledDrawing.draw(in: CGRect(origin: .zero, size: scaledSize))

            // Draw overlay images (CanvasImage objects)
            for canvasImage in overlayImages {
                if let overlayImage = UIImage(data: canvasImage.imageData) {
                    let scaledFrame = CGRect(
                        x: canvasImage.position.x * scale,
                        y: canvasImage.position.y * scale,
                        width: canvasImage.size.width * scale,
                        height: canvasImage.size.height * scale
                    )
                    overlayImage.draw(in: scaledFrame)
                }
            }
        }

        return compositeImage
    }

    // MARK: - Cache Management

    /// Clear cache for a specific note
    func clearCache(for noteId: String) {
        cache.clearCacheForNote(noteId: noteId)
    }

    /// Clear all cached renders
    func clearAllCache() {
        cache.clearAll()
    }
}
