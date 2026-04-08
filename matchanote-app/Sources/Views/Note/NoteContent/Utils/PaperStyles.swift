import SwiftUI
import UIKit

// MARK: - Paper Styles Extension

extension WrittenNoteView {

    @ViewBuilder
    func backgroundImagesView(pageIndex: Int) -> some View {
        // Display vector PDF background if present; otherwise fall back to raster image
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let firstData = imageDataArray.first {
            if let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
                PDFPageBackgroundView(background: pdfBg, noteId: note.id.uuidString)
                    .frame(
                        width: perPageSize(pageIndex).width,
                        height: perPageSize(pageIndex).height
                    )
                    .clipped()
            } else if let uiImage = UIImage(data: firstData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: perPageSize(pageIndex).width,
                        height: perPageSize(pageIndex).height
                    )
                    .clipped()
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    func paperBackground(pageIndex: Int) -> some View {
        // Determine if dark mode should apply to the paper background
        let shouldUseDarkBackground = preferencesManager.noteEditorDarkModeForWhitePaper
            && note.paperColor == .white
            && colorScheme == .dark

        let paperBackground: Color = shouldUseDarkBackground ? .black : getPaperBackgroundColor(for: note.paperColor)

        Rectangle()
            .fill(paperBackground)
            .frame(
                width: perPageSize(pageIndex).width,
                height: perPageSize(pageIndex).height
            )
            .overlay {
                switch note.paperStyle {
                case .grid:
                    gridOverlay(size: perPageSize(pageIndex), isDarkBackground: shouldUseDarkBackground)
                case .dotted:
                    dottedOverlay(size: perPageSize(pageIndex), isDarkBackground: shouldUseDarkBackground)
                case .lined:
                    linedOverlay(size: perPageSize(pageIndex), isDarkBackground: shouldUseDarkBackground)
                case .blank:
                    EmptyView()
                }
            }
    }

    // Determine per-page size from background image if present; fallback to note paper size
    func perPageSize(_ pageIndex: Int) -> CGSize {
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let firstData = imageDataArray.first {
            if let pdfBg = try? JSONDecoder().decode(PDFPageBackground.self, from: firstData) {
                return pdfBg.size
            } else if let uiImage = UIImage(data: firstData) {
                return uiImage.size
            }
        }
        return CGSize(
            width: getPaperWidth(for: note.paperSize, orientation: note.paperOrientation),
            height: getPaperHeight(for: note.paperSize, orientation: note.paperOrientation)
        )
    }

    @ViewBuilder
    func gridOverlay(size: CGSize, isDarkBackground: Bool) -> some View {
        PaperUtilities.paperPatternView(paperStyle: .grid, isDarkBackground: isDarkBackground)
    }

    @ViewBuilder
    func dottedOverlay(size: CGSize, isDarkBackground: Bool) -> some View {
        PaperUtilities.paperPatternView(paperStyle: .dotted, isDarkBackground: isDarkBackground)
    }

    @ViewBuilder
    func linedOverlay(size: CGSize, isDarkBackground: Bool) -> some View {
        PaperUtilities.paperPatternView(paperStyle: .lined, isDarkBackground: isDarkBackground)
    }

    // Helper function for background color
    func getPaperBackgroundColor(for color: PaperColor) -> Color {
        return PaperUtilities.getPaperBackgroundColor(for: color)
    }

    // Helper functions to get paper dimensions
    func getPaperWidth(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGFloat {
        return PaperUtilities.getPaperWidth(for: size, orientation: orientation)
    }

    func getPaperHeight(for size: PaperSize, orientation: PaperOrientation = .portrait) -> CGFloat {
        return PaperUtilities.getPaperHeight(for: size, orientation: orientation)
    }
}
