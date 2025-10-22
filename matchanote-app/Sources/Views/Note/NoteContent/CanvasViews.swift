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
    let snapToCenter: Bool
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

        // Configure for high-resolution
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

        // Apply initial centering
        DispatchQueue.main.async {

                context.coordinator.centerContentIfNeeded(canvasView)

        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        uiView.isUserInteractionEnabled = (currentTool != .textbox)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: NativeScrollCanvasView
        var canvasView: PKCanvasView?
        private var drawingObserver: NSKeyValueObservation?
        private var previousTool: PenTool = .pen

        init(_ parent: NativeScrollCanvasView) {
            self.parent = parent
        }

        func setupDrawingObservation() {
            drawingObserver = canvasView?.observe(\.drawing, options: [.new]) { [weak self] _, _ in
                self?.parent.onDrawingChange()
            }
        }

        // MARK: - PKCanvasViewDelegate (UIScrollViewDelegate methods)

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateZoomOffset(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            print("🔍 Zoom - contentSize: \(scrollView.contentSize), bounds: \(scrollView.bounds), offset: \(scrollView.contentOffset), insets: \(scrollView.contentInset)")

            // Conditionally center based on user preference
            if parent.snapToCenter {
                centerContentIfNeeded(scrollView)
            }
            updateZoomOffset(scrollView)
        }

     func centerContentIfNeeded(_ scrollView: UIScrollView) {
            // Center content when it's smaller than the viewport
            let contentWidth = scrollView.contentSize.width
            let contentHeight = scrollView.contentSize.height
            let boundsWidth = scrollView.bounds.width
            let boundsHeight = scrollView.bounds.height

            var insets = UIEdgeInsets.zero

            // Only center if content is significantly smaller than viewport
            if contentWidth < boundsWidth * 0.95 {
                let horizontalInset = max((boundsWidth - contentWidth) * 0.5, 0)
                insets.left = horizontalInset
                insets.right = horizontalInset
            }

            if contentHeight < boundsHeight * 0.95 {
                let verticalInset = max((boundsHeight - contentHeight) * 0.5, 0)
                insets.top = verticalInset
                insets.bottom = verticalInset
            }

            scrollView.contentInset = insets
        }

        private func updateZoomOffset(_ scrollView: UIScrollView) {

                self.parent.contentOffset = scrollView.contentOffset
                self.parent.currentScale = scrollView.zoomScale

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
    // Shape recognition removed

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isScrollEnabled = false  // Disable to let outer scroll view handle pan/zoom
        canvasView.overrideUserInterfaceStyle = .light

        // Configure for high-resolution rendering
        canvasView.contentScaleFactor = UIScreen.main.scale * 2  // 2x scale for crisp rendering
        canvasView.layer.contentsScale = UIScreen.main.scale * 2
        canvasView.layer.shouldRasterize = false  // Never rasterize to avoid blur

        // Set up drawing change delegate for shape recognition
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
            // This gets called immediately when a stroke is completed
            // We can trigger recognition here by posting a notification
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
