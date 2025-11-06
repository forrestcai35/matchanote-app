import Foundation
import UIKit
import SwiftUI

/// Response structure from LLM for auto-fill
struct AutoFillResponse: Codable {
    let textboxes: [AutoFillTextBox]
}

struct AutoFillTextBox: Codable {
    let text: String
    let x: Int
    let y: Int
    let pageIndex: Int
    let confidence: Double
}

    /// Result of auto-fill operation
    struct AutoFillResult {
        let textboxes: [ValidatedTextBox]
        let skippedCount: Int
        let totalRequested: Int
        let message: String
    }

/// Validated textbox ready for insertion
struct ValidatedTextBox {
    let text: String
    let position: CGPoint
    let pageIndex: Int
    let confidence: Double
}

/// Handles automatic filling of worksheets and forms
class AutoFillHandler {

    // MARK: - Singleton
    static let shared = AutoFillHandler()

    private init() {}

    // MARK: - Auto-Fill Detection

    /// Determine if user query is requesting auto-fill functionality
    /// - Parameter input: User's query text
    /// - Returns: True if auto-fill should be triggered
    func shouldAutoFill(input: String) -> Bool {
        let lowercaseInput = input.lowercased()

        let autoFillKeywords = [
            "fill out", "fill in", "fill this",
            "answer these", "answer the", "complete this",
            "fill the worksheet", "fill the form",
            "complete the worksheet", "complete the form",
            "do this worksheet", "do this assignment",
            "solve these", "work through"
        ]

        return autoFillKeywords.contains { lowercaseInput.contains($0) }
    }

    // MARK: - Auto-Fill Processing

    /// Process auto-fill request
    /// - Parameters:
    ///   - note: The note containing the worksheet/form
    ///   - query: User's query
    ///   - model: AI model to use
    ///   - storageManager: Storage manager for note access
    ///   - existingTextBoxesByPage: Existing textboxes for collision detection (optional)
    /// - Returns: Result with validated textboxes ready for insertion
    func processAutoFill(
        note: Note,
        query: String,
        model: String,
        storageManager: StorageManager,
        existingTextBoxesByPage: [Int: [TextBox]]? = nil
    ) async throws -> AutoFillResult {

        // Get latest note version
        guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
            throw NSError(
                domain: "AutoFillHandler",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find latest note data"]
            )
        }

        // Generate note images for LLM
        // Support up to 20 pages for large worksheets
        let mediaItems = await NoteContextProvider.shared.generateMediaItems(
            from: latestNote,
            userQuery: query,
            maxPages: 20,
            scale: 0.6
        )

        guard !mediaItems.isEmpty else {
            throw NSError(
                domain: "AutoFillHandler",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No images could be generated from note"]
            )
        }

        // Send to LLM with auto-fill prompt
        let response = try await LlmAPI.sendMessage(
            userMessage: "Analyze this worksheet/form and provide coordinates for filling in answers: \(query)",
            model_string: model,
            mediaItems: mediaItems,
            conversationHistory: nil,
            systemPrompt: .autoFill
        )

        // Parse JSON response
        let autoFillResponse = try parseAutoFillResponse(response)

        // Validate textboxes and prepare for insertion
        let result = validateTextBoxes(
            autoFillResponse: autoFillResponse,
            note: latestNote,
            existingTextBoxesByPage: existingTextBoxesByPage
        )

