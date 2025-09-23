import Foundation
import SwiftUI

struct ParsedSuggestion: Identifiable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Priority
    let actionType: ActionType
    let targetLocation: TargetLocation
    let insertionPoint: InsertionPoint?
    let content: String?
    let isAccepted: Bool

    init(
        type: SuggestionType,
        title: String,
        description: String,
        priority: Priority = .medium,
        actionType: ActionType,
        targetLocation: TargetLocation = .endOfNote,
        insertionPoint: InsertionPoint? = nil,
        content: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionType = actionType
        self.targetLocation = targetLocation
        self.insertionPoint = insertionPoint
        self.content = content
        self.isAccepted = false
    }

    enum SuggestionType: String, CaseIterable {
        case addDefinition = "add_definition"
        case addExample = "add_example"
        case expandConcept = "expand_concept"
        case createSummary = "create_summary"
        case addDiagram = "add_diagram"
        case crossReference = "cross_reference"
        case research = "research"
        case clarifyPoint = "clarify_point"
        case organize = "organize"
        case review = "review"

        var icon: String {
            switch self {
            case .addDefinition: return "book.closed"
            case .addExample: return "lightbulb"
            case .expandConcept: return "arrow.up.right"
            case .createSummary: return "list.bullet"
            case .addDiagram: return "rectangle.3.offgrid"
            case .crossReference: return "arrow.triangle.branch"
            case .research: return "magnifyingglass"
            case .clarifyPoint: return "questionmark.circle"
            case .organize: return "folder"
            case .review: return "checkmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .addDefinition, .addExample, .expandConcept:
                return .blue
            case .createSummary, .organize, .review:
                return .green
            case .addDiagram, .crossReference:
                return .purple
            case .research, .clarifyPoint:
                return .orange
            }
        }
    }

    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3

        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }

        var label: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }

    enum ActionType: String, CaseIterable {
        case insertText = "insert_text"
        case insertImage = "insert_image"
        case createPage = "create_page"
        case highlightText = "highlight_text"
        case addAnnotation = "add_annotation"
        case linkNote = "link_note"
        case scheduleReview = "schedule_review"
        case researchTopic = "research_topic"
    }

    enum TargetLocation: String, CaseIterable {
        case beginningOfNote = "beginning"
        case endOfNote = "end"
        case currentPage = "current_page"
        case newPage = "new_page"
        case afterSection = "after_section"
        case beforeSection = "before_section"
        case specificLocation = "specific"
    }

    struct InsertionPoint {
        let pageIndex: Int?
        let textPosition: Int?
        let coordinates: CGPoint?
        let sectionName: String?
    }
}

class SuggestionParser: ObservableObject {
    @Published var suggestions: [ParsedSuggestion] = []
    @Published var acceptedSuggestions: [ParsedSuggestion] = []
    @Published var isProcessing = false

