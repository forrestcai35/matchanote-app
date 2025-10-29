import SwiftUI

struct RotationHandle: View {
    let center: CGPoint
    let initialVector: CGVector
    let coordinateSpaceName: String
    let onBegan: () -> Void
    let onChanged: (Double) -> Void
    let onEnded: (Double) -> Void

    @State private var hasBeganGesture = false

    private var baseAngle: Double {
        atan2(initialVector.dy, initialVector.dx)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 28, height: 28)

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
        }
        .frame(width: 64, height: 64)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                .onChanged { value in
                    if !hasBeganGesture {
                        hasBeganGesture = true
                        onBegan()
                    }

                    let rotation = rotationDegrees(for: value.location)
                    onChanged(rotation)
                }
                .onEnded { value in
                    let rotation = rotationDegrees(for: value.location)
                    onEnded(rotation)
                    hasBeganGesture = false
                }
        )
    }

    private func rotationDegrees(for location: CGPoint) -> Double {
        let vector = CGVector(
            dx: location.x - center.x,
            dy: location.y - center.y
        )

        guard vector.dx != 0 || vector.dy != 0 else {
            return 0
        }

        let currentAngle = atan2(vector.dy, vector.dx)
        let rotationRadians = currentAngle - baseAngle
        let rotationDegrees = -(rotationRadians * 180 / .pi)

        return normalizeAngle(rotationDegrees)
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < -180 {
            normalized += 360
        } else if normalized > 180 {
            normalized -= 360
        }
        return normalized
    }
}
