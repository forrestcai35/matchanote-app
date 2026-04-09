import SwiftUI

// MARK: - Shimmer Effect ViewModifier

/// A shimmer effect that sweeps a gradient across content
/// Based on the gradient masking technique with animated start/end points
/// Optimized for performance with drawingGroup() and reduced animation complexity
public struct Shimmer: ViewModifier {

    @State private var isInitialState: Bool = true

    public func body(content: Content) -> some View {
        content
            .mask {
                LinearGradient(
                    gradient: .init(colors: [
                        Color(red: 0.4, green: 0.7, blue: 0.3).opacity(0.3),  // Matcha green (dim)
                        Color(red: 0.4, green: 0.7, blue: 0.3),                // Matcha green (bright)
                        Color(red: 0.3, green: 0.6, blue: 0.9),                // Premium blue (bright)
                        Color(red: 0.3, green: 0.6, blue: 0.9).opacity(0.3)   // Premium blue (dim)
                    ]),
                    startPoint: (isInitialState ? .init(x: -0.3, y: -0.3) : .init(x: 1, y: 1)),
                    endPoint: (isInitialState ? .init(x: 0, y: 0) : .init(x: 1.3, y: 1.3))
                )
            }
            .drawingGroup()  // Optimize rendering by using Metal rendering
            .animation(.linear(duration: 1.5).delay(0.25).repeatForever(autoreverses: false), value: isInitialState)
            .onAppear {
                isInitialState = false
            }
    }
}

// MARK: - View Extension for Convenience

extension View {
    /// Applies a shimmer effect to the view
    /// - Returns: A view with a sweeping gradient shimmer animation
    public func shimmer() -> some View {
        self.modifier(Shimmer())
    }
}
