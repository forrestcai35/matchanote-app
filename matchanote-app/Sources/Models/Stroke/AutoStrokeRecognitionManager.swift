import Foundation
import PencilKit
import SwiftUI

class AutoStrokeRecognitionManager_v2: NSObject, ObservableObject {
    private let strokeRecognizer = StrokeRecognizer()
    private weak var canvasView: PKCanvasView?
    private var longPressTimer: Timer?
    private var lastStrokeEndTime: Date?
    private var lastStrokeEndPosition: CGPoint?
    private var isMonitoringStroke = false
    private var currentStroke: PKStroke?
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
    }

    private func loadUserDefaults() {
        isEnabled = UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionEnabled") as? Bool ?? true
        longPressThreshold = UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionLongPressThreshold") as? Double ?? 1.0
        sensitivity = Float(UserDefaults.standard.object(forKey: "tool.autoStrokeRecognitionSensitivity_v2") as? Double ?? 0.8)
    }

    func attachToCanvas(_ canvas: PKCanvasView) {
        detachFromCanvas()
        self.canvasView = canvas
        // Initialize with current stroke count to avoid triggering on existing strokes
        lastProcessedStrokeCount = canvas.drawing.strokes.count
    }

    func detachFromCanvas() {
        resetMonitoring()
        lastProcessedStrokeCount = 0
    }

    // Called from toolbar when drawing changes
    func onDrawingChanged() {
        guard let canvas = canvasView, isEnabled else {
            print("DEBUG: Guard failed - canvas: \(canvasView != nil), enabled: \(isEnabled)")
            return
        }

        let currentStrokeCount = canvas.drawing.strokes.count
        print("DEBUG: Stroke count - current: \(currentStrokeCount), last processed: \(lastProcessedStrokeCount)")

        guard currentStrokeCount > lastProcessedStrokeCount else {
            print("DEBUG: No new strokes, returning")
            return
        }

        lastProcessedStrokeCount = currentStrokeCount
        print("DEBUG: Updated lastProcessedStrokeCount to \(currentStrokeCount)")

        guard let lastStroke = canvas.drawing.strokes.last else {
            print("DEBUG: No last stroke found")
            return
        }

        if isDrawingTool(lastStroke) {
            print("DEBUG: Starting monitoring for drawing tool stroke")
            startMonitoringForLongPress(lastStroke)
        } else {
            print("DEBUG: Not a drawing tool, resetting monitoring")
            resetMonitoring()
        }
    }

    private func startMonitoringForLongPress(_ stroke: PKStroke) {
        print("DEBUG: Starting monitoring - isEnabled: \(isEnabled)")
        guard isEnabled else { return }
        guard isDrawingTool(stroke) else { return }

        let strokePath = stroke.path
        guard strokePath.count > 0 else {
            print("DEBUG: Stroke path is empty")
            return
        }

        // Reset any existing monitoring first
        resetMonitoring()

        let endPoint = strokePath[strokePath.count - 1]
        lastStrokeEndPosition = endPoint.location
        lastStrokeEndTime = Date()
        isMonitoringStroke = true
        currentStroke = stroke

        print("DEBUG: Set up monitoring, starting timer for \(longPressThreshold) seconds")
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { [weak self] _ in
            print("DEBUG: Timer fired!")
            self?.checkForAutoRecognition()
        }
    }

    private func isDrawingTool(_ stroke: PKStroke) -> Bool {
        let inkType = stroke.ink.inkType
        return inkType == .pen || inkType == .marker
    }

    private func performRecognition(_ stroke: PKStroke) {
        print("DEBUG: performRecognition called")
        let points = convertStrokeToPoints(stroke)
        let result = strokeRecognizer.recognize(points: points)

        print("DEBUG: Recognition result - shape: \(result.shapeName), confidence: \(result.confidence), threshold: \(confidenceThreshold)")

        if result.confidence >= confidenceThreshold && result.shapeName != "unknown" {
            print("DEBUG: Recognition successful, performing replacement")
            performAutoReplacement(originalStroke: stroke, detectedShape: result.shapeName)
        } else {
            print("DEBUG: Recognition failed - confidence too low or unknown shape")
        }

        resetMonitoring()
    }

    private func checkForAutoRecognition() {
        print("DEBUG: checkForAutoRecognition called")
        print("DEBUG: isMonitoringStroke: \(isMonitoringStroke)")
        print("DEBUG: lastStrokeEndTime: \(lastStrokeEndTime?.description ?? "nil")")
        print("DEBUG: currentStroke: \(currentStroke != nil)")

        guard isMonitoringStroke,
              let endTime = lastStrokeEndTime,
              let stroke = currentStroke,
              Date().timeIntervalSince(endTime) >= longPressThreshold else {
            print("DEBUG: Guard failed in checkForAutoRecognition")
            resetMonitoring()
            return
        }

        print("DEBUG: All guards passed, performing recognition")
        performRecognition(stroke)
    }

    private func performAutoReplacement(originalStroke: PKStroke, detectedShape: String) {
        guard let canvas = canvasView else { return }

        if let perfectStroke = createPerfectShape(detectedShape, from: originalStroke) {
            canvas.undoManager?.beginUndoGrouping()

            // Use a simpler approach: replace the last stroke (most recently drawn)
            var drawing = canvas.drawing
            var strokes = Array(drawing.strokes)

            // The stroke we want to replace should be the last one since we monitor immediately after drawing
            if !strokes.isEmpty {
                strokes.removeLast()
                strokes.append(perfectStroke)
                drawing = PKDrawing(strokes: strokes)

                canvas.drawing = drawing

                // Update our stroke count to account for the replacement
                // (stroke count stays the same, but we need to track it properly)
                lastProcessedStrokeCount = canvas.drawing.strokes.count
                print("DEBUG: Stroke replaced successfully, updated lastProcessedStrokeCount to \(lastProcessedStrokeCount)")
            }

            canvas.undoManager?.endUndoGrouping()
            canvas.undoManager?.setActionName("Auto Shape Recognition")
        }
    }

    private func resetMonitoring() {
        print("DEBUG: resetMonitoring called")
        longPressTimer?.invalidate()
        longPressTimer = nil
        isMonitoringStroke = false
        lastStrokeEndTime = nil
        lastStrokeEndPosition = nil
        currentStroke = nil
        print("DEBUG: Monitoring state reset complete")
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

