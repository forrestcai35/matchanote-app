import Foundation
import CoreGraphics

struct UnistrokeTemplate {
    let name: String
    let points: [CGPoint]
    let vector: [Double] // For Protractor method
}

struct RecognitionResult {
    let shapeName: String
    let confidence: Double
    let processingTime: Double
}

class StrokeRecognizer {
    // $1 Recognizer constants
    private let numPoints: Int = 64
    private let squareSize: Double = 250.0
    private let origin = CGPoint(x: 0, y: 0)
    private let diagonal: Double
    private let halfDiagonal: Double
    private let angleRange: Double = 45.0 * .pi / 180.0
    private let anglePrecision: Double = 2.0 * .pi / 180.0
    private let phi: Double = 0.5 * (-1.0 + sqrt(5.0)) // Golden Ratio

    private var templates: [UnistrokeTemplate] = []

    init() {
        self.diagonal = sqrt(squareSize * squareSize + squareSize * squareSize)
        self.halfDiagonal = 0.5 * diagonal
        setupGestureTemplates()
    }

    func recognize(points: [CGPoint]) -> RecognitionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard points.count >= 3 else {
            return RecognitionResult(
                shapeName: "unknown",
                confidence: 0.0,
                processingTime: CFAbsoluteTimeGetCurrent() - startTime
            )
        }

        let candidate = createTemplate(from: points)

        var bestIndex = -1
        var bestDistance = Double.infinity

        for (index, template) in templates.enumerated() {
            let distance = distanceAtBestAngle(candidate.points, template.points)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        if bestIndex == -1 {
            return RecognitionResult(
                shapeName: "unknown",
                confidence: 0.0,
                processingTime: processingTime
            )
        }

        let confidence = max(0.0, 1.0 - bestDistance / halfDiagonal)
        return RecognitionResult(
            shapeName: templates[bestIndex].name,
            confidence: confidence,
            processingTime: processingTime
        )
    }

