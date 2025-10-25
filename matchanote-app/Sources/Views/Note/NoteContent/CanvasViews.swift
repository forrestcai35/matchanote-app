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
    @ObservedObject var preferencesManager = PreferencesManager.shared

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

        print("📐 makeUIView - AFTER: contentSize=\(canvasView.contentSize), isScrollEnabled=\(canvasView.isScrollEnabled)")
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.backgroundColor = .clear

        // Disable automatic content inset adjustment to prevent auto-centering
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.bouncesZoom = false
        canvasView.bounces = false

        // Configure for high-resolution (match ensureCanvasExists settings)
        canvasView.contentScaleFactor = 2.0 // Default high-resolution scale
        canvasView.layer.contentsScale = 2.0 
        canvasView.layer.shouldRasterize = false

        // Add pencil interaction
        if UIPencilInteraction.preferredTapAction == .switchEraser {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = context.coordinator
            canvasView.addInteraction(pencilInteraction)
        }

        // Add custom undo/redo gestures only when in tap mode
        if preferencesManager.noteEditorUndoRedoGestureMode == .twoThreeTap {
            // Add custom undo gesture (2-finger tap)
            let twoFingerTapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTwoFingerTap(_:))
            )
            twoFingerTapGesture.numberOfTouchesRequired = 2
            twoFingerTapGesture.numberOfTapsRequired = 1
            canvasView.addGestureRecognizer(twoFingerTapGesture)

            // Add custom redo gesture (3-finger tap)
            let threeFingerTapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleThreeFingerTap(_:))
            )
            threeFingerTapGesture.numberOfTouchesRequired = 3
            threeFingerTapGesture.numberOfTapsRequired = 1
            // Set delegate to allow simultaneous recognition with system gestures
            threeFingerTapGesture.delegate = context.coordinator
            canvasView.addGestureRecognizer(threeFingerTapGesture)
        }

        context.coordinator.canvasView = canvasView
        context.coordinator.setupDrawingObservation()

        // HACK: Trigger a micro-zoom to force PKCanvasView to enforce contentSize bounds
        // This simulates what a pinch gesture does
        DispatchQueue.main.async {
            let originalZoom = canvasView.zoomScale
            canvasView.zoomScale = originalZoom * 1.00001
            canvasView.zoomScale = originalZoom
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self

        // Apply finger drawing preference
        uiView.drawingPolicy = preferencesManager.noteEditorFingerDrawingEnabled ? .anyInput : .pencilOnly

        // Always disable drawing when textbox or photo tool is active (regardless of interaction state)
        uiView.drawingGestureRecognizer.isEnabled = (currentTool != .textbox && currentTool != .photo)
        
        // Synchronize zoom and offset when they change (e.g., when switching pages)
        // Only update if not currently being modified by user interaction
        if !context.coordinator.isUserInteracting {
            // Update zoom scale if it differs significantly from binding
            if abs(uiView.zoomScale - currentScale) > 0.01 {
                uiView.setZoomScale(currentScale, animated: false)
            }
            
            // Update content offset if it differs significantly from binding
            let offsetDiff = sqrt(pow(uiView.contentOffset.x - contentOffset.x, 2) + 
                                 pow(uiView.contentOffset.y - contentOffset.y, 2))
            if offsetDiff > 1.0 {
                uiView.setContentOffset(contentOffset, animated: false)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate, UIGestureRecognizerDelegate {
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
            // Full tile refresh by reassigning drawing
            if let canvas = canvasView {
                let current = canvas.drawing
                canvas.drawing = current
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            isUserInteracting = false
            // Full tile refresh by reassigning drawing
            if let canvas = canvasView {
                let current = canvas.drawing
                canvas.drawing = current
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateZoomOffset(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateZoomOffset(scrollView)
        }

        private func updateZoomOffset(_ scrollView: UIScrollView) {
            guard !isUpdatingZoom else { return }
            isUpdatingZoom = true
            
            // Use transaction to suppress the warning while keeping synchronous behavior
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.parent.contentOffset = scrollView.contentOffset
                self.parent.currentScale = scrollView.zoomScale
            }
            
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

            // MARK: - Gesture Recognizers

            @objc func handleTwoFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
                guard gestureRecognizer.state == .ended else { return }
                guard let canvas = canvasView else { return }
                
                // Perform undo
                if let undoManager = canvas.undoManager, undoManager.canUndo {
                    undoManager.undo()
                }
            }

            @objc func handleThreeFingerTap(_ gestureRecognizer: UITapGestureRecognizer) {
                guard gestureRecognizer.state == .ended else { return }
                guard let canvas = canvasView else { return }
                
                // Perform redo
                if let undoManager = canvas.undoManager, undoManager.canRedo {
                    undoManager.redo()
                }
            }

            // MARK: - UIGestureRecognizerDelegate
            
            // Allow our gesture to be recognized simultaneously with system gestures
            func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
                return true
            }

            deinit {
                drawingObserver?.invalidate()
            }
    }
}


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
