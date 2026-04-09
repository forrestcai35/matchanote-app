import Foundation
import PencilKit
import SwiftUI

class AutoStrokeRecognitionManager_v2: NSObject, ObservableObject {
    private let strokeRecognizer = StrokeRecognizer()
    private weak var canvasView: PKCanvasView?
    private var lastProcessedStrokeCount = 0
    private var isPerformingProgrammaticChange = false

    // When true, only replace strokes recognized as straight lines
    @Published var restrictToLinesOnly: Bool = false


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
        // Fix potential memory leak: Remove all observers and invalidate any pending tasks
        NotificationCenter.default.removeObserver(self)
        canvasView = nil // Break weak reference
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

        // Skip processing during programmatic changes (shape replacement or undo)
        guard !isPerformingProgrammaticChange else { return }

        let currentStrokeCount = canvas.drawing.strokes.count

        // If stroke count decreased (undo happened), sync the count without processing
        if currentStrokeCount < lastProcessedStrokeCount {
            lastProcessedStrokeCount = currentStrokeCount
            return
        }

        // Only process new strokes (when count increased)
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
        return inkType == .pen || inkType == .marker || inkType == .monoline
    }

    private func performImmediateRecognition(_ stroke: PKStroke) {
        // PERFORMANCE OPTIMIZED: Move heavy recognition to background thread
        // Fix: Use lower priority to avoid blocking build processes
        Task(priority: .utility) {
            let points = convertStrokeToPoints(stroke)
            let result = strokeRecognizer.recognize(points: points)

            // Only update UI if recognition was successful and canvas still exists
            let isAllowedShape = (!self.restrictToLinesOnly) || (result.shapeName == "line")
            if result.confidence >= confidenceThreshold && result.shapeName != "unknown" && isAllowedShape {
                await MainActor.run {
                    // Check canvas still exists before processing
                    guard canvasView != nil else { return }
                    performAutoReplacement(originalStroke: stroke, detectedShape: result.shapeName)
                }
            }
        }
    }



    private func performAutoReplacement(originalStroke: PKStroke, detectedShape: String) {
        guard let canvas = canvasView else { return }

        if let perfectStrokes = createPerfectShape(detectedShape, from: originalStroke) {
            // Set flag to prevent processing drawing changes
            isPerformingProgrammaticChange = true

            // STEP 1: Consume PencilKit's automatic undo by undoing it
            // This removes the rough stroke and consumes the undo entry from the stack
            canvas.undoManager?.undo()

            // Capture the state AFTER undoing (no rough stroke)
            let drawingBeforeShape = canvas.drawing
            lastProcessedStrokeCount = drawingBeforeShape.strokes.count

            // STEP 2: Add the perfect shape(s) - could be multiple strokes!
            var newStrokes = Array(drawingBeforeShape.strokes)
            newStrokes.append(contentsOf: perfectStrokes)
            let drawingWithShape = PKDrawing(strokes: newStrokes)

            // STEP 3: Apply the drawing WITHOUT PencilKit registering undo
            canvas.undoManager?.disableUndoRegistration()
            canvas.drawing = drawingWithShape
            lastProcessedStrokeCount = drawingWithShape.strokes.count
            canvas.undoManager?.enableUndoRegistration()

            // STEP 4: Register the initial undo action
            registerShapeUndoRedo(canvas: canvas, drawingWithShape: drawingWithShape, drawingBeforeShape: drawingBeforeShape)

            isPerformingProgrammaticChange = false
        }
    }

    // Helper function to register mutually recursive undo/redo actions
    private func registerShapeUndoRedo(canvas: PKCanvasView, drawingWithShape: PKDrawing, drawingBeforeShape: PKDrawing) {
        canvas.undoManager?.registerUndo(withTarget: self) { [weak canvas] target in
            guard let canvas = canvas else { return }
            target.isPerformingProgrammaticChange = true
            canvas.drawing = drawingBeforeShape
            target.lastProcessedStrokeCount = drawingBeforeShape.strokes.count
            target.isPerformingProgrammaticChange = false

            // Register the redo action (which will re-register undo)
            target.registerShapeRedoUndo(canvas: canvas, drawingWithShape: drawingWithShape, drawingBeforeShape: drawingBeforeShape)
        }
        canvas.undoManager?.setActionName("Draw Shape")
    }

    // Helper function to register redo action that re-registers undo
    private func registerShapeRedoUndo(canvas: PKCanvasView, drawingWithShape: PKDrawing, drawingBeforeShape: PKDrawing) {
        canvas.undoManager?.registerUndo(withTarget: self) { [weak canvas] target in
            guard let canvas = canvas else { return }
            target.isPerformingProgrammaticChange = true
            canvas.drawing = drawingWithShape
            target.lastProcessedStrokeCount = drawingWithShape.strokes.count
            target.isPerformingProgrammaticChange = false

            // Register the undo action again (which will re-register redo)
            target.registerShapeUndoRedo(canvas: canvas, drawingWithShape: drawingWithShape, drawingBeforeShape: drawingBeforeShape)
        }
        canvas.undoManager?.setActionName("Draw Shape")
    }


    private func convertStrokeToPoints(_ stroke: PKStroke) -> [CGPoint] {
        var points: [CGPoint] = []
        let path = stroke.path
        for i in 0..<path.count {
            points.append(path[i].location)
        }
        return points
    }

    private func createPerfectShape(_ shapeName: String, from stroke: PKStroke) -> [PKStroke]? {
        switch shapeName.lowercased() {
        case "circle":
            if let s = createPerfectCircle(from: stroke) { return [s] }
        case "ellipse":
            if let s = createPerfectEllipse(from: stroke) { return [s] }
        case "rectangle":
            if let s = createPerfectRectangle(from: stroke) { return [s] }
        case "triangle":
            if let s = createPerfectTriangle(from: stroke) { return [s] }
        case "line":
            if let s = createPerfectLine(from: stroke) { return [s] }
        case "angle":
            return createPerfectAngledLines(from: stroke)
        default:
            return nil
        }
        return nil
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

    private func createPerfectEllipse(from stroke: PKStroke) -> PKStroke? {
        let points = convertStrokeToPoints(stroke)
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let radiusX = (maxX - minX) / 2
        let radiusY = (maxY - minY) / 2

        var ellipsePoints: [PKStrokePoint] = []
        let pointCount = 32
        let originalPoint = stroke.path[0]

        for i in 0...pointCount {
            let angle = Double(i) * 2.0 * .pi / Double(pointCount)
            let x = center.x + radiusX * cos(angle)
            let y = center.y + radiusY * sin(angle)

            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: originalPoint.size,
                opacity: originalPoint.opacity,
                force: originalPoint.force,
                azimuth: originalPoint.azimuth,
                altitude: originalPoint.altitude
            )
            ellipsePoints.append(point)
        }

        let path = PKStrokePath(controlPoints: ellipsePoints, creationDate: Date())
        return PKStroke(ink: stroke.ink, path: path)
    }

    private func createPerfectAngledLines(from stroke: PKStroke) -> [PKStroke]? {
        let points = convertStrokeToPoints(stroke)
        guard points.count >= 5 else { return nil }

        let windowSize = max(3, points.count / 10)

        // Ensure we have enough points for the window
        guard points.count >= 2 * windowSize + 1 else {
            return nil
        }

        // Find the corner point (where the angle changes most)
        var maxAngleChange = 0.0
        var cornerIndex = -1

        let startIdx = windowSize
        let endIdx = points.count - windowSize

        // Validate range before loop to prevent crash
        guard startIdx < endIdx else {
            return nil
        }

        for i in startIdx..<endIdx {
            let prev = points[i - windowSize]
            let curr = points[i]
            let next = points[i + windowSize]

            let v1 = CGPoint(x: curr.x - prev.x, y: curr.y - prev.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)

            let angle = angleBetween(v1, v2)

            if angle > maxAngleChange {
                maxAngleChange = angle
                cornerIndex = i
            }
        }

        guard cornerIndex > 0 else { return nil }

        // Get the three key points: start, corner, end
        let startPoint = points.first!
        let cornerPoint = points[cornerIndex]
        let endPoint = points.last!

        let originalPoint = stroke.path[0]
        let pointsPerLine = 8

        // Create FIRST LINE: start -> corner
        var firstLinePoints: [PKStrokePoint] = []
        for i in 0..<pointsPerLine {
            let t = Double(i) / Double(pointsPerLine - 1)
            let x = startPoint.x + CGFloat(t) * (cornerPoint.x - startPoint.x)
            let y = startPoint.y + CGFloat(t) * (cornerPoint.y - startPoint.y)

            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: originalPoint.size,
                opacity: originalPoint.opacity,
                force: originalPoint.force,
                azimuth: originalPoint.azimuth,
                altitude: originalPoint.altitude
            )
            firstLinePoints.append(point)
        }

        // Create SECOND LINE: corner -> end
        var secondLinePoints: [PKStrokePoint] = []
        for i in 0..<pointsPerLine {
            let t = Double(i) / Double(pointsPerLine - 1)
            let x = cornerPoint.x + CGFloat(t) * (endPoint.x - cornerPoint.x)
            let y = cornerPoint.y + CGFloat(t) * (endPoint.y - cornerPoint.y)

            let point = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.01,
                size: originalPoint.size,
                opacity: originalPoint.opacity,
                force: originalPoint.force,
                azimuth: originalPoint.azimuth,
                altitude: originalPoint.altitude
            )
            secondLinePoints.append(point)
        }

        // Create two separate strokes - this ensures a SHARP corner!
        let firstPath = PKStrokePath(controlPoints: firstLinePoints, creationDate: Date())
        let firstStroke = PKStroke(ink: stroke.ink, path: firstPath)

        let secondPath = PKStrokePath(controlPoints: secondLinePoints, creationDate: Date())
        let secondStroke = PKStroke(ink: stroke.ink, path: secondPath)

        return [firstStroke, secondStroke]
    }

    private func angleBetween(_ v1: CGPoint, _ v2: CGPoint) -> Double {
        let d1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let d2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        guard d1 > 0 && d2 > 0 else { return 0 }

        let cosAngle = (v1.x * v2.x + v1.y * v2.y) / (d1 * d2)
        let clampedCosAngle = max(-1.0, min(1.0, cosAngle))
        return acos(clampedCosAngle)
    }
}
