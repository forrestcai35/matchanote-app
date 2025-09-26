import Foundation
import PencilKit
import SwiftUI

class AutoStrokeRecognitionManager_v2: NSObject, ObservableObject {
    private let strokeRecognizer = StrokeRecognizer()
    private weak var canvasView: PKCanvasView?
    private var lastProcessedStrokeCount = 0


    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "tool.autoStrokeRecognitionEnabled")
        }
    }

    @Published var longPressThreshold: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(longPressThreshold, forKey: "tool.autoStrokeRecognitionLongPressThreshold")
        }
    }

    @Published var sensitivity: Float = 0.0 {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "tool.autoStrokeRecognitionSensitivity_v2")
        }
    }

    private var confidenceThreshold: Double {
        // Convert sensitivity (0-1) to a reasonable confidence threshold
        // Lower sensitivity = higher threshold (more strict)
        // Higher sensitivity = lower threshold (more lenient)
        return max(0.1, 0.8 - Double(sensitivity) * 0.5)
    }

    override init() {
        super.init()
        loadUserDefaults()
        self.sensitivity = Float(UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionSensitivity_v2") as? Double ?? 0.8)

        // Listen for stroke completion notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(strokeCompleted(_:)),
            name: NSNotification.Name("StrokeCompleted"),
            object: nil
        )
    }

    private func loadUserDefaults() {
        isEnabled = UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionEnabled") as? Bool ?? true
        longPressThreshold = UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionLongPressThreshold") as? Double ?? 1.0
        sensitivity = Float(UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionSensitivity_v2") as? Double ?? 0.8)
    }

    func attachToCanvas(_ canvas: PKCanvasView) {
        self.canvasView = canvas
        // Initialize with current stroke count to avoid triggering on existing strokes
        lastProcessedStrokeCount = canvas.drawing.strokes.count
    }

    func detachFromCanvas() {
        self.canvasView = nil
        lastProcessedStrokeCount = 0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func strokeCompleted(_ notification: Notification) {
        guard let canvas = notification.object as? PKCanvasView,
              canvas === self.canvasView else { return }

        // Process the stroke immediately when we get the notification
        onDrawingChanged()
    }

    // Called from toolbar when drawing changes
    func onDrawingChanged() {
        guard let canvas = canvasView, isEnabled else { return }

        let currentStrokeCount = canvas.drawing.strokes.count

        guard currentStrokeCount > lastProcessedStrokeCount else {
            return
        }

        lastProcessedStrokeCount = currentStrokeCount

        guard let lastStroke = canvas.drawing.strokes.last else {
            return
        }

        if isDrawingTool(lastStroke) {
            // For shape tool, do immediate recognition
            performImmediateRecognition(lastStroke)
        }
    }


    private func isDrawingTool(_ stroke: PKStroke) -> Bool {
        let inkType = stroke.ink.inkType
        return inkType == .pen || inkType == .marker
    }

    private func performImmediateRecognition(_ stroke: PKStroke) {
        // PERFORMANCE OPTIMIZED: Move heavy recognition to background thread
        Task(priority: .userInitiated) {
            let points = convertStrokeToPoints(stroke)
            let result = strokeRecognizer.recognize(points: points)

            // Only update UI if recognition was successful
            if result.confidence >= confidenceThreshold && result.shapeName != "unknown" {
                await MainActor.run {
                    performAutoReplacement(originalStroke: stroke, detectedShape: result.shapeName)
                }
            }
        }
    }



    private func performAutoReplacement(originalStroke: PKStroke, detectedShape: String) {
        guard let canvas = canvasView else { return }

        if let perfectStroke = createPerfectShape(detectedShape, from: originalStroke) {
            // Store the current drawing state for undo
            let currentDrawing = canvas.drawing

            // Create new drawing with perfect shape
            var strokes = Array(currentDrawing.strokes)
            if !strokes.isEmpty {
                strokes.removeLast() // Remove original stroke
                strokes.append(perfectStroke) // Add perfect stroke
                let newDrawing = PKDrawing(strokes: strokes)

                // Register undo action before making the change
                canvas.undoManager?.registerUndo(withTarget: self) { [weak canvas] target in
                    guard let canvas = canvas else { return }
                    canvas.drawing = currentDrawing
                    // Update stroke count when undoing
                    target.lastProcessedStrokeCount = currentDrawing.strokes.count
                }
                canvas.undoManager?.setActionName("Shape Recognition")

                // Apply the new drawing
                canvas.drawing = newDrawing
                lastProcessedStrokeCount = newDrawing.strokes.count
            }
        }
    }


    private func convertStrokeToPoints(_ stroke: PKStroke) -> [CGPoint] {
        var points: [CGPoint] = []
        let path = stroke.path
        for i in 0..<path.count {
            points.append(path[i].location)
        }
        return points
    }

    private func createPerfectShape(_ shapeName: String, from stroke: PKStroke) -> PKStroke? {
        switch shapeName.lowercased() {
        case "circle":
            return createPerfectCircle(from: stroke)
        case "rectangle":
            return createPerfectRectangle(from: stroke)
        case "triangle":
            return createPerfectTriangle(from: stroke)
        case "line":
            return createPerfectLine(from: stroke)
        default:
            return nil
        }
    }

    private func createPerfectCircle(from stroke: PKStroke) -> PKStroke? {
        let points = convertStrokeToPoints(stroke)
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let radius = min(maxX - minX, maxY - minY) / 2

        var circlePoints: [PKStrokePoint] = []
        let pointCount = 32
        let originalPoint = stroke.path[0]

        for i in 0...pointCount {
            let angle = Double(i) * 2.0 * .pi / Double(pointCount)
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: originalPoint.size,
                opacity: originalPoint.opacity,
                force: originalPoint.force,
                azimuth: originalPoint.azimuth,
                altitude: originalPoint.altitude
            )
            circlePoints.append(point)
        }

        let path = PKStrokePath(controlPoints: circlePoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: path)
    }

    private func createPerfectLine(from stroke: PKStroke) -> PKStroke? {
        let points = convertStrokeToPoints(stroke)
        guard points.count >= 2 else { return nil }

        let startPoint = points.first!
        let endPoint = points.last!

        var linePoints: [PKStrokePoint] = []
        let pointCount = min(16, points.count / 2)
        let originalPoint = stroke.path[0]

        for i in 0..<pointCount {
            let t = Double(i) / Double(pointCount - 1)
            let x = startPoint.x + CGFloat(t) * (endPoint.x - startPoint.x)
            let y = startPoint.y + CGFloat(t) * (endPoint.y - startPoint.y)

            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: originalPoint.size,
                opacity: originalPoint.opacity,
                force: originalPoint.force,
                azimuth: originalPoint.azimuth,
                altitude: originalPoint.altitude
            )
            linePoints.append(point)
        }

        let path = PKStrokePath(controlPoints: linePoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: path)
    }

    private func createPerfectRectangle(from stroke: PKStroke) -> PKStroke? {
        let points = convertStrokeToPoints(stroke)
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        let corners = [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: minX, y: minY)
        ]

        var rectPoints: [PKStrokePoint] = []
        let pointsPerSide = 8
        let originalPoint = stroke.path[0]

        for i in 0..<corners.count - 1 {
            let startCorner = corners[i]
            let endCorner = corners[i + 1]

            for j in 0..<pointsPerSide {
                let t = Double(j) / Double(pointsPerSide - 1)
                let x = startCorner.x + CGFloat(t) * (endCorner.x - startCorner.x)
                let y = startCorner.y + CGFloat(t) * (endCorner.y - startCorner.y)

                let point = PKStrokePoint(
                    location: CGPoint(x: x, y: y),
                    timeOffset: TimeInterval(rectPoints.count) * 0.01,
                    size: originalPoint.size,
                    opacity: originalPoint.opacity,
                    force: originalPoint.force,
                    azimuth: originalPoint.azimuth,
                    altitude: originalPoint.altitude
                )
                rectPoints.append(point)
            }
        }

        let path = PKStrokePath(controlPoints: rectPoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: path)
    }

    private func createPerfectTriangle(from stroke: PKStroke) -> PKStroke? {
        let points = convertStrokeToPoints(stroke)
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        let centerX = (minX + maxX) / 2

        let vertices = [
            CGPoint(x: centerX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: centerX, y: minY)
        ]

        var trianglePoints: [PKStrokePoint] = []
        let pointsPerSide = 10
        let originalPoint = stroke.path[0]

        for i in 0..<vertices.count - 1 {
            let startVertex = vertices[i]
            let endVertex = vertices[i + 1]

            for j in 0..<pointsPerSide {
                let t = Double(j) / Double(pointsPerSide - 1)
                let x = startVertex.x + CGFloat(t) * (endVertex.x - startVertex.x)
                let y = startVertex.y + CGFloat(t) * (endVertex.y - startVertex.y)

                let point = PKStrokePoint(
                    location: CGPoint(x: x, y: y),
                    timeOffset: TimeInterval(trianglePoints.count) * 0.01,
                    size: originalPoint.size,
                    opacity: originalPoint.opacity,
                    force: originalPoint.force,
                    azimuth: originalPoint.azimuth,
                    altitude: originalPoint.altitude
                )
                trianglePoints.append(point)
            }
        }

        let path = PKStrokePath(controlPoints: trianglePoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: path)
    }
}