    func parseAIResponse(_ response: String, for noteId: UUID) -> [ParsedSuggestion] {
        var parsedSuggestions: [ParsedSuggestion] = []

        let sections = response.components(separatedBy: "\n\n")

        for section in sections {
            if let suggestion = parseSuggestionSection(section, noteId: noteId) {
                parsedSuggestions.append(suggestion)
            }
        }

        // Also parse from structured formats
        parsedSuggestions.append(contentsOf: parseStructuredSuggestions(response, noteId: noteId))

        return parsedSuggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    private func parseSuggestionSection(_ section: String, noteId: UUID) -> ParsedSuggestion? {
        let lines = section.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !lines.isEmpty else { return nil }

        let content = section.lowercased()

        // Detect suggestion type from content
        let type = detectSuggestionType(from: content)
        let priority = detectPriority(from: content)
        let actionType = detectActionType(from: content, suggestionType: type)

        // Extract title and description
        let title = extractTitle(from: lines)
        let description = extractDescription(from: lines, title: title)

        // Determine target location
        let targetLocation = detectTargetLocation(from: content)

        return ParsedSuggestion(
            type: type,
            title: title,
            description: description,
            priority: priority,
            actionType: actionType,
            targetLocation: targetLocation,
            content: extractSuggestedContent(from: section)
        )
    }

    private func parseStructuredSuggestions(_ response: String, noteId: UUID) -> [ParsedSuggestion] {
        var suggestions: [ParsedSuggestion] = []

        // Parse JSON-like structures
        if let jsonSuggestions = parseJSONSuggestions(response, noteId: noteId) {
            suggestions.append(contentsOf: jsonSuggestions)
        }

        // Parse markdown-style lists
        suggestions.append(contentsOf: parseMarkdownSuggestions(response, noteId: noteId))

        // Parse numbered lists
        suggestions.append(contentsOf: parseNumberedSuggestions(response, noteId: noteId))

        return suggestions
    }

    private func detectSuggestionType(from content: String) -> ParsedSuggestion.SuggestionType {
        if content.contains("definition") || content.contains("define") || content.contains("meaning") {
            return .addDefinition
        } else if content.contains("example") || content.contains("instance") || content.contains("illustration") {
            return .addExample
        } else if content.contains("expand") || content.contains("elaborate") || content.contains("detail") {
            return .expandConcept
        } else if content.contains("summary") || content.contains("summarize") || content.contains("recap") {
            return .createSummary
        } else if content.contains("diagram") || content.contains("chart") || content.contains("visual") {
            return .addDiagram
        } else if content.contains("related") || content.contains("connection") || content.contains("link") {
            return .crossReference
        } else if content.contains("research") || content.contains("investigate") || content.contains("study") {
            return .research
        } else if content.contains("clarify") || content.contains("unclear") || content.contains("confusing") {
            return .clarifyPoint
        } else if content.contains("organize") || content.contains("structure") || content.contains("arrange") {
            return .organize
        } else if content.contains("review") || content.contains("revisit") || content.contains("check") {
            return .review
        } else {
            return .expandConcept
        }
    }

    private func detectPriority(from content: String) -> ParsedSuggestion.Priority {
        if content.contains("urgent") || content.contains("critical") || content.contains("important") || content.contains("essential") {
            return .high
        } else if content.contains("consider") || content.contains("might") || content.contains("could") || content.contains("optional") {
            return .low
        } else {
            return .medium
        }
    }

    private func detectActionType(from content: String, suggestionType: ParsedSuggestion.SuggestionType) -> ParsedSuggestion.ActionType {
        switch suggestionType {
        case .addDefinition, .addExample, .expandConcept, .clarifyPoint:
            return .insertText
        case .addDiagram:
            return .insertImage
        case .createSummary, .organize:
            return .createPage
        case .crossReference:
            return .linkNote
        case .research:
            return .researchTopic
        case .review:
            return .scheduleReview
        }
    }

    private func detectTargetLocation(from content: String) -> ParsedSuggestion.TargetLocation {
        if content.contains("beginning") || content.contains("start") || content.contains("top") {
            return .beginningOfNote
        } else if content.contains("end") || content.contains("conclusion") || content.contains("bottom") {
            return .endOfNote
        } else if content.contains("new page") || content.contains("separate page") {
            return .newPage
        } else if content.contains("current page") || content.contains("here") {
            return .currentPage
        } else {
            return .endOfNote
        }
    }

    private func extractTitle(from lines: [String]) -> String {
        // First non-empty line is usually the title
        let title = lines.first { !$0.isEmpty } ?? "Suggestion"

        // Clean up common prefixes
        let cleanTitle = title
            .replacingOccurrences(of: "^(Suggestion|Recommend|Consider):\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanTitle.isEmpty ? "Suggestion" : String(cleanTitle.prefix(100))
    }

    private func extractDescription(from lines: [String], title: String) -> String {
        let remainingLines = lines.dropFirst().filter { !$0.isEmpty && $0 != title }
        let description = remainingLines.joined(separator: " ")

        return description.isEmpty ? title : String(description.prefix(300))
    }

    private func extractSuggestedContent(from section: String) -> String? {
        // Look for content in quotes, code blocks, or after "Content:" labels
        let patterns = [
            "\"([^\"]+)\"",
            "`([^`]+)`",
            "Content:\\s*(.+)",
            "Add:\\s*(.+)",
            "Insert:\\s*(.+)"
        ]

        for pattern in patterns {
            if let range = section.range(of: pattern, options: .regularExpression) {
                let match = String(section[range])
                return match.replacingOccurrences(of: "^[\"'`]|[\"'`]$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func parseJSONSuggestions(_ response: String, noteId: UUID) -> [ParsedSuggestion]? {
        // Try to find JSON structures in the response
        guard let jsonRange = response.range(of: "\\{.*\\}", options: .regularExpression),
              let jsonData = String(response[jsonRange]).data(using: .utf8) else {
            return nil
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return [parseJSONSuggestion(json, noteId: noteId)].compactMap { $0 }
            } else if let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                return jsonArray.compactMap { parseJSONSuggestion($0, noteId: noteId) }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func parseJSONSuggestion(_ json: [String: Any], noteId: UUID) -> ParsedSuggestion? {
        guard let title = json["title"] as? String ?? json["suggestion"] as? String else {
            return nil
        }

        let description = json["description"] as? String ?? title
        let typeString = json["type"] as? String ?? ""
        let priorityString = json["priority"] as? String ?? "medium"

        let type = ParsedSuggestion.SuggestionType.allCases.first {
            $0.rawValue == typeString
        } ?? .expandConcept

        let priority = ParsedSuggestion.Priority.allCases.first {
            $0.label.lowercased() == priorityString.lowercased()
        } ?? .medium

        return ParsedSuggestion(
            type: type,
            title: title,
            description: description,
            priority: priority,
            actionType: detectActionType(from: description.lowercased(), suggestionType: type),
            content: json["content"] as? String
        )
    }

    private func parseMarkdownSuggestions(_ response: String, noteId: UUID) -> [ParsedSuggestion] {
        let lines = response.components(separatedBy: .newlines)
        var suggestions: [ParsedSuggestion] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                if let suggestion = parseSuggestionSection(content, noteId: noteId) {
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    private func parseNumberedSuggestions(_ response: String, noteId: UUID) -> [ParsedSuggestion] {
        let lines = response.components(separatedBy: .newlines)
        var suggestions: [ParsedSuggestion] = []

        let numberPattern = "^\\d+\\.\\s*(.+)$"
        let regex = try? NSRegularExpression(pattern: numberPattern)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: 0, length: trimmed.utf16.count)

            if let match = regex?.firstMatch(in: trimmed, options: [], range: range),
               let contentRange = Range(match.range(at: 1), in: trimmed) {
                let content = String(trimmed[contentRange])
                if let suggestion = parseSuggestionSection(content, noteId: noteId) {
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    func applySuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        switch suggestion.actionType {
        case .insertText:
            return insertTextSuggestion(suggestion, to: &note)
        case .insertImage:
            return insertImageSuggestion(suggestion, to: &note)
        case .createPage:
            return createPageSuggestion(suggestion, to: &note)
        case .highlightText:
            return highlightTextSuggestion(suggestion, to: &note)
        case .addAnnotation:
            return addAnnotationSuggestion(suggestion, to: &note)
        case .linkNote:
            return linkNoteSuggestion(suggestion, to: &note)
        case .scheduleReview:
            return scheduleReviewSuggestion(suggestion, to: &note)
        case .researchTopic:
            return researchTopicSuggestion(suggestion, to: &note)
        }
    }

    private func insertTextSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        guard let content = suggestion.content else { return false }

        switch suggestion.targetLocation {
        case .beginningOfNote:
            note.content = content + "\n\n" + note.content
        case .endOfNote:
            note.content += "\n\n" + content
        default:
            note.content += "\n\n" + content
        }

        note.dateModified = Date()
        return true
    }

    private func insertImageSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        // Placeholder for image insertion logic
        // This would typically involve creating a placeholder or instruction
        let placeholder = "[IMAGE SUGGESTION: \(suggestion.title)]"
        note.content += "\n\n" + placeholder

        note.dateModified = Date()
        return true
    }

    private func createPageSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        // Add suggestion as a new page marker in content
        let pageMarker = "\n\n--- NEW PAGE: \(suggestion.title) ---\n"
        if let content = suggestion.content {
            note.content += pageMarker + content
        } else {
            note.content += pageMarker + suggestion.description
        }

        note.dateModified = Date()
        return true
    }

    private func highlightTextSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        // Add highlighting instruction to content
        let highlight = "\n\n[HIGHLIGHT: \(suggestion.description)]"
        note.content += highlight

        note.dateModified = Date()
        return true
    }

    private func addAnnotationSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        let annotation = "\n\n[ANNOTATION: \(suggestion.title) - \(suggestion.description)]"
        note.content += annotation

        note.dateModified = Date()
        return true
    }

    private func linkNoteSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        let link = "\n\n[LINK SUGGESTION: \(suggestion.description)]"
        note.content += link

        note.dateModified = Date()
        return true
    }

    private func scheduleReviewSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        let review = "\n\n[REVIEW SCHEDULED: \(suggestion.title)]"
        note.content += review

        note.dateModified = Date()
        return true
    }

    private func researchTopicSuggestion(_ suggestion: ParsedSuggestion, to note: inout Note) -> Bool {
        let research = "\n\n[RESEARCH TOPIC: \(suggestion.title) - \(suggestion.description)]"
        note.content += research

        note.dateModified = Date()
        return true
    }

    func acceptSuggestion(_ suggestion: ParsedSuggestion) {
        acceptedSuggestions.append(suggestion)
        suggestions.removeAll { $0.id == suggestion.id }
    }

    func dismissSuggestion(_ suggestion: ParsedSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    func filterSuggestions(by type: ParsedSuggestion.SuggestionType) -> [ParsedSuggestion] {
        return suggestions.filter { $0.type == type }
    }

    func filterSuggestions(by priority: ParsedSuggestion.Priority) -> [ParsedSuggestion] {
        return suggestions.filter { $0.priority == priority }
    }
}