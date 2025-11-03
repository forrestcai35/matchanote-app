import Foundation

/// Centralized zoom-related constants for note canvas views
/// This ensures consistency across all zoom operations and prevents duplicate definitions
enum ZoomConstants {
    /// Initial zoom level when first loading a note (slightly less than 1.0 for small margin)
    static let initialFitZoom: CGFloat = 0.95

    /// Minimum allowed zoom level (relative to fit-to-screen)
    static let minZoom: CGFloat = 0.75

    /// Maximum allowed zoom level (relative to fit-to-screen)
    static let maxZoom: CGFloat = 7.0

    /// Zoom threshold above which page boundary indicators are shown
    static let boundaryIndicatorThreshold: CGFloat = 1.5
}
