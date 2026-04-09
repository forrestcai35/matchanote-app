import SwiftUI

// MARK: - Matcha UI Constants
struct MatchaUI {
    // Animation constants
    struct Animation {
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
        static let enterDelay: Double = 0.1
        static let staggerDelay: Double = 0.1

        static var spring: SwiftUI.Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }

        static func springWithDelay(_ delay: Double) -> SwiftUI.Animation {
            spring.delay(delay)
        }
    }

    // Styling constants
    struct Style {
        static let cardCornerRadius: Double = 16
        static let itemCornerRadius: Double = 12
        static let cardPadding: Double = 20
        static let sectionSpacing: Double = 32
        static let itemSpacing: Double = 16
    }
}

// MARK: - Segmented Width Slider
struct SegmentedWidthSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let icon: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var isDragging = false

    // Width presets based on range (pen vs marker)
    private var widthPresets: [CGFloat] {
        // If range includes values above 10, use marker presets
        if range.upperBound > 10 {
            return [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
        } else {
            // Pen presets
            return [0.3, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 6]
        }
    }

    // Map current value to nearest preset
    private var currentPresetIndex: Int {
        let distances = widthPresets.map { abs($0 - value) }
        return distances.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    // Visual diameter for each preset based on index (1-12)
    private func circleSize(for index: Int) -> CGFloat {
        let minSize: CGFloat = 8
        let maxSize: CGFloat = 28
        let fraction = CGFloat(index) / CGFloat(widthPresets.count - 1)
        return minSize + fraction * (maxSize - minSize)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // Circle indicators with equal spacing (vertical ovals in fixed-width containers)
                HStack(spacing: 4) {
                    ForEach(Array(widthPresets.enumerated()), id: \.offset) { index, width in
                        ZStack {
                            // Size-based vertical oval
                            Ellipse()
                                .fill(index <= currentPresetIndex ? Color.matchalight_dark : Color.gray)
                                .frame(width: circleSize(for: index) * 0.7, height: circleSize(for: index))
                        }
                        .frame(width: 28, height: 30)
                    }
                }
                .frame(height: 30)

                // Draggable slider track overlapping circles
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let containerWidth: CGFloat = 28

                    // Track spans from center of first oval to center of last oval
                    let trackWidth = totalWidth - containerWidth
                    let startOffset = containerWidth / 2

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: trackWidth, height: 4)
                            .offset(x: startOffset)

                        // Filled track up to current position
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.matchalight_dark)
                            .frame(
                                width: trackWidth * CGFloat(currentPresetIndex) / CGFloat(widthPresets.count - 1),
                                height: 4
                            )
                            .offset(x: startOffset)
                    }
                    .frame(height: 4)
                    .contentShape(Rectangle().size(width: 1000, height: 30))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let position = max(0, min(gesture.location.x, totalWidth))
                                let adjustedPosition = max(0, position - startOffset)
                                let fraction = adjustedPosition / trackWidth
                                let index = Int(round(fraction * CGFloat(widthPresets.count - 1)))
                                let clampedIndex = max(0, min(widthPresets.count - 1, index))
                                value = widthPresets[clampedIndex]
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                .frame(height: 4)
                .offset(y: -13)
            }
            .frame(height: 30)
            .padding(.horizontal, 12)

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.jost(.caption()))
                    .foregroundColor(.gray)
                Text("Size: \(currentPresetIndex + 1)")
                    .font(.jost(.caption()))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(width: 420, height: 70)
    }
}
