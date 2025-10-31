import Foundation
import CoreGraphics
import UIKit

// MARK: - PDF Background Model
// Encoded into note.imageDataByPage as JSON to represent a vector PDF page background
struct PDFPageBackground: Codable {
    // Relative path under the app's Documents directory (e.g. "Attachments/uuid_name.pdf")
    let relativePath: String

    // 1-based page index within the PDF file
    let pageIndex: Int

    // Original page size in points (media box)
    let width: CGFloat
    let height: CGFloat

    // Convenience
    var size: CGSize { CGSize(width: width, height: height) }
}

// MARK: - Attachments Manager
// Stores imported assets (like original PDFs) on disk and returns relative paths to persist in notes
enum AttachmentManager {
    private static let attachmentsFolderName = "Attachments"

    // Documents directory
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // Attachments directory URL (ensures the folder exists)
    static func attachmentsDirectory() throws -> URL {
        let url = documentsDirectory.appendingPathComponent(attachmentsFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // Save data to Attachments with a unique, sanitized name; returns relative path (e.g. "Attachments/<file>")
    static func save(data: Data, preferredFileName: String, fileExtension: String) throws -> String {
        let sanitizedBase = sanitizeFileName(preferredFileName)
        let uniqueName = "\(UUID().uuidString)_\(sanitizedBase).\(fileExtension)"
        let dir = try attachmentsDirectory()
        let fileURL = dir.appendingPathComponent(uniqueName)
        try data.write(to: fileURL, options: .atomic)
        return "\(attachmentsFolderName)/\(uniqueName)"
    }

    // Build a file URL from a relative path
    static func fileURL(for relativePath: String) -> URL {
        return documentsDirectory.appendingPathComponent(relativePath)
    }

    // Best-effort file name sanitization
    private static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        return cleaned.replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - PDF Drawing Helpers
enum PDFDrawingUtils {
    // Draw a CGPDF page to fit the given rect, preserving aspect ratio (letterboxed if needed)
    static func draw(pdf url: URL, pageIndex: Int, in context: CGContext, bounds: CGRect, backgroundColor: UIColor? = .white) {
        guard let doc = CGPDFDocument(url as CFURL),
              let page = doc.page(at: pageIndex) else { return }

        // Optional background fill
        if let bg = backgroundColor {
            context.saveGState()
            context.setFillColor(bg.cgColor)
            context.fill(bounds)
            context.restoreGState()
        }

        // Compute aspect-fit transform
        let pageRect = page.getBoxRect(.mediaBox)
        let scaleX = bounds.width / max(pageRect.width, 1)
        let scaleY = bounds.height / max(pageRect.height, 1)
        let scale = min(scaleX, scaleY)
        let scaledWidth = pageRect.width * scale
        let scaledHeight = pageRect.height * scale
        let offsetX = bounds.minX + (bounds.width - scaledWidth) / 2
        let offsetY = bounds.minY + (bounds.height - scaledHeight) / 2

        context.saveGState()
        // PDF coordinate system is bottom-left origin; flip to iOS coordinates
        context.translateBy(x: offsetX, y: offsetY + scaledHeight)
        context.scaleBy(x: scale, y: -scale)
        context.drawPDFPage(page)
        context.restoreGState()
    }
}
