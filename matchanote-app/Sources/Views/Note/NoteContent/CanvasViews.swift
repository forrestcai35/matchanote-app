import PencilKit
import SwiftUI
import UIKit

// MARK: - Line Shape

// Line Shape for drawing grids and lines
struct Line: Shape {
    var start, end: CGPoint
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Native Scroll Canvas View

// Native scroll canvas view with PKCanvasView's built-in scrolling
struct NativeScrollCanvasView: UIViewRepresentable {
    let canvasView: PKCanvasView
    let contentSize: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat
    @Binding var currentScale: CGFloat
    @Binding var contentOffset: CGPoint
    @Binding var currentTool: PenTool?

    let onDrawingChange: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        // Enable native scrolling and zooming
        canvasView.contentSize = contentSize
        canvasView.isScrollEnabled = true
        canvasView.minimumZoomScale = minScale
        canvasView.maximumZoomScale = maxScale
        canvasView.zoomScale = currentScale
        canvasView.contentOffset = contentOffset
        canvasView.delegate = context.coordinator

        print("📐 Canvas setup - contentSize: \(contentSize), frame: \(canvasView.frame)")
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.backgroundColor = .clear

        // Disable automatic content inset adjustment to prevent auto-centering
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.bouncesZoom = false
        canvasView.bounces = false

        // Configure for high-resolution (match ensureCanvasExists settings)
        canvasView.contentScaleFactor = UIScreen.main.scale * 2
        canvasView.layer.contentsScale = UIScreen.main.scale * 2
        canvasView.layer.shouldRasterize = false

        // Add pencil interaction
        if UIPencilInteraction.preferredTapAction == .switchEraser {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = context.coordinator
            canvasView.addInteraction(pencilInteraction)
        }

        context.coordinator.canvasView = canvasView
        context.coordinator.setupDrawingObservation()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self

        // Only update canvas properties when user is NOT actively interacting
        // This prevents rendering issues during rapid zoom/scroll
        if !context.coordinator.isUserInteracting {
            // Update canvas properties to stay in sync with bindings
            if uiView.contentSize != contentSize {
                uiView.contentSize = contentSize
            }

            if uiView.minimumZoomScale != minScale {
                uiView.minimumZoomScale = minScale
            }

            if uiView.maximumZoomScale != maxScale {
                uiView.maximumZoomScale = maxScale
            }

            // Only update zoom/offset if not actively zooming (to avoid feedback loop)
            if !context.coordinator.isUpdatingZoom {
                if abs(uiView.zoomScale - currentScale) > 0.01 {
                    uiView.zoomScale = currentScale
                }

                if abs(uiView.contentOffset.x - contentOffset.x) > 1.0 ||
                   abs(uiView.contentOffset.y - contentOffset.y) > 1.0 {
                    uiView.contentOffset = contentOffset
                }
            }
        }

        // Always disable drawing when textbox or photo tool is active (regardless of interaction state)
        uiView.drawingGestureRecognizer.isEnabled = (currentTool != .textbox && currentTool != .photo)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: NativeScrollCanvasView
        var canvasView: PKCanvasView?
        private var drawingObserver: NSKeyValueObservation?
        private var previousTool: PenTool = .pen
        var isUpdatingZoom: Bool = false
        var isUserInteracting: Bool = false

        init(_ parent: NativeScrollCanvasView) {
            self.parent = parent
        }

        func setupDrawingObservation() {
            drawingObserver = canvasView?.observe(\.drawing, options: [.new]) { [weak self] _, _ in
                self?.parent.onDrawingChange()
            }
        }

        // MARK: - PKCanvasViewDelegate (UIScrollViewDelegate methods)

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            isUserInteracting = true
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserInteracting = false
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserInteracting = false
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            isUserInteracting = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Constrain scrolling to valid content bounds
            constrainScrollBounds(scrollView)
            updateZoomOffset(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Constrain scrolling during zoom as well
            constrainScrollBounds(scrollView)
            updateZoomOffset(scrollView)
        }

        private func constrainScrollBounds(_ scrollView: UIScrollView) {
            // Calculate the valid scroll bounds based on content size and zoom
            let scaledContentWidth = scrollView.contentSize.width * scrollView.zoomScale
            let scaledContentHeight = scrollView.contentSize.height * scrollView.zoomScale
            
            let maxOffsetX = max(0, scaledContentWidth - scrollView.bounds.width)
            let maxOffsetY = max(0, scaledContentHeight - scrollView.bounds.height)
            
            var newOffset = scrollView.contentOffset
            var needsCorrection = false
            
            // Clamp horizontal scrolling
            if newOffset.x < 0 {
                newOffset.x = 0
                needsCorrection = true
            } else if newOffset.x > maxOffsetX {
                newOffset.x = maxOffsetX
                needsCorrection = true
            }
            
            // Clamp vertical scrolling
            if newOffset.y < 0 {
                newOffset.y = 0
                needsCorrection = true
            } else if newOffset.y > maxOffsetY {
                newOffset.y = maxOffsetY
                needsCorrection = true
            }
            
            // Apply correction if needed
            if needsCorrection {
                scrollView.contentOffset = newOffset
            }
        }

