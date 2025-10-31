import SwiftUI
import UIKit
import CoreGraphics

// UIKit tiled view that renders a single PDF page crisply at any zoom level
final class PDFTiledPageView: UIView {
    override class var layerClass: AnyClass { CATiledLayer.self }

    var fileURL: URL? { didSet { setNeedsDisplay() } }
    var pageIndex: Int = 1 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureTiling()
        isOpaque = true
        backgroundColor = .white
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTiling()
        isOpaque = true
        backgroundColor = .white
        contentMode = .redraw
    }

    private func configureTiling() {
        guard let layer = self.layer as? CATiledLayer else { return }
        // Reasonable defaults for crispness when zooming
        layer.levelsOfDetail = 4
        layer.levelsOfDetailBias = 4
        // Tile size tuned for memory/perf; multiplied by screen scale automatically
        layer.tileSize = CGSize(width: 512, height: 512)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let url = fileURL else { return }
        PDFDrawingUtils.draw(pdf: url, pageIndex: pageIndex, in: ctx, bounds: bounds, backgroundColor: .white)
    }
}

// SwiftUI wrapper
struct PDFPageBackgroundView: UIViewRepresentable {
    let background: PDFPageBackground

    func makeUIView(context: Context) -> PDFTiledPageView {
        let view = PDFTiledPageView()
        view.fileURL = AttachmentManager.fileURL(for: background.relativePath)
        view.pageIndex = background.pageIndex
        return view
    }

    func updateUIView(_ uiView: PDFTiledPageView, context: Context) {
        uiView.fileURL = AttachmentManager.fileURL(for: background.relativePath)
        uiView.pageIndex = background.pageIndex
        // Size is managed by SwiftUI frame; content redraw happens automatically
    }
}

