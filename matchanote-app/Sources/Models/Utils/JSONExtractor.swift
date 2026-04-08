import Foundation

/// Utility for extracting and repairing JSON from LLM responses
/// Handles common formatting issues and markdown code blocks
class JSONExtractor {

    // MARK: - Public API

    /// Extract JSON from an LLM response, handling markdown code blocks and common formatting errors
    /// - Parameters:
    ///   - response: The raw LLM response string
    ///   - repair: Whether to apply automatic JSON repairs (default: true)
    ///   - verbose: Whether to print debug information (default: false)
    /// - Returns: Cleaned JSON string ready for parsing
    static func extractJSON(from response: String, repair: Bool = true, verbose: Bool = false) -> String {
        if verbose {
            print("📝 Extracting JSON from response (length: \(response.count))")
        }

        // Method 1: Extract from markdown code blocks
        let components = response.components(separatedBy: "```")
        if components.count >= 3 {
            var jsonContent = components[1]

            // Remove language identifier (json, JSON, etc.)
            if jsonContent.hasPrefix("json") || jsonContent.hasPrefix("JSON") {
                jsonContent = String(jsonContent.dropFirst(4))
            }

            let trimmed = jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidJSONStart(trimmed) {
                if verbose {
                    print("✅ Extracted from markdown code block (length: \(trimmed.count))")
                }
                return repair ? repairJSON(trimmed) : trimmed
            }
        }

        // Method 2: Extract JSON object by matching braces
        if let extracted = extractJSONByBraces(from: response) {
            if verbose {
                print("✅ Extracted by brace matching (length: \(extracted.count))")
            }
            return repair ? repairJSON(extracted) : extracted
        }

        // Method 3: Extract JSON array by matching brackets
        if let extracted = extractJSONArray(from: response) {
            if verbose {
                print("✅ Extracted by bracket matching (length: \(extracted.count))")
            }
            return repair ? repairJSON(extracted) : extracted
        }

        // Fallback: return trimmed original
        if verbose {
            print("⚠️ No extraction method worked, returning trimmed original")
        }
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return repair ? repairJSON(trimmed) : trimmed
    }

    /// Repair common JSON formatting errors from LLM responses
    /// - Parameter json: JSON string to repair
    /// - Returns: Repaired JSON string
    static func repairJSON(_ json: String) -> String {
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

        // Fix missing quotes before field names: ,fieldName" -> , "fieldName"
        repaired = repaired.replacingOccurrences(
            of: #",\s*([a-z][a-zA-Z0-9_]*)\""#,
            with: #", \"$1\""#,
            options: .regularExpression
        )

        // Fix trailing commas before closing braces/brackets
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

    // MARK: - Private Helpers

    /// Check if string starts with valid JSON structure
    private static func isValidJSONStart(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }

    /// Extract JSON object by matching braces
    private static func extractJSONByBraces(from text: String) -> String? {
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

    /// Extract JSON array by matching brackets
    private static func extractJSONArray(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "[") else { return nil }

        // Validate that this looks like a real JSON array
        let checkIndex = text.index(after: startIndex)
        if checkIndex < text.endIndex {
            let nextChar = text[checkIndex]
            // If next character is a letter (like 'X' in [X]), it's probably not JSON
            if nextChar.isLetter {
                // Recursively look for another [ that might be the actual JSON array
                let remainingText = String(text[text.index(after: startIndex)...])
                return extractJSONArray(from: remainingText)
            }
        }

        var bracketCount = 0
        var currentIndex = startIndex

        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            if char == "[" {
                bracketCount += 1
            } else if char == "]" {
                bracketCount -= 1
                if bracketCount == 0 {
                    return String(text[startIndex...currentIndex])
                }
            }
            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }
}