        private func updateZoomOffset(_ scrollView: UIScrollView) {
            guard !isUpdatingZoom else { return }
            isUpdatingZoom = true
            
            // Update immediately for smooth, lag-free drawing
            // Synchronous updates are critical for real-time canvas interactions
            self.parent.contentOffset = scrollView.contentOffset
            self.parent.currentScale = scrollView.zoomScale
            self.isUpdatingZoom = false
        }

            // MARK: - PKCanvasViewDelegate

            func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
                // This gets called immediately when a stroke is completed
                // Trigger recognition by posting a notification for AutoStrokeRecognitionManager
                NotificationCenter.default.post(name: NSNotification.Name("StrokeCompleted"), object: canvasView)
            }

            // MARK: - UIPencilInteractionDelegate

            func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
                guard let canvas = canvasView else { return }

                if let currentTool = parent.currentTool {
                    if currentTool == .eraser {
                        parent.currentTool = previousTool
                        canvas.tool = previousTool.toolInstance()
                    } else {
                        previousTool = currentTool
                        parent.currentTool = .eraser
                        canvas.tool = PenTool.eraser.toolInstance()
                    }
                } else {
                    previousTool = .pen
                    parent.currentTool = .eraser
                    canvas.tool = PenTool.eraser.toolInstance()
                }
            }

            deinit {
                drawingObserver?.invalidate()
            }
    }
}

// MARK: - PencilKit Canvas View (Legacy)

// PencilKit Canvas SwiftUI wrapper
struct PencilKitCanvasView: UIViewRepresentable {
    var canvasView: PKCanvasView
    @Binding var currentTool: PenTool?
    @Binding var canvasViews: [PKCanvasView]
    @Binding var currentPage: Int


    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.overrideUserInterfaceStyle = .light

        // Configure for high-resolution rendering
        canvasView.contentScaleFactor = UIScreen.main.scale * 3
        canvasView.layer.contentsScale = UIScreen.main.scale * 3
        canvasView.layer.shouldRasterize = false 
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.delegate = context.coordinator

        // Add pencil interaction for double tap
        if UIPencilInteraction.preferredTapAction == .switchEraser {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = context.coordinator
            canvasView.addInteraction(pencilInteraction)
        }

        // Add undo/redo gesture recognizers
        let twoFingerTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerTap(_:))
        )
        twoFingerTapGesture.numberOfTouchesRequired = 2
        twoFingerTapGesture.numberOfTapsRequired = 1
        canvasView.addGestureRecognizer(twoFingerTapGesture)

        let threeFingerTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleThreeFingerTap(_:))
        )
        threeFingerTapGesture.numberOfTouchesRequired = 3
        threeFingerTapGesture.numberOfTapsRequired = 1
        canvasView.addGestureRecognizer(threeFingerTapGesture)

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Disable user interaction when textbox tool is active
        uiView.isUserInteractionEnabled = (currentTool != .textbox)
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPencilInteractionDelegate, PKCanvasViewDelegate {
        var parent: PencilKitCanvasView
        private var previousTool: PenTool = .pen

        init(_ parent: PencilKitCanvasView) {
            self.parent = parent
            super.init()
            // Shape recognition configuration removed
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            // Handle double tap to switch between eraser and previous tool
            if let currentTool = parent.currentTool {
                if currentTool == .eraser {
                    // Switch back to previous tool
                    parent.currentTool = previousTool
                    if parent.currentPage < parent.canvasViews.count {
                        parent.canvasViews[parent.currentPage].tool = previousTool.toolInstance()
                    }
                } else {
                    // Store current tool and switch to eraser
                    previousTool = currentTool
                    parent.currentTool = .eraser
                    if parent.currentPage < parent.canvasViews.count {
                        parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
                    }
                }
            } else {
                // If no current tool, default to pen then switch to eraser
                previousTool = .pen
                parent.currentTool = .eraser
                if parent.currentPage < parent.canvasViews.count {
                    parent.canvasViews[parent.currentPage].tool = PenTool.eraser.toolInstance()
                }
            }
        }

        @objc func handleTwoFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard gestureRecognizer.state == .ended else { return }

            // Perform undo on the current canvas
            if parent.currentPage < parent.canvasViews.count {
                let canvas = parent.canvasViews[parent.currentPage]
                if let undoManager = canvas.undoManager, undoManager.canUndo {
                    undoManager.undo()
                }
            }
        }

        @objc func handleThreeFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard gestureRecognizer.state == .ended else { return }

            // Perform redo on the current canvas
            if parent.currentPage < parent.canvasViews.count {
                let canvas = parent.canvasViews[parent.currentPage]
                if let undoManager = canvas.undoManager, undoManager.canRedo {
                    undoManager.redo()
                }
            }
        }

        // MARK: - PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {

            NotificationCenter.default.post(name: NSNotification.Name("StrokeCompleted"), object: canvasView)
        }

        deinit {
            // Shape recognition cleanup removed
        }
    }
}

// MARK: - UIView Extension

// Extension to find the UIViewController
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