    private func setupGestureTemplates() {
        // Circle template - based on $1 recognizer circle data
        let circlePoints = [
            CGPoint(x: 127, y: 141), CGPoint(x: 124, y: 140), CGPoint(x: 120, y: 139), CGPoint(x: 118, y: 139),
            CGPoint(x: 116, y: 139), CGPoint(x: 111, y: 140), CGPoint(x: 109, y: 141), CGPoint(x: 104, y: 144),
            CGPoint(x: 100, y: 147), CGPoint(x: 96, y: 152), CGPoint(x: 93, y: 157), CGPoint(x: 90, y: 163),
            CGPoint(x: 87, y: 169), CGPoint(x: 85, y: 175), CGPoint(x: 83, y: 181), CGPoint(x: 82, y: 190),
            CGPoint(x: 82, y: 195), CGPoint(x: 83, y: 200), CGPoint(x: 84, y: 205), CGPoint(x: 88, y: 213),
            CGPoint(x: 91, y: 216), CGPoint(x: 96, y: 219), CGPoint(x: 103, y: 222), CGPoint(x: 108, y: 224),
            CGPoint(x: 111, y: 224), CGPoint(x: 120, y: 224), CGPoint(x: 133, y: 223), CGPoint(x: 142, y: 222),
            CGPoint(x: 152, y: 218), CGPoint(x: 160, y: 214), CGPoint(x: 167, y: 210), CGPoint(x: 173, y: 204),
            CGPoint(x: 178, y: 198), CGPoint(x: 179, y: 196), CGPoint(x: 182, y: 188), CGPoint(x: 182, y: 177),
            CGPoint(x: 178, y: 167), CGPoint(x: 170, y: 150), CGPoint(x: 163, y: 138), CGPoint(x: 152, y: 130),
            CGPoint(x: 143, y: 129), CGPoint(x: 140, y: 131), CGPoint(x: 129, y: 136), CGPoint(x: 126, y: 139)
        ]

        // Rectangle template
        let rectanglePoints = [
            CGPoint(x: 78, y: 149), CGPoint(x: 78, y: 153), CGPoint(x: 78, y: 157), CGPoint(x: 78, y: 160),
            CGPoint(x: 79, y: 162), CGPoint(x: 79, y: 164), CGPoint(x: 79, y: 167), CGPoint(x: 79, y: 169),
            CGPoint(x: 79, y: 173), CGPoint(x: 79, y: 178), CGPoint(x: 79, y: 183), CGPoint(x: 80, y: 189),
            CGPoint(x: 80, y: 193), CGPoint(x: 80, y: 198), CGPoint(x: 80, y: 202), CGPoint(x: 81, y: 208),
            CGPoint(x: 81, y: 210), CGPoint(x: 81, y: 216), CGPoint(x: 82, y: 222), CGPoint(x: 82, y: 224),
            CGPoint(x: 82, y: 227), CGPoint(x: 83, y: 229), CGPoint(x: 83, y: 231), CGPoint(x: 85, y: 230),
            CGPoint(x: 88, y: 232), CGPoint(x: 90, y: 233), CGPoint(x: 92, y: 232), CGPoint(x: 94, y: 233),
            CGPoint(x: 99, y: 232), CGPoint(x: 102, y: 233), CGPoint(x: 106, y: 233), CGPoint(x: 109, y: 234),
            CGPoint(x: 117, y: 235), CGPoint(x: 123, y: 236), CGPoint(x: 126, y: 236), CGPoint(x: 135, y: 237),
            CGPoint(x: 142, y: 238), CGPoint(x: 145, y: 238), CGPoint(x: 152, y: 238), CGPoint(x: 154, y: 239),
            CGPoint(x: 165, y: 238), CGPoint(x: 174, y: 237), CGPoint(x: 179, y: 236), CGPoint(x: 186, y: 235),
            CGPoint(x: 191, y: 235), CGPoint(x: 195, y: 233), CGPoint(x: 197, y: 233), CGPoint(x: 200, y: 233),
            CGPoint(x: 201, y: 235), CGPoint(x: 201, y: 233), CGPoint(x: 199, y: 231), CGPoint(x: 198, y: 226),
            CGPoint(x: 198, y: 220), CGPoint(x: 196, y: 207), CGPoint(x: 195, y: 195), CGPoint(x: 195, y: 181),
            CGPoint(x: 195, y: 173), CGPoint(x: 195, y: 163), CGPoint(x: 194, y: 155), CGPoint(x: 192, y: 145),
            CGPoint(x: 192, y: 143), CGPoint(x: 192, y: 138), CGPoint(x: 191, y: 135), CGPoint(x: 191, y: 133),
            CGPoint(x: 191, y: 130), CGPoint(x: 190, y: 128), CGPoint(x: 188, y: 129), CGPoint(x: 186, y: 129),
            CGPoint(x: 181, y: 132), CGPoint(x: 173, y: 131), CGPoint(x: 162, y: 131), CGPoint(x: 151, y: 132),
            CGPoint(x: 149, y: 132), CGPoint(x: 138, y: 132), CGPoint(x: 136, y: 132), CGPoint(x: 122, y: 131),
            CGPoint(x: 120, y: 131), CGPoint(x: 109, y: 130), CGPoint(x: 107, y: 130), CGPoint(x: 90, y: 132),
            CGPoint(x: 81, y: 133), CGPoint(x: 76, y: 133)
        ]

        // Triangle template
        let trianglePoints = [
            CGPoint(x: 137, y: 139), CGPoint(x: 135, y: 141), CGPoint(x: 133, y: 144), CGPoint(x: 132, y: 146),
            CGPoint(x: 130, y: 149), CGPoint(x: 128, y: 151), CGPoint(x: 126, y: 155), CGPoint(x: 123, y: 160),
            CGPoint(x: 120, y: 166), CGPoint(x: 116, y: 171), CGPoint(x: 112, y: 177), CGPoint(x: 107, y: 183),
            CGPoint(x: 102, y: 188), CGPoint(x: 100, y: 191), CGPoint(x: 95, y: 195), CGPoint(x: 90, y: 199),
            CGPoint(x: 86, y: 203), CGPoint(x: 82, y: 206), CGPoint(x: 80, y: 209), CGPoint(x: 75, y: 213),
            CGPoint(x: 73, y: 213), CGPoint(x: 70, y: 216), CGPoint(x: 67, y: 219), CGPoint(x: 64, y: 221),
            CGPoint(x: 61, y: 223), CGPoint(x: 60, y: 225), CGPoint(x: 62, y: 226), CGPoint(x: 65, y: 225),
            CGPoint(x: 67, y: 226), CGPoint(x: 74, y: 226), CGPoint(x: 77, y: 227), CGPoint(x: 85, y: 229),
            CGPoint(x: 91, y: 230), CGPoint(x: 99, y: 231), CGPoint(x: 108, y: 232), CGPoint(x: 116, y: 233),
            CGPoint(x: 125, y: 233), CGPoint(x: 134, y: 234), CGPoint(x: 145, y: 233), CGPoint(x: 153, y: 232),
            CGPoint(x: 160, y: 233), CGPoint(x: 170, y: 234), CGPoint(x: 177, y: 235), CGPoint(x: 179, y: 236),
            CGPoint(x: 186, y: 237), CGPoint(x: 193, y: 238), CGPoint(x: 198, y: 239), CGPoint(x: 200, y: 237),
            CGPoint(x: 202, y: 239), CGPoint(x: 204, y: 238), CGPoint(x: 206, y: 234), CGPoint(x: 205, y: 230),
            CGPoint(x: 202, y: 222), CGPoint(x: 197, y: 216), CGPoint(x: 192, y: 207), CGPoint(x: 186, y: 198),
            CGPoint(x: 179, y: 189), CGPoint(x: 174, y: 183), CGPoint(x: 170, y: 178), CGPoint(x: 164, y: 171),
            CGPoint(x: 161, y: 168), CGPoint(x: 154, y: 160), CGPoint(x: 148, y: 155), CGPoint(x: 143, y: 150),
            CGPoint(x: 138, y: 148), CGPoint(x: 136, y: 148)
        ]

        // Line template (horizontal)
        let linePoints = createLineTemplate()

        templates = [
            createUnistrokeTemplate(name: "circle", points: circlePoints),
            createUnistrokeTemplate(name: "rectangle", points: rectanglePoints),
            createUnistrokeTemplate(name: "triangle", points: trianglePoints),
            createUnistrokeTemplate(name: "line", points: linePoints)
        ]
    }

