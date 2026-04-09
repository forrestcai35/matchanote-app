import SwiftUI

/// A reusable text component with shimmer animation effect
/// Applies the shimmer gradient animation to text content
struct ShimmeringText: View {
    let text: String
    let font: Font
    let baseColor: Color
    
    init(
        _ text: String,
        font: Font = .jost(.caption()),
        baseColor: Color = .secondary
    ) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(baseColor)
            .shimmer()
    }
}

// MARK: - Preview
#if DEBUG
struct ShimmeringText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ShimmeringText("Thinking...")
            
            ShimmeringText(
                "Loading content...",
                font: .jost(.body()),
                baseColor: .primary
            )
            
            ShimmeringText(
                "Processing...",
                font: .jost(.title3()),
                baseColor: .matchalight_light
            )
        }
        .padding()
    }
}
#endif



