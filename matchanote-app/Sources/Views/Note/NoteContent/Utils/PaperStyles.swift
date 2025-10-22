import SwiftUI
import UIKit

// MARK: - Paper Styles Extension

extension WrittenNoteView {

    @ViewBuilder
    func backgroundImagesView(pageIndex: Int) -> some View {
        // Display images from note.imageDataByPage as backgrounds
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let imageData = imageDataArray.first,
           let uiImage = UIImage(data: imageData) {
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
    }

    @ViewBuilder
    func paperBackground(pageIndex: Int) -> some View {
        let paperBackground: Color = getPaperBackgroundColor(for: note.paperColor)
        Rectangle()
            .fill(paperBackground)
            .frame(
                width: perPageSize(pageIndex).width,
                height: perPageSize(pageIndex).height
            )
            .overlay {
                GeometryReader { geometry in
                    switch note.paperStyle {
                    case .grid:
                        gridOverlay(size: geometry.size)
                    case .dotted:
                        dottedOverlay(size: geometry.size)
                    case .lined:
                        linedOverlay(size: geometry.size)
                    case .blank:
                        EmptyView()
                    }
                }
            }
    }

    // Determine per-page size from background image if present; fallback to note paper size
    func perPageSize(_ pageIndex: Int) -> CGSize {
        let baseSize: CGSize
        if let imageDataArray = note.imageDataByPage[String(pageIndex)],
           let imageData = imageDataArray.first,
           let uiImage = UIImage(data: imageData) {
            baseSize = uiImage.size
        } else {
            baseSize = CGSize(width: getPaperWidth(for: note.paperSize), height: getPaperHeight(for: note.paperSize))
        }
        // Render at natural size; rely on UIScreen scale for crispness
        return baseSize
    }

    @ViewBuilder
    func gridOverlay(size: CGSize) -> some View {
        // Match prior visual density now that we render at natural size
        let gridSpacing: CGFloat = 20

        ZStack {
            // Horizontal lines
            ForEach(0..<Int(size.height / gridSpacing + 1), id: \.self) { i in
                let y = CGFloat(i) * gridSpacing
                Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
            // Vertical lines
            ForEach(0..<Int(size.width / gridSpacing + 1), id: \.self) { i in
                let x = CGFloat(i) * gridSpacing
                Line(start: CGPoint(x: x, y: 0), end: CGPoint(x: x, y: size.height))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
        }
    }

    @ViewBuilder
    func dottedOverlay(size: CGSize) -> some View {
        // Match prior visual density at natural size
        let baseSpacing: CGFloat = 18
        let dotRadius: CGFloat = 1
        let margin: CGFloat = baseSpacing

        Canvas { context, canvasSize in
                // Calculate available space after margins
                let availableWidth = canvasSize.width - 2 * margin
                let availableHeight = canvasSize.height - 2 * margin

                // Calculate number of intervals that can fit
                let horizontalIntervals = max(1, Int(availableWidth / baseSpacing))
                let verticalIntervals = max(1, Int(availableHeight / baseSpacing))

                // Calculate dynamic spacing to fill available width
                let horizontalSpacing = availableWidth / CGFloat(horizontalIntervals)
                let verticalSpacing = availableHeight / CGFloat(verticalIntervals)

                // Draw dots within margins
                for y in 0...verticalIntervals {
                    for x in 0...horizontalIntervals {
                        let xPos = margin + CGFloat(x) * horizontalSpacing
                        let yPos = margin + CGFloat(y) * verticalSpacing
                        context.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: xPos - dotRadius,
                                    y: yPos - dotRadius,
                                    width: 2 * dotRadius,
                                    height: 2 * dotRadius
                                )),
                            with: .color(Color.gray.opacity(0.35))
                        )
                    }
                }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    func linedOverlay(size: CGSize) -> some View {
        // Match prior visual density at natural size
        let lineSpacing: CGFloat = 24
        let marginTop: CGFloat = 30

        ZStack {
            ForEach(0..<Int((size.height - marginTop) / lineSpacing + 1), id: \.self) { i in
                let y = marginTop + CGFloat(i) * lineSpacing
                Line(start: CGPoint(x: 0, y: y), end: CGPoint(x: size.width, y: y))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.75)
            }
        }
    }

    // Helper function for background color
    func getPaperBackgroundColor(for color: PaperColor) -> Color {
        return PaperUtilities.getPaperBackgroundColor(for: color)
    }

    // Helper functions to get paper dimensions
    func getPaperWidth(for size: PaperSize) -> CGFloat {
        return PaperUtilities.getPaperWidth(for: size)
    }

    func getPaperHeight(for size: PaperSize) -> CGFloat {
        return PaperUtilities.getPaperHeight(for: size)
    }
}
