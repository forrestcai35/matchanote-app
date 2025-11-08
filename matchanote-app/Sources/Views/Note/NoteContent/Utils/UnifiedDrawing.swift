import PencilKit
import SwiftUI

// MARK: - Unified Drawing Conversion Extension

extension WrittenNoteView {

    // MARK: - Page Y-Offset Calculations

    /// Calculate the vertical spacing between pages
    var pageSpacing: CGFloat { 8 }

    /// Calculate the Y offset for a specific page in the unified canvas
    func pageYOffset(for pageIndex: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<pageIndex {
            offset += perPageSize(i).height + pageSpacing
        }
        return offset
    }

    /// Calculate the total height of the unified canvas
    func calculateTotalVerticalSize() -> CGSize {
        guard pageCount > 0 else { return .zero }

        var totalHeight: CGFloat = 0
        let maxWidth = (0..<pageCount).map { perPageSize($0).width }.max() ?? 0

        for i in 0..<pageCount {
            totalHeight += perPageSize(i).height
            if i < pageCount - 1 {
                totalHeight += pageSpacing
            }
        }

        return CGSize(width: maxWidth, height: totalHeight)
    }

    // MARK: - Unified Drawing Conversion

    /// Create a single unified PKDrawing from all page drawings
    /// Used when entering vertical scroll mode
    func createUnifiedDrawing() -> PKDrawing {
        var unified = PKDrawing()

        for pageIndex in 0..<min(pageCount, canvasViews.count) {
            let pageDrawing = canvasViews[pageIndex].drawing
            let yOffset = pageYOffset(for: pageIndex)

            // Transform strokes to the correct vertical position
            let shifted = pageDrawing.transformed(
                using: CGAffineTransform(translationX: 0, y: yOffset)
            )
            unified.append(shifted)
        }

        return unified
    }

    /// Split a unified PKDrawing back into individual page drawings
    /// Used when saving from vertical scroll mode
    func splitUnifiedDrawing(_ drawing: PKDrawing) -> [PKDrawing] {
        var pageDrawings: [PKDrawing] = []

        for pageIndex in 0..<pageCount {
            let pageHeight = perPageSize(pageIndex).height
            let pageYStart = pageYOffset(for: pageIndex)
            let pageYEnd = pageYStart + pageHeight

            // Create a new drawing with only strokes for this page
            var pageDrawing = PKDrawing()

            // Filter strokes that belong to this page
            for stroke in drawing.strokes {
                let bounds = stroke.renderBounds
                // Include stroke if any part overlaps with page bounds
                if bounds.maxY > pageYStart && bounds.minY < pageYEnd {
                    pageDrawing.strokes.append(stroke)
                }
            }

            // Transform the page drawing back to page-local coordinates
            let localDrawing = pageDrawing.transformed(
                using: CGAffineTransform(translationX: 0, y: -pageYStart)
            )

            pageDrawings.append(localDrawing)
        }

        return pageDrawings
    }

    /// Detect which page is currently visible based on scroll offset
    func detectCurrentPage(from contentOffset: CGPoint) -> Int {
        var accumulatedY: CGFloat = 0

        for pageIndex in 0..<pageCount {
            let pageHeight = perPageSize(pageIndex).height

            // If the scroll position is within this page's bounds, return it
            if contentOffset.y < accumulatedY + pageHeight {
                return pageIndex
            }

            accumulatedY += pageHeight + pageSpacing
        }

        // If we've scrolled past all pages, return the last page
        return max(0, pageCount - 1)
    }
}