        return result
    }

    // MARK: - JSON Parsing

    /// Parse LLM response to extract auto-fill data
    private func parseAutoFillResponse(_ response: String) throws -> AutoFillResponse {
        // Use same extraction logic as other JSON responses
        let jsonString = extractJSON(from: response)

        // Repair common JSON formatting errors from LLMs
        let repairedJSON = repairJSON(jsonString)

        guard let jsonData = repairedJSON.data(using: .utf8) else {
            throw NSError(
                domain: "AutoFillHandler",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to data"]
            )
        }

        do {
            let decoded = try JSONDecoder().decode(AutoFillResponse.self, from: jsonData)
            return decoded
        } catch {
            print("❌ AutoFill JSON decoding error: \(error)")
            print("📄 Original response: \(jsonString)")
            print("📄 Repaired JSON: \(repairedJSON)")
            throw NSError(
                domain: "AutoFillHandler",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse auto-fill response: \(error.localizedDescription)"]
            )
        }
    }

    /// Repair common JSON formatting errors from LLM responses
    private func repairJSON(_ json: String) -> String {
        var repaired = json

        // Fix wrong field names: Gemini sometimes uses "text_content" instead of "text"
        repaired = repaired.replacingOccurrences(
            of: "\"text_content\"",
            with: "\"text\""
        )

        // Fix missing quotes after text field values
        // Pattern: "text": "value",x" should be "text": "value", "x"
        // This happens when LLMs forget the closing quote, especially with superscripts
        repaired = repaired.replacingOccurrences(
            of: #"\"([^\"]*)\",([a-z])"#,
            with: #"\"$1\", \"$2"#,
            options: .regularExpression
        )

        // Fix missing quotes before field names in general: ,fieldName" -> , "fieldName"
        repaired = repaired.replacingOccurrences(
            of: #",\s*([a-z][a-zA-Z0-9_]*)\""#,
            with: #", \"$1\""#,
            options: .regularExpression
        )

        // Fix trailing commas before closing braces/brackets (some LLMs add these)
        repaired = repaired.replacingOccurrences(
            of: #",\s*\}"#,
            with: "}",
            options: .regularExpression
        )
        repaired = repaired.replacingOccurrences(
            of: #",\s*\]"#,
            with: "]",
            options: .regularExpression
        )

        return repaired
    }

    /// Extract JSON from response (handles markdown code blocks)
    private func extractJSON(from response: String) -> String {
        // Remove markdown code blocks
        var cleaned = response

        // Remove ```json and ``` markers
        if let jsonStart = cleaned.range(of: "```json") {
            cleaned = String(cleaned[jsonStart.upperBound...])
        } else if let jsonStart = cleaned.range(of: "```") {
            cleaned = String(cleaned[jsonStart.upperBound...])
        }

        if let jsonEnd = cleaned.range(of: "```", options: .backwards) {
            cleaned = String(cleaned[..<jsonEnd.lowerBound])
        }

        // Find JSON object by braces
        if let extracted = extractJSONByBraces(from: cleaned) {
            return extracted
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract JSON by matching braces
    private func extractJSONByBraces(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else { return nil }

        var braceCount = 0
        var currentIndex = startIndex

        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    return String(text[startIndex...currentIndex])
                }
            }
            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }

    // MARK: - TextBox Validation

    /// Validate textboxes from auto-fill response
    private func validateTextBoxes(
        autoFillResponse: AutoFillResponse,
        note: Note,
        existingTextBoxesByPage: [Int: [TextBox]]?
    ) -> AutoFillResult {

        var validatedTextBoxes: [ValidatedTextBox] = []
        let skippedCount = 0
        let totalRequested = autoFillResponse.textboxes.count

        let paperSize = PaperUtilities.paperSize(for: note.paperSize)

        for autoFillBox in autoFillResponse.textboxes {
            // Debug: Log raw coordinates from LLM
            print("📍 AUTO-FILL DEBUG: LLM returned coordinates: x=\(autoFillBox.x), y=\(autoFillBox.y) for page \(autoFillBox.pageIndex)")
            print("   Text: \"\(autoFillBox.text.prefix(30))...\" (confidence: \(autoFillBox.confidence))")

            // LLM provides coordinates in full paper space (not scaled image pixels)
            // No conversion needed - use coordinates directly
            let actualX = CGFloat(autoFillBox.x)
            let actualY = CGFloat(autoFillBox.y)

            print("   Using coordinates directly (full paper space): x=\(actualX), y=\(actualY)")

            // Clamp coordinates to paper bounds instead of skipping
            let clampedX = max(0, min(actualX, paperSize.width))
            let clampedY = max(0, min(actualY, paperSize.height))
            let position = CGPoint(x: clampedX, y: clampedY)

            if clampedX != actualX || clampedY != actualY {
                print("   ⚠️ Clamped out-of-bounds coordinates: (\(actualX), \(actualY)) → (\(clampedX), \(clampedY))")
                print("   Paper bounds: width=\(paperSize.width), height=\(paperSize.height)")
            }

            print("   Final position: (\(position.x), \(position.y))")

            // Always create textbox (remove text-to-stroke logic)
            validatedTextBoxes.append(ValidatedTextBox(
                text: autoFillBox.text,
                position: position,
                pageIndex: autoFillBox.pageIndex,
                confidence: autoFillBox.confidence
            ))

            print("   ✓ Created textbox")
        }

        // Generate result message
        let addedCount = validatedTextBoxes.count
        let itemType = "answer"
        let message = "Adding \(addedCount) \(itemType)\(addedCount == 1 ? "" : "s") from auto-fill"

        print("✅ AUTO-FILL VALIDATION COMPLETE:")
        print("   Total requested: \(totalRequested)")
        print("   Total validated: \(addedCount)")
        print("   Skipped: \(skippedCount)")

        return AutoFillResult(
            textboxes: validatedTextBoxes,
            skippedCount: skippedCount,
            totalRequested: totalRequested,
            message: message
        )
    }

    // MARK: - Collision Detection

    /// Check if position would collide with existing textboxes
    private func hasCollision(
        position: CGPoint,
        pageIndex: Int,
        existingTextBoxesByPage: [Int: [TextBox]]
    ) -> Bool {
        guard let existingBoxes = existingTextBoxesByPage[pageIndex] else {
            return false
        }

        let collisionBuffer: CGFloat = 30  // Minimum distance between textboxes

        for existingBox in existingBoxes {
            let distance = sqrt(
                pow(position.x - existingBox.position.x, 2) +
                pow(position.y - existingBox.position.y, 2)
            )

            if distance < collisionBuffer {
                return true
            }
        }

        return false
    }
}
