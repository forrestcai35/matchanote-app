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
    var showScrollIndicators: Bool = false
    // Whether this view is the active page (in TabView mode). When false, it
    // will not push/pull unified content offsets to avoid flashing during transitions.
    var isActivePage: Bool = true

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
        canvasView.showsVerticalScrollIndicator = showScrollIndicators
        canvasView.showsHorizontalScrollIndicator = showScrollIndicators
        canvasView.backgroundColor = .clear
        canvasView.decelerationRate = .fast
        canvasView.clipsToBounds = true

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
            applyMicroZoomSync(to: canvasView)
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self

        // Apply finger drawing preference
        uiView.drawingPolicy = preferencesManager.noteEditorFingerDrawingEnabled ? .anyInput : .pencilOnly

        // Always disable drawing when textbox or photo tool is active (regardless of interaction state)
        uiView.drawingGestureRecognizer.isEnabled = (currentTool != .textbox && currentTool != .photo)
        
        // Disable native scrolling on non-active pages to avoid fighting with page transitions
        uiView.isScrollEnabled = isActivePage
        
        // Synchronize zoom and offset when they change (e.g., when switching pages)
        if !context.coordinator.isUserInteracting {
            // Update zoom scale if it differs significantly from binding
            if abs(uiView.zoomScale - currentScale) > 0.01 {
                uiView.setZoomScale(currentScale, animated: false)
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
        private var panWasEnabledBeforeZoom: Bool = true
        private var lastPublishedOffset: CGPoint = .zero

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
            // Reduce micro panning noise during pinch by disabling pan temporarily
            panWasEnabledBeforeZoom = scrollView.panGestureRecognizer.isEnabled
            scrollView.panGestureRecognizer.isEnabled = false
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
            // Restore pan gesture
            scrollView.panGestureRecognizer.isEnabled = panWasEnabledBeforeZoom
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
            // Ignore updates from non-active pages to prevent offset contention
            guard parent.isActivePage else { return }
            guard !isUpdatingZoom else { return }
            isUpdatingZoom = true
            
            // Use transaction to suppress the warning while keeping synchronous behavior
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // Publish offset with a small deadzone while zooming to avoid jitter from micro finger movements
                let newOffset = scrollView.contentOffset
                let threshold: CGFloat = 0.5
                let dx = abs(newOffset.x - lastPublishedOffset.x)
                let dy = abs(newOffset.y - lastPublishedOffset.y)
                if !scrollView.isZooming || dx > threshold || dy > threshold {
                    self.parent.contentOffset = newOffset
                    lastPublishedOffset = newOffset
                }
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
                        // Switch back from eraser to previous tool
                        let toolToRestore = previousTool
                        DispatchQueue.main.async {
                            self.parent.currentTool = toolToRestore
                        }
                        canvas.tool = toolToRestore.toolInstance()
                    } else {
                        // Switch to eraser
                        previousTool = currentTool
                        DispatchQueue.main.async {
                            self.parent.currentTool = .eraser
                        }
                        canvas.tool = PenTool.eraser.toolInstance()
                    }
                } else {
                    // No current tool, switch to eraser
                    previousTool = .pen
                    DispatchQueue.main.async {
                        self.parent.currentTool = .eraser
                    }
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


// MARK: - Vertical Scroll View with Zoom

// UIViewRepresentable that wraps SwiftUI content and adds zoom gesture support
// Used only in vertical scroll mode to enable zooming even in gaps between pages
struct VerticalScrollViewWithZoom<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var zoomLevel: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let unifiedFitScale: CGFloat

    init(
        zoomLevel: Binding<CGFloat>,
        minZoom: CGFloat = ZoomConstants.minZoom,
        maxZoom: CGFloat = ZoomConstants.maxZoom,
        unifiedFitScale: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self._zoomLevel = zoomLevel
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.unifiedFitScale = unifiedFitScale
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear

        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.addSubview(hostingController.view)

        // Add pinch gesture recognizer for zoom
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinchGesture.delegate = context.coordinator
        containerView.addGestureRecognizer(pinchGesture)

        context.coordinator.hostingController = hostingController
        context.coordinator.containerView = containerView

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self

        // Update hosting controller's root view
        if let hostingController = context.coordinator.hostingController {
            hostingController.rootView = content

            // Update frame to match container
            hostingController.view.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: VerticalScrollViewWithZoom
        var hostingController: UIHostingController<Content>?
        var containerView: UIView?
        private var initialZoomLevel: CGFloat = 1.0

        init(_ parent: VerticalScrollViewWithZoom) {
            self.parent = parent
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                initialZoomLevel = parent.zoomLevel

            case .changed:
                // Calculate new relative zoom level
                let newZoomLevel = initialZoomLevel * gesture.scale

                // Clamp to min/max bounds
                let clampedZoomLevel = max(parent.minZoom, min(parent.maxZoom, newZoomLevel))

                // Update binding
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    parent.zoomLevel = clampedZoomLevel
                }

            case .ended, .cancelled, .failed:
                break

            default:
                break
            }
        }

        // Allow pinch gesture to work alongside scroll view gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.hostingController?.willMove(toParent: nil)
        coordinator.hostingController?.view.removeFromSuperview()
        coordinator.hostingController?.removeFromParent()
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
