@preconcurrency import Vision
import PencilKit
import CoreGraphics

class HandwritingRecognizer: ObservableObject {
    @Published var isProcessing = false
    @Published var recognizedText: String = ""
    @Published var confidence: Float = 0.0

    private var recognitionRequest: VNRecognizeTextRequest?

    init() {
        setupTextRecognition()
    }

    private func setupTextRecognition() {
        recognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.processRecognitionResults(request: request, error: error)
            }
        }

        recognitionRequest?.recognitionLevel = .accurate
        recognitionRequest?.usesLanguageCorrection = true
        _ = try? recognitionRequest?.supportedRecognitionLanguages()
    }

    func recognizeHandwriting(from drawing: PKDrawing, completion: @escaping (Result<String, Error>) -> Void) {
        isProcessing = true

        Task {
            do {
                let text = try await recognizeText(from: drawing)
                await MainActor.run {
                    self.isProcessing = false
                    completion(.success(text))
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    completion(.failure(error))
                }
            }
        }
    }

    func recognizeHandwriting(from drawingData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let drawing = try? PKDrawing(data: drawingData) else {
            completion(.failure(HandwritingError.invalidDrawingData))
            return
        }

        recognizeHandwriting(from: drawing, completion: completion)
    }

    private func recognizeText(from drawing: PKDrawing) async throws -> String {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else {
            return ""
        }

        let scale: CGFloat = 2.0
        let image = drawing.image(from: bounds, scale: scale)

        guard let cgImage = image.cgImage else {
            throw HandwritingError.imageConversionFailed
        }

        return try await performTextRecognition(on: cgImage)
    }

    private func performTextRecognition(on cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let request = recognitionRequest else {
                continuation.resume(throwing: HandwritingError.recognitionSetupFailed)
                return
            }

            request.cancel()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                
                // Process results immediately after performing the request
                if let results = request.results {
                    let recognizedStrings = results.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let fullText = recognizedStrings.joined(separator: "\n")
                    continuation.resume(returning: fullText)
                } else {
                    continuation.resume(returning: "")
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func processRecognitionResults(request: VNRequest, error: Error?) {
        guard error == nil else {
            print("Text recognition error: \(error!)")
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        recognizedText = recognizedStrings.joined(separator: "\n")

        if let firstObservation = observations.first,
           let firstCandidate = firstObservation.topCandidates(1).first {
            confidence = firstCandidate.confidence
        }
    }

    func recognizeTextFromMultiplePages(drawingDataByPage: [String: Data]) async -> [String: String] {
        var recognizedTextByPage: [String: String] = [:]

        for (pageKey, drawingData) in drawingDataByPage {
            guard let drawing = try? PKDrawing(data: drawingData) else {
                continue
            }

            do {
                let text = try await recognizeText(from: drawing)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recognizedTextByPage[pageKey] = text
                }
            } catch {
                print("Failed to recognize text for page \(pageKey): \(error)")
            }
        }

        return recognizedTextByPage
    }

    func extractKeywordsFromText(_ text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filteredWords = words
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }
            .filter { !commonStopWords.contains($0.lowercased()) }

        let wordCounts = Dictionary(grouping: filteredWords, by: { $0.lowercased() })
            .mapValues { $0.count }

        return Array(wordCounts.keys)
            .sorted { wordCounts[$0] ?? 0 > wordCounts[$1] ?? 0 }
            .prefix(10)
            .map { String($0) }
    }

    private let commonStopWords = Set([
        "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "a", "an", "is", "are", "was", "were", "be", "been", "have", "has", "had",
        "do", "does", "did", "will", "would", "could", "should", "may", "might",
        "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they"
    ])
}

enum HandwritingError: Error {
    case invalidDrawingData
    case imageConversionFailed
    case recognitionSetupFailed
    case recognitionFailed

    var localizedDescription: String {
        switch self {
        case .invalidDrawingData:
            return "Invalid drawing data provided"
        case .imageConversionFailed:
            return "Failed to convert drawing to image"
        case .recognitionSetupFailed:
            return "Failed to setup text recognition"
        case .recognitionFailed:
            return "Text recognition failed"
        }
    }
}