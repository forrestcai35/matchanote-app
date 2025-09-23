import Foundation
import SwiftUI

struct NoteContent {
    let handwrittenText: [String: String] // page -> text
    let typedText: String
    let keywords: [String]
    let subjects: [String]
    let createdDate: Date
    let modifiedDate: Date
    let title: String

    var allText: String {
        let handwrittenContent = handwrittenText.values.joined(separator: "\n")
        return [typedText, handwrittenContent]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct ContentGap {
    let type: GapType
    let description: String
    let severity: Severity
    let suggestedAction: String
    let relatedKeywords: [String]

    enum GapType {
        case missingDefinition
        case incompleteExplanation
        case lacksExamples
        case missingConclusion
        case fragmentedThought
        case unclarConcept
        case missingConnection
    }

    enum Severity {
        case low, medium, high

        var color: Color {
            switch self {
            case .low: return .yellow
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

struct NoteInsight {
    let mainTopics: [String]
    let keyDefinitions: [String: String]
    let questions: [String]
    let actionItems: [String]
    let summaryPoints: [String]
    let connections: [String]
}

class NoteAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastAnalysis: AnalysisResult?

    private let handwritingRecognizer = HandwritingRecognizer()

    func analyzeNote(_ note: Note, relatedNotes: [Note] = []) async -> AnalysisResult {
        await MainActor.run { isAnalyzing = true }

        // Extract handwritten text from all pages
        let handwrittenText = await handwritingRecognizer.recognizeTextFromMultiplePages(
            drawingDataByPage: note.drawingDataByPage
        )

        // Create note content structure
        let content = NoteContent(
            handwrittenText: handwrittenText,
            typedText: note.content,
            keywords: extractKeywords(from: note),
            subjects: [note.subject].filter { !$0.isEmpty },
            createdDate: note.dateCreated,
            modifiedDate: note.dateModified,
            title: note.title
        )

        // Perform analysis
        let gaps = identifyContentGaps(in: content)
        let insights = generateInsights(from: content, relatedNotes: relatedNotes)
        let suggestions = generateSuggestions(for: content, gaps: gaps, insights: insights)

        let result = AnalysisResult(
            noteId: note.id,
            content: content,
            gaps: gaps,
            insights: insights,
            suggestions: suggestions,
            timestamp: Date()
        )

        await MainActor.run {
            self.lastAnalysis = result
            self.isAnalyzing = false
        }

        return result
    }

    private func extractKeywords(from note: Note) -> [String] {
        let allText = note.content + " " + note.title + " " + note.subject
        return handwritingRecognizer.extractKeywordsFromText(allText)
    }

    private func identifyContentGaps(in content: NoteContent) -> [ContentGap] {
        var gaps: [ContentGap] = []
        let text = content.allText.lowercased()

        // Check for incomplete definitions
        if text.contains("define") || text.contains("what is") {
            if !text.contains("means") && !text.contains("is when") && !text.contains("refers to") {
                gaps.append(ContentGap(
                    type: .missingDefinition,
                    description: "Found questions about definitions but no clear explanations",
                    severity: .medium,
                    suggestedAction: "Add clear definitions for key terms",
                    relatedKeywords: content.keywords
                ))
            }
        }

        // Check for fragmented thoughts (very short content)
        if content.allText.count < 100 {
            gaps.append(ContentGap(
                type: .fragmentedThought,
                description: "Content appears to be fragmented or incomplete",
                severity: .high,
                suggestedAction: "Expand on key points and provide more context",
                relatedKeywords: content.keywords
            ))
        }

        // Check for missing examples
        if text.contains("example") || text.contains("e.g.") || text.contains("for instance") {
            let exampleCount = ["example", "e.g.", "for instance"].reduce(0) { count, marker in
                count + text.components(separatedBy: marker).count - 1
            }
            if exampleCount < 2 {
                gaps.append(ContentGap(
                    type: .lacksExamples,
                    description: "Could benefit from more concrete examples",
                    severity: .low,
                    suggestedAction: "Add specific examples to illustrate key concepts",
                    relatedKeywords: content.keywords
                ))
            }
        }

        // Check for questions without answers
        let questionMarkers = ["?", "how", "why", "what", "when", "where", "who"]
        let questionCount = questionMarkers.reduce(0) { count, marker in
            count + text.components(separatedBy: marker).count - 1
        }

        if questionCount > 2 && content.allText.count < 500 {
            gaps.append(ContentGap(
                type: .incompleteExplanation,
                description: "Multiple questions found but limited explanatory content",
                severity: .medium,
                suggestedAction: "Provide answers to the questions posed",
                relatedKeywords: content.keywords
            ))
        }

        return gaps
    }

    private func generateInsights(from content: NoteContent, relatedNotes: [Note]) -> NoteInsight {
        let text = content.allText

        // Extract main topics from keywords and content
        let mainTopics = extractMainTopics(from: text, keywords: content.keywords)

        // Find key definitions
        let definitions = extractDefinitions(from: text)

        // Extract questions
        let questions = extractQuestions(from: text)

        // Extract action items
        let actionItems = extractActionItems(from: text)

        // Generate summary points
        let summaryPoints = generateSummaryPoints(from: text)

        // Find connections to related notes
        let connections = findConnections(to: relatedNotes, keywords: content.keywords)

        return NoteInsight(
            mainTopics: mainTopics,
            keyDefinitions: definitions,
            questions: questions,
            actionItems: actionItems,
            summaryPoints: summaryPoints,
            connections: connections
        )
    }

    private func generateSuggestions(for content: NoteContent, gaps: [ContentGap], insights: NoteInsight) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []

        // Convert gaps to suggestions
        for gap in gaps {
            suggestions.append(AISuggestion(
                type: .improvement,
                title: gap.suggestedAction,
                description: gap.description,
                priority: mapSeverityToPriority(gap.severity),
                actionType: .addContent,
                targetLocation: .endOfNote
            ))
        }

        // Add insight-based suggestions
        if insights.questions.count > 2 {
            suggestions.append(AISuggestion(
                type: .research,
                title: "Research Questions",
                description: "Found \(insights.questions.count) questions that could guide further research",
                priority: .medium,
                actionType: .research,
                targetLocation: .newPage
            ))
        }

        if insights.connections.count > 0 {
            suggestions.append(AISuggestion(
                type: .connection,
                title: "Related Notes",
                description: "Found connections to \(insights.connections.count) other notes",
                priority: .low,
                actionType: .crossReference,
                targetLocation: .endOfNote
            ))
        }

        if content.keywords.count > 5 {
            suggestions.append(AISuggestion(
                type: .organization,
                title: "Create Index",
                description: "Rich content detected - consider creating an index or summary",
                priority: .low,
                actionType: .organize,
                targetLocation: .beginningOfNote
            ))
        }

        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Helper Methods

    private func extractMainTopics(from text: String, keywords: [String]) -> [String] {
        // Use a combination of keywords and sentence analysis
        let sentences = text.components(separatedBy: .newlines)
        let _ = sentences.filter { sentence in
            keywords.contains { keyword in
                sentence.lowercased().contains(keyword.lowercased())
            }
        }

        return Array(Set(keywords.prefix(5))).sorted()
    }

    private func extractDefinitions(from text: String) -> [String: String] {
        var definitions: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lowercaseLine = line.lowercased()
            if lowercaseLine.contains(" is ") || lowercaseLine.contains(" means ") || lowercaseLine.contains(" refers to ") {
                let parts = line.components(separatedBy: CharacterSet(charactersIn: ":=-"))
                if parts.count >= 2 {
                    let term = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let definition = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !term.isEmpty && !definition.isEmpty {
                        definitions[term] = definition
                    }
                }
            }
        }

        return definitions
    }

    private func extractQuestions(from text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        return sentences.filter { $0.contains("?") || $0.lowercased().hasPrefix("how ") || $0.lowercased().hasPrefix("why ") || $0.lowercased().hasPrefix("what ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractActionItems(from text: String) -> [String] {
        let actionWords = ["todo", "task", "action", "need to", "must", "should", "remember to"]
        let lines = text.components(separatedBy: .newlines)

        return lines.filter { line in
            actionWords.contains { actionWord in
                line.lowercased().contains(actionWord)
            }
        }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func generateSummaryPoints(from text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 && $0.count < 150 }

        return Array(sentences.prefix(5))
    }

    private func findConnections(to relatedNotes: [Note], keywords: [String]) -> [String] {
        var connections: [String] = []

        for note in relatedNotes {
            let noteContent = note.content + " " + note.title + " " + note.subject
            let matchingKeywords = keywords.filter { keyword in
                noteContent.lowercased().contains(keyword.lowercased())
            }

            if matchingKeywords.count >= 2 {
                connections.append("Related to '\(note.title)' via: \(matchingKeywords.joined(separator: ", "))")
            }
        }

        return connections
    }

    private func mapSeverityToPriority(_ severity: ContentGap.Severity) -> AISuggestion.Priority {
        switch severity {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

struct AnalysisResult {
    let noteId: UUID
    let content: NoteContent
    let gaps: [ContentGap]
    let insights: NoteInsight
    let suggestions: [AISuggestion]
    let timestamp: Date
}

struct AISuggestion {
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Priority
    let actionType: ActionType
    let targetLocation: TargetLocation

    enum SuggestionType {
        case improvement
        case research
        case connection
        case organization
    }

    enum Priority: Int {
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
    }

    enum ActionType {
        case addContent
        case research
        case crossReference
        case organize
    }

    enum TargetLocation {
        case beginningOfNote
        case endOfNote
        case newPage
        case currentLocation
    }
}