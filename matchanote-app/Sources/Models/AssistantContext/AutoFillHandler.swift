import Foundation
import UIKit

/// Response structure from LLM for auto-fill
struct AutoFillResponse: Codable {
    let textboxes: [AutoFillTextBox]
    let explanation: String
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
        let conversationalResponse: String  // Natural language explanation for chat
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

        // Send to LLM via secure backend with auto-fill prompt
        let response = try await SecureLlmAPI.sendMessageCompat(
            userMessage: "Analyze this worksheet/form and provide coordinates for filling in answers: \(query)",
            model_string: model,
            mediaItems: mediaItems,
            conversationHistory: nil,
            systemPrompt: .autoFill
        )

        // Parse JSON response
        let autoFillResponse = try parseAutoFillResponse(response)

        // Validate textboxes and prepare for insertion
        let validationResult = validateTextBoxes(
            autoFillResponse: autoFillResponse,
            note: latestNote,
            existingTextBoxesByPage: existingTextBoxesByPage
        )

        // Return result with explanation from LLM response
        return AutoFillResult(
            textboxes: validationResult.textboxes,
            skippedCount: validationResult.skippedCount,
            totalRequested: validationResult.totalRequested,
            message: validationResult.message,
            conversationalResponse: autoFillResponse.explanation
        )
    }

    // MARK: - JSON Parsing

    /// Parse LLM response to extract auto-fill data
    private func parseAutoFillResponse(_ response: String) throws -> AutoFillResponse {
        // Use JSONExtractor utility to extract and repair JSON
        let jsonString = JSONExtractor.extractJSON(from: response, repair: true)

        guard let jsonData = jsonString.data(using: .utf8) else {
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
            print("📄 Extracted JSON: \(jsonString)")
            throw NSError(
                domain: "AutoFillHandler",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse auto-fill response: \(error.localizedDescription)"]
            )
        }
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
            message: message,
            conversationalResponse: ""  // Will be filled by caller
        )
    }
}
