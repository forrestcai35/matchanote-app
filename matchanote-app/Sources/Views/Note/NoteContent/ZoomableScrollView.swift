import SwiftUI
import UIKit

// MARK: - Zoomable Scroll View (Legacy)

// Custom ZoomableScrollView that provides a much more natural zooming experience
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    private var minScale: CGFloat
    private var maxScale: CGFloat
    private var resetOnDoubleTap: Bool
    @Binding private var isPanEnabled: Bool

    @Binding private var currentScale: CGFloat
    @Binding private var contentOffset: CGPoint

    // Initialize with default scale binding
    init(
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 6.0,
        resetOnDoubleTap: Bool = true,
        currentScale: Binding<CGFloat> = .constant(1.0),
        contentOffset: Binding<CGPoint> = .constant(.zero),
        isPanEnabled: Binding<Bool> = .constant(true),
        @ViewBuilder content: () -> Content
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.resetOnDoubleTap = resetOnDoubleTap
        self._currentScale = currentScale
        self._contentOffset = contentOffset
        self._isPanEnabled = isPanEnabled
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        // Set up the UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxScale
        scrollView.minimumZoomScale = minScale
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        // Disable automatic safe area content inset adjustments
        scrollView.contentInsetAdjustmentBehavior = .never

        // Apply initial zoom scale from binding
        let initialScale = max(min(currentScale, maxScale), minScale)
        scrollView.zoomScale = initialScale

        // Add the SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        // CRITICAL: Disable safe area insets on hosting controller to prevent content size expansion
        // This fixes the landscape bottom margin issue where content would grow by ~12pts
        hostingController.view.insetsLayoutMarginsFromSafeArea = false

        // Store reference in coordinator for updates
        context.coordinator.hostingController = hostingController

        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear

        // Configure for lossless scaling
        hostedView.contentScaleFactor = UIScreen.main.scale
        hostedView.layer.rasterizationScale = UIScreen.main.scale
        hostedView.layer.shouldRasterize = false  // Disable rasterization to avoid blur

        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])

        // Add double-tap gesture if needed
        if resetOnDoubleTap {
            let doubleTapGesture = UITapGestureRecognizer(
                target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            scrollView.addGestureRecognizer(doubleTapGesture)
        }

        // Apply initial content offset after a brief delay to ensure layout is complete
        DispatchQueue.main.async {
            if contentOffset != .zero {
                scrollView.contentOffset = contentOffset
            } else {
                // Force centering when content offset is zero by calling zoom delegate
                context.coordinator.scrollViewDidZoom(scrollView)
            }
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the coordinator's parent reference
        context.coordinator.parent = self
        // Keep zoom enabled but disable panning when requested
        uiView.isScrollEnabled = true
        uiView.panGestureRecognizer.isEnabled = isPanEnabled

        // Update the hosting controller's rootView
        if let hostingController = context.coordinator.hostingController {
            hostingController.rootView = content
        }

        // Only update zoom scale if the user is not currently interacting with the scroll view
        // and if there's a significant difference to avoid unnecessary updates
        let clampedScale = max(min(currentScale, maxScale), minScale)
        if !context.coordinator.isUserInteracting && abs(uiView.zoomScale - clampedScale) > 0.01 {
            uiView.setZoomScale(clampedScale, animated: false)
        }

        // Handle content offset updates when not interacting
        if !context.coordinator.isUserInteracting {
            if contentOffset != .zero {
                // Apply non-zero offsets if significantly different
                let currentOffset = uiView.contentOffset
                let targetOffset = contentOffset
                let offsetDistance = sqrt(pow(currentOffset.x - targetOffset.x, 2) + pow(currentOffset.y - targetOffset.y, 2))
                if offsetDistance > 20.0 {
                    uiView.contentOffset = targetOffset
                }
            } else if uiView.contentOffset != .zero {
                // When offset is reset to .zero but scroll view is not centered, force recentering
                context.coordinator.scrollViewDidZoom(uiView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        var isUserInteracting = false
        var hostingController: UIHostingController<Content>?

        init(_ parent: ZoomableScrollView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            isUserInteracting = true
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            isUserInteracting = false
            // Update the binding after user interaction ends
            if abs(parent.currentScale - scale) > 0.01 {
                parent.currentScale = scale
            }
            // Only save content offset if it's not centered (i.e. user has scrolled)
            // Don't save offsets that are just from centering insets
            if scrollView.contentOffset != .zero {
                parent.contentOffset = scrollView.contentOffset
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserInteracting = false
                if scrollView.contentOffset != .zero {
                    parent.contentOffset = scrollView.contentOffset
                }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserInteracting = false
            if scrollView.contentOffset != .zero {
                parent.contentOffset = scrollView.contentOffset
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center content when it's smaller than the viewport, otherwise allow free scrolling
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

            // Only update binding during user interaction if the change is significant
            if isUserInteracting {
                let newScale = scrollView.zoomScale
                if abs(parent.currentScale - newScale) > 0.02 {
                    parent.currentScale = newScale
                }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Update content offset during scrolling, but only for significant changes
            if isUserInteracting {
                let currentOffset = scrollView.contentOffset
                let parentOffset = parent.contentOffset
                let offsetDistance = sqrt(pow(currentOffset.x - parentOffset.x, 2) + pow(currentOffset.y - parentOffset.y, 2))
                // Increase threshold to reduce update frequency and improve performance
                if offsetDistance > 25.0 {
                    parent.contentOffset = currentOffset
                }
            }
        }

        @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let scrollView = gestureRecognizer.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // Zoom out to minimum scale
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zoom in to a reasonable scale (halfway between min and max)
                let targetScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
                let point = gestureRecognizer.location(in: scrollView.subviews.first ?? scrollView)

                // Calculate zoom rect centered on tap point
                let zoomSize = CGSize(
                    width: scrollView.bounds.width / targetScale,
                    height: scrollView.bounds.height / targetScale
                )
                let zoomRect = CGRect(
                    x: point.x - zoomSize.width / 2,
                    y: point.y - zoomSize.height / 2,
                    width: zoomSize.width,
                    height: zoomSize.height
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
