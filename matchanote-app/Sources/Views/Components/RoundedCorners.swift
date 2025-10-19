import SwiftUI

// Custom shape for rounded corners for Tabbarview
struct RoundedCorners: Shape {
  var topLeft: CGFloat = 0
  var topRight: CGFloat = 0
  var bottomLeft: CGFloat = 0
  var bottomRight: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let width = rect.size.width
    let height = rect.size.height

    // Top left corner
    path.move(to: CGPoint(x: 0, y: topLeft))
    path.addQuadCurve(to: CGPoint(x: topLeft, y: 0), control: CGPoint(x: 0, y: 0))

    // Top right corner
    path.addLine(to: CGPoint(x: width - topRight, y: 0))
    path.addQuadCurve(to: CGPoint(x: width, y: topRight), control: CGPoint(x: width, y: 0))

    // Bottom right corner
    path.addLine(to: CGPoint(x: width, y: height - bottomRight))
    path.addQuadCurve(
      to: CGPoint(x: width - bottomRight, y: height), control: CGPoint(x: width, y: height))

    // Bottom left corner
    path.addLine(to: CGPoint(x: bottomLeft, y: height))
    path.addQuadCurve(to: CGPoint(x: 0, y: height - bottomLeft), control: CGPoint(x: 0, y: height))

    path.closeSubpath()

    return path
  }
}
