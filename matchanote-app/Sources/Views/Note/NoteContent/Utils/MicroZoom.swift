import PencilKit
import UIKit

// Shared helper to apply a micro-zoom nudge to PKCanvasView synchronously.
// Captures original/min/max zoom, bumps slightly within bounds without animation,
// then restores the original scale on the next runloop tick, also without animation.
func applyMicroZoomSync(to canvas: PKCanvasView) {
    let originalZoom = canvas.zoomScale
    let minZoom = canvas.minimumZoomScale
    let maxZoom = canvas.maximumZoomScale
    let bumpedZoom = max(minZoom, min(maxZoom, originalZoom * 1.001))

    UIView.performWithoutAnimation {
        canvas.setZoomScale(bumpedZoom, animated: false)
    }

    DispatchQueue.main.async {
        UIView.performWithoutAnimation {
            canvas.setZoomScale(originalZoom, animated: false)
        }
    }
}


