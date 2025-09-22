import PencilKit
import Foundation
import CoreGraphics

// MARK: - Shape Recognition Engine
class ShapeRecognitionEngine {

    // MARK: - Configuration
    struct Config {
        static let minDistanceThreshold: CGFloat = 10.0
        static let lineAngleTolerance: CGFloat = 15.0 // degrees
        static let circleToleranceRatio: CGFloat = 0.15
        static let rectangleAngleTolerance: CGFloat = 20.0 // degrees
        static let minimumStrokeLength: CGFloat = 20.0
        static let snapDetectionDelay: TimeInterval = 0.5
    }

    // MARK: - Detected Shape Types
    enum DetectedShape {
        case line(start: CGPoint, end: CGPoint)
        case circle(center: CGPoint, radius: CGFloat)
        case rectangle(topLeft: CGPoint, bottomRight: CGPoint)
        case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)
        case unknown
    }

    // MARK: - Public Methods

    /// Analyzes a stroke and returns a detected shape if found
    static func recognizeShape(from stroke: PKStroke) -> DetectedShape {
        let points = extractPoints(from: stroke)

        guard points.count >= 2 else { return .unknown }

        let simplifiedPoints = simplifyPath(points: points)

        // Try to detect different shapes in order of complexity
        if let line = detectLine(points: simplifiedPoints) {
            return line
        }

        if let circle = detectCircle(points: simplifiedPoints) {
            return circle
        }

        if let rectangle = detectRectangle(points: simplifiedPoints) {
            return rectangle
        }

        if let triangle = detectTriangle(points: simplifiedPoints) {
            return triangle
        }

        return .unknown
    }

    /// Creates a perfect PKStroke from a detected shape
    static func createPerfectStroke(from shape: DetectedShape, originalStroke: PKStroke) -> PKStroke? {
        switch shape {
        case .line(let start, let end):
            return createLineStroke(from: start, to: end, originalStroke: originalStroke)
        case .circle(let center, let radius):
            return createCircleStroke(center: center, radius: radius, originalStroke: originalStroke)
        case .rectangle(let topLeft, let bottomRight):
            return createRectangleStroke(topLeft: topLeft, bottomRight: bottomRight, originalStroke: originalStroke)
        case .triangle(let p1, let p2, let p3):
            return createTriangleStroke(p1: p1, p2: p2, p3: p3, originalStroke: originalStroke)
        case .unknown:
            return nil
        }
    }

    // MARK: - Private Helper Methods

    private static func extractPoints(from stroke: PKStroke) -> [CGPoint] {
        var points: [CGPoint] = []
        let path = stroke.path

        for i in 0..<path.count {
            let strokePoint = path[i]
            points.append(strokePoint.location)
        }

        return points
    }

    private static func simplifyPath(points: [CGPoint], tolerance: CGFloat = 5.0) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return douglasPeucker(points: points, epsilon: tolerance)
    }

    // MARK: - Douglas-Peucker Algorithm Implementation
    private static func douglasPeucker(points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        let start = points.first!
        let end = points.last!

        var maxDistance: CGFloat = 0
        var maxIndex = 0

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > epsilon {
            let leftPart = douglasPeucker(points: Array(points[0...maxIndex]), epsilon: epsilon)
            let rightPart = douglasPeucker(points: Array(points[maxIndex..<points.count]), epsilon: epsilon)

            // Remove duplicate point at connection
            return leftPart + rightPart.dropFirst()
        } else {
            return [start, end]
        }
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        if dx == 0 && dy == 0 {
            return distance(from: point, to: lineStart)
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)

        return distance(from: point, to: projection)
    }

    // MARK: - Shape Detection Methods

    private static func detectLine(points: [CGPoint]) -> DetectedShape? {
        guard points.count >= 2 else { return nil }

        let start = points.first!
        let end = points.last!
        let totalLength = distance(from: start, to: end)

        guard totalLength > Config.minimumStrokeLength else { return nil }

        // Check if all points are reasonably close to the line
        var maxDeviation: CGFloat = 0
        for point in points {
            let deviation = perpendicularDistance(point: point, lineStart: start, lineEnd: end)
            maxDeviation = max(maxDeviation, deviation)
        }

        if maxDeviation < Config.minDistanceThreshold {
            return .line(start: start, end: end)
        }

        return nil
    }

    private static func detectCircle(points: [CGPoint]) -> DetectedShape? {
        guard points.count >= 4 else { return nil }

        // Check if start and end points are close (closed curve)
        let startPoint = points.first!
        let endPoint = points.last!
        let closureDistance = distance(from: startPoint, to: endPoint)

        let averageRadius = calculateAverageDistanceFromCenter(points: points)

        if closureDistance < averageRadius * 0.3 { // Closed curve
            let center = calculateCentroid(points: points)
            let avgRadius = calculateAverageDistanceFromCenter(points: points, center: center)

            // Check how consistent the radius is
            var radiusVariance: CGFloat = 0
            for point in points {
                let currentRadius = distance(from: point, to: center)
                radiusVariance += abs(currentRadius - avgRadius)
            }
            radiusVariance /= CGFloat(points.count)

            if radiusVariance < avgRadius * Config.circleToleranceRatio {
                return .circle(center: center, radius: avgRadius)
            }
        }

        return nil
    }

    private static func detectRectangle(points: [CGPoint]) -> DetectedShape? {
        guard points.count >= 4 else { return nil }

        // Find the bounding box
        let minX = points.map { $0.x }.min()!
        let maxX = points.map { $0.x }.max()!
        let minY = points.map { $0.y }.min()!
        let maxY = points.map { $0.y }.max()!

        let width = maxX - minX
        let height = maxY - minY

        guard width > Config.minimumStrokeLength && height > Config.minimumStrokeLength else { return nil }

        // Check if the path roughly follows rectangle edges
        let corners = [
            CGPoint(x: minX, y: minY), // top-left
            CGPoint(x: maxX, y: minY), // top-right
            CGPoint(x: maxX, y: maxY), // bottom-right
            CGPoint(x: minX, y: maxY)  // bottom-left
        ]

        // Check if points generally follow the rectangle perimeter
        var deviationCount = 0
        for point in points {
            let minDistanceToEdge = min(
                abs(point.x - minX), // left edge
                abs(point.x - maxX), // right edge
                abs(point.y - minY), // top edge
                abs(point.y - maxY)  // bottom edge
            )

            if minDistanceToEdge > Config.minDistanceThreshold {
                deviationCount += 1
            }
        }

        if deviationCount < points.count / 3 { // Allow some deviation
            return .rectangle(topLeft: CGPoint(x: minX, y: minY), bottomRight: CGPoint(x: maxX, y: maxY))
        }

        return nil
    }

    private static func detectTriangle(points: [CGPoint]) -> DetectedShape? {
        guard points.count >= 3 else { return nil }

        let simplified = douglasPeucker(points: points, epsilon: 10.0)

        if simplified.count == 3 || simplified.count == 4 {
            // If we have 4 points, check if first and last are the same (closed triangle)
            if simplified.count == 4 {
                let start = simplified.first!
                let end = simplified.last!
                if distance(from: start, to: end) < Config.minDistanceThreshold {
                    let trianglePoints = Array(simplified.prefix(3))
                    return .triangle(p1: trianglePoints[0], p2: trianglePoints[1], p3: trianglePoints[2])
                }
            } else {
                return .triangle(p1: simplified[0], p2: simplified[1], p3: simplified[2])
            }
        }

        return nil
    }

    // MARK: - Stroke Creation Methods

    private static func createLineStroke(from start: CGPoint, to end: CGPoint, originalStroke: PKStroke) -> PKStroke {
        let controlPoints = [
            PKStrokePoint(location: start, timeOffset: 0, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: end, timeOffset: 0.1, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2)
        ]
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())

        return PKStroke(ink: originalStroke.ink, path: path)
    }

    private static func createCircleStroke(center: CGPoint, radius: CGFloat, originalStroke: PKStroke) -> PKStroke {
        var points: [PKStrokePoint] = []
        let numberOfPoints = max(20, Int(radius / 5)) // More points for larger circles

        for i in 0...numberOfPoints {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(numberOfPoints)
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            let location = CGPoint(x: x, y: y)
            let timeOffset = Double(i) / Double(numberOfPoints) * 2.0

            points.append(PKStrokePoint(location: location, timeOffset: timeOffset, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2))
        }

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    private static func createRectangleStroke(topLeft: CGPoint, bottomRight: CGPoint, originalStroke: PKStroke) -> PKStroke {
        let topRight = CGPoint(x: bottomRight.x, y: topLeft.y)
        let bottomLeft = CGPoint(x: topLeft.x, y: bottomRight.y)

        let points = [
            PKStrokePoint(location: topLeft, timeOffset: 0.0, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: topRight, timeOffset: 0.25, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: bottomRight, timeOffset: 0.5, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: bottomLeft, timeOffset: 0.75, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: topLeft, timeOffset: 1.0, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2)
        ]

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    private static func createTriangleStroke(p1: CGPoint, p2: CGPoint, p3: CGPoint, originalStroke: PKStroke) -> PKStroke {
        let points = [
            PKStrokePoint(location: p1, timeOffset: 0.0, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: p2, timeOffset: 0.33, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: p3, timeOffset: 0.66, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2),
            PKStrokePoint(location: p1, timeOffset: 1.0, size: CGSize(width: 5, height: 5), opacity: 1.0, force: 1.0, azimuth: 0, altitude: .pi/2)
        ]

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    // MARK: - Utility Methods

    private static func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func calculateCentroid(points: [CGPoint]) -> CGPoint {
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private static func calculateAverageDistanceFromCenter(points: [CGPoint], center: CGPoint? = nil) -> CGFloat {
        let centerPoint = center ?? calculateCentroid(points: points)
        let totalDistance = points.reduce(0) { sum, point in
            sum + distance(from: point, to: centerPoint)
        }
        return totalDistance / CGFloat(points.count)
    }
}

// MARK: - Shape Recognition Manager
class ShapeRecognitionManager: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var recognitionSensitivity: Float = 0.5 // 0.0 = very sensitive, 1.0 = less sensitive

    private var pendingRecognitionTimer: Timer?
    private weak var canvasView: PKCanvasView?

    func configure(with canvasView: PKCanvasView) {
        self.canvasView = canvasView
    }

    func processStrokeForRecognition(_ stroke: PKStroke, in drawing: PKDrawing) {
        guard isEnabled else { return }

        // Cancel any pending recognition
        pendingRecognitionTimer?.invalidate()

        // Start a timer to delay recognition (gives user time to continue drawing)
        pendingRecognitionTimer = Timer.scheduledTimer(withTimeInterval: ShapeRecognitionEngine.Config.snapDetectionDelay, repeats: false) { [weak self] _ in
            self?.performRecognition(for: stroke, in: drawing)
        }
    }

    private func performRecognition(for stroke: PKStroke, in drawing: PKDrawing) {
        let detectedShape = ShapeRecognitionEngine.recognizeShape(from: stroke)

        if case .unknown = detectedShape {
            return // No shape detected
        }

        // Create perfect stroke from detected shape
        if let perfectStroke = ShapeRecognitionEngine.createPerfectStroke(from: detectedShape, originalStroke: stroke) {
            // Replace the original stroke with the perfect one
            DispatchQueue.main.async { [weak self] in
                self?.replaceStroke(original: stroke, with: perfectStroke, in: drawing)
            }
        }
    }

    private func replaceStroke(original: PKStroke, with perfect: PKStroke, in drawing: PKDrawing) {
        guard let canvasView = canvasView else { return }

        // Create a new drawing with the stroke replaced
        var strokes = drawing.strokes

        // Since we can't easily compare PKStroke objects, we'll replace the last stroke
        // which should be the one that was just drawn and triggered recognition
        if !strokes.isEmpty {
            strokes[strokes.count - 1] = perfect
            let newDrawing = PKDrawing(strokes: strokes)
            canvasView.drawing = newDrawing
        }
    }

    func cleanup() {
        pendingRecognitionTimer?.invalidate()
        pendingRecognitionTimer = nil
    }
}