    private func createLineTemplate() -> [CGPoint] {
        // Create a simple horizontal line
        var points: [CGPoint] = []
        for i in 0..<32 {
            let t = Double(i) / 31.0
            let x = 50 + t * 150 // Line from x=50 to x=200
            let y = 125.0 // Middle height
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private func createUnistrokeTemplate(name: String, points: [CGPoint]) -> UnistrokeTemplate {
        let processedPoints = preprocessPoints(points)
        let vector = vectorize(processedPoints)
        return UnistrokeTemplate(name: name, points: processedPoints, vector: vector)
    }

    private func createTemplate(from rawPoints: [CGPoint]) -> UnistrokeTemplate {
        let processedPoints = preprocessPoints(rawPoints)
        let vector = vectorize(processedPoints)
        return UnistrokeTemplate(name: "candidate", points: processedPoints, vector: vector)
    }

    private func preprocessPoints(_ points: [CGPoint]) -> [CGPoint] {
        var processed = resample(points, numPoints: numPoints)
        let radians = indicativeAngle(processed)
        processed = rotateBy(processed, radians: -radians)
        processed = scaleTo(processed, size: squareSize)
        processed = translateTo(processed, point: origin)
        return processed
    }

    private func resample(_ points: [CGPoint], numPoints: Int) -> [CGPoint] {
        guard points.count > 1 else { return points }

        let totalLength = pathLength(points)
        guard totalLength > 0 else { return points }

        let interval = totalLength / Double(numPoints - 1)
        var resampled: [CGPoint] = [points[0]]
        var distance = 0.0

        for i in 1..<points.count {
            let segmentLength = distanceBetween(points[i-1], points[i])

            if distance + segmentLength >= interval {
                let ratio = (interval - distance) / segmentLength
                let newX = points[i-1].x + CGFloat(ratio) * (points[i].x - points[i-1].x)
                let newY = points[i-1].y + CGFloat(ratio) * (points[i].y - points[i-1].y)
                let newPoint = CGPoint(x: newX, y: newY)

                resampled.append(newPoint)

                // Insert the new point into the original array for next iteration
                var mutablePoints = points
                mutablePoints.insert(newPoint, at: i)
                distance = 0.0
            } else {
                distance += segmentLength
            }
        }

        // Ensure we have exactly numPoints
        while resampled.count < numPoints {
            resampled.append(points.last!)
        }

        return Array(resampled.prefix(numPoints))
    }

    private func pathLength(_ points: [CGPoint]) -> Double {
        var length = 0.0
        for i in 1..<points.count {
            length += distanceBetween(points[i-1], points[i])
        }
        return length
    }

    private func distanceBetween(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = Double(p1.x - p2.x)
        let dy = Double(p1.y - p2.y)
        return sqrt(dx * dx + dy * dy)
    }

    private func indicativeAngle(_ points: [CGPoint]) -> Double {
        let c = centroid(points)
        return atan2(Double(c.y - points[0].y), Double(c.x - points[0].x))
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for point in points {
            x += point.x
            y += point.y
        }
        x /= CGFloat(points.count)
        y /= CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }

    private func rotateBy(_ points: [CGPoint], radians: Double) -> [CGPoint] {
        let c = centroid(points)
        let cos = Foundation.cos(radians)
        let sin = Foundation.sin(radians)

        return points.map { point in
            let dx = Double(point.x - c.x)
            let dy = Double(point.y - c.y)
            let qx = dx * cos - dy * sin + Double(c.x)
            let qy = dx * sin + dy * cos + Double(c.y)
            return CGPoint(x: qx, y: qy)
        }
    }

    private func scaleTo(_ points: [CGPoint], size: Double) -> [CGPoint] {
        let bbox = boundingBox(points)
        guard bbox.width > 0 && bbox.height > 0 else { return points }

        let scaleX = size / Double(bbox.width)
        let scaleY = size / Double(bbox.height)

        return points.map { point in
            CGPoint(
                x: point.x * scaleX,
                y: point.y * scaleY
            )
        }
    }

    private func translateTo(_ points: [CGPoint], point: CGPoint) -> [CGPoint] {
        let c = centroid(points)
        let dx = point.x - c.x
        let dy = point.y - c.y

        return points.map { p in
            CGPoint(x: p.x + dx, y: p.y + dy)
        }
    }

    private func boundingBox(_ points: [CGPoint]) -> CGRect {
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func vectorize(_ points: [CGPoint]) -> [Double] {
        var sum = 0.0
        var vector: [Double] = []

        for point in points {
            vector.append(Double(point.x))
            vector.append(Double(point.y))
            sum += Double(point.x * point.x + point.y * point.y)
        }

        let magnitude = sqrt(sum)
        if magnitude > 0 {
            for i in 0..<vector.count {
                vector[i] /= magnitude
            }
        }

        return vector
    }

    private func distanceAtBestAngle(_ points1: [CGPoint], _ points2: [CGPoint]) -> Double {
        var startRange = -angleRange
        var endRange = angleRange
        let threshold = anglePrecision

        var x1 = phi * startRange + (1.0 - phi) * endRange
        var f1 = distanceAtAngle(points1, points2, x1)
        var x2 = (1.0 - phi) * startRange + phi * endRange
        var f2 = distanceAtAngle(points1, points2, x2)

        while abs(endRange - startRange) > threshold {
            if f1 < f2 {
                endRange = x2
                x2 = x1
                f2 = f1
                x1 = phi * startRange + (1.0 - phi) * endRange
                f1 = distanceAtAngle(points1, points2, x1)
            } else {
                startRange = x1
                x1 = x2
                f1 = f2
                x2 = (1.0 - phi) * startRange + phi * endRange
                f2 = distanceAtAngle(points1, points2, x2)
            }
        }

        return min(f1, f2)
    }

    private func distanceAtAngle(_ points1: [CGPoint], _ points2: [CGPoint], _ radians: Double) -> Double {
        let rotatedPoints = rotateBy(points1, radians: radians)
        return pathDistance(rotatedPoints, points2)
    }

    private func pathDistance(_ points1: [CGPoint], _ points2: [CGPoint]) -> Double {
        guard points1.count == points2.count else { return Double.infinity }

        var distance = 0.0
        for i in 0..<points1.count {
            distance += distanceBetween(points1[i], points2[i])
        }

        return distance / Double(points1.count)
    }
}