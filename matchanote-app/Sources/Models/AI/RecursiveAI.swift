import Foundation
import SwiftUI

struct AITool {
    let name: String
    let description: String
    let parameters: [String: String]
    let execute: ([String: Any]) async throws -> String
}

struct AIConversation {
    var messages: [AIMessage] = []
    var tools: [AITool] = []
    var context: [String: Any] = [:]
}

struct AIMessage {
    let role: String // "system", "user", "assistant", "tool"
    let content: String
    let toolCalls: [ToolCall]?
    let toolCallId: String?

    init(role: String, content: String, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

struct ToolCall {
    let id: String
    let function: FunctionCall

    struct FunctionCall {
        let name: String
        let arguments: [String: Any]
    }
}

class RecursiveAI: ObservableObject {
    @Published var isProcessing = false
    @Published var currentStep = ""
    @Published var progress: Double = 0.0

    private let noteAnalyzer = NoteAnalyzer()
    private let handwritingRecognizer = HandwritingRecognizer()
    private var storageManager: StorageManager?

    init(storageManager: StorageManager? = nil) {
        self.storageManager = storageManager
    }

    func analyzeNoteWithAI(_ note: Note, storageManager: StorageManager) async -> IntelligentAnalysis {
        await MainActor.run {
            isProcessing = true
            currentStep = "Initializing AI analysis..."
            progress = 0.1
        }

        // Create tools for AI to use
        let tools = createAnalysisTools(for: note, storageManager: storageManager)

        // Start recursive analysis conversation
        var conversation = AIConversation(tools: tools)
        conversation.context["noteId"] = note.id.uuidString
        conversation.context["noteTitle"] = note.title

        // System prompt for intelligent analysis
        let systemPrompt = """
        You are an intelligent note analysis assistant. Your goal is to deeply analyze the provided note and help the user improve their understanding and note-taking.

        Available tools:
        - search_related_notes: Find notes related to the current topic
        - extract_handwriting: Get text from handwritten content
        - analyze_content_gaps: Identify missing information or incomplete thoughts
        - find_key_concepts: Extract main concepts and definitions
        - suggest_connections: Find relationships between ideas

        Instructions:
        1. Use the extract_handwriting tool to get all text content
        2. Use analyze_content_gaps to identify areas for improvement
        3. Use search_related_notes to find connections
        4. Use find_key_concepts to extract important information
        5. Use suggest_connections to identify relationships
        6. Provide comprehensive analysis with actionable suggestions

        IMPORTANT: You may use basic text formatting like **bold text** and *italic text* for emphasis, but avoid complex markdown like code blocks, headers (#), lists (- or 1.), or other special formatting. Keep responses clean with simple line breaks and basic emphasis formatting only.

        Respond with specific, actionable insights that help the user learn and improve their notes.
        """

        conversation.messages.append(AIMessage(role: "system", content: systemPrompt))

        // Initial user prompt
        let userPrompt = """
        Please analyze this note comprehensively:

        Title: \(note.title)
        Subject: \(note.subject)
        Typed content: \(note.content)
        Pages with drawings: \(note.drawingDataByPage.keys.joined(separator: ", "))

        I want you to:
        1. Extract and analyze all handwritten content
        2. Identify knowledge gaps or incomplete thoughts
        3. Find connections to my other notes
        4. Suggest improvements and next steps
        5. Provide a comprehensive summary with actionable insights

        Use the available tools to gather information and provide a thorough analysis.
        """

        conversation.messages.append(AIMessage(role: "user", content: userPrompt))

        do {
            let analysis = try await executeRecursiveAnalysis(conversation: conversation)

            await MainActor.run {
                self.isProcessing = false
                self.progress = 1.0
            }

            return analysis

        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.currentStep = "Analysis failed: \(error.localizedDescription)"
            }

            // Return basic analysis on failure
            return await createBasicAnalysis(for: note, storageManager: storageManager)
        }
    }

    private func executeRecursiveAnalysis(conversation: AIConversation) async throws -> IntelligentAnalysis {
        var currentConversation = conversation
        let maxIterations = 5
        var iteration = 0

        await MainActor.run {
            currentStep = "Starting recursive analysis..."
            progress = 0.2
        }

        while iteration < maxIterations {
            iteration += 1
            let currentIteration = iteration
            let currentMaxIterations = maxIterations

            await MainActor.run {
                currentStep = "Analysis step \(currentIteration)/\(currentMaxIterations)..."
                progress = 0.2 + (0.6 * Double(currentIteration) / Double(currentMaxIterations))
            }

            // Send conversation to AI
            let response = try await sendToAI(conversation: currentConversation)

            currentConversation.messages.append(response)

            // Check if AI wants to use tools
            if let toolCalls = response.toolCalls {
                // Execute tool calls
                for toolCall in toolCalls {
                    let toolResult = try await executeToolCall(toolCall, conversation: currentConversation)
                    currentConversation.messages.append(AIMessage(
                        role: "tool",
                        content: toolResult,
                        toolCallId: toolCall.id
                    ))
                }
                continue
            } else {
                // AI provided final response
                break
            }
        }

        await MainActor.run {
            currentStep = "Generating final analysis..."
            progress = 0.9
        }

        // Parse the final AI response into structured analysis
        let finalResponse = currentConversation.messages.last?.content ?? "Analysis completed"
        return try await parseAIAnalysis(finalResponse, conversation: currentConversation)
    }

    private func sendToAI(conversation: AIConversation) async throws -> AIMessage {
        // Convert conversation to OpenRouter API format
        let messages = conversation.messages.map { message in
            ["role": message.role, "content": message.content]
        }

        let requestBody: [String: Any] = [
            "model": ModelConfiguration.getModelId(for: "Matcha Assistant") ?? "x-ai/grok-4-fast:free",
            "messages": messages,
            "temperature": 0.7,
            "tools": conversation.tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": [
                            "type": "object",
                            "properties": tool.parameters.mapValues { ["type": "string", "description": $0] }
                        ]
                    ]
                ]
            }
        ]

        // Use existing OpenRouterAPI to send request (simplified version)
        let response = try await makeOpenRouterRequest(body: requestBody)
        return parseOpenRouterResponse(response)
    }

    private func makeOpenRouterRequest(body: [String: Any]) async throws -> [String: Any] {
        guard let apiKey = EnvironmentManager.shared.getLlmAPIKey(for: "OPENROUTER") else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Matcha Note App", forHTTPHeaderField: "HTTP-Referer")

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        return json
    }

    private func parseOpenRouterResponse(_ response: [String: Any]) -> AIMessage {
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return AIMessage(role: "assistant", content: "I apologize, but I encountered an error processing your request.")
        }

        // Check for tool calls
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            let parsedToolCalls = toolCalls.compactMap { toolCallData -> ToolCall? in
                guard let id = toolCallData["id"] as? String,
                      let function = toolCallData["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argumentsString = function["arguments"] as? String,
                      let argumentsData = argumentsString.data(using: .utf8),
                      let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
                    return nil
                }

                return ToolCall(
                    id: id,
                    function: ToolCall.FunctionCall(name: name, arguments: arguments)
                )
            }

            return AIMessage(role: "assistant", content: content, toolCalls: parsedToolCalls)
        }

        return AIMessage(role: "assistant", content: content)
    }

    private func executeToolCall(_ toolCall: ToolCall, conversation: AIConversation) async throws -> String {
        guard let tool = conversation.tools.first(where: { $0.name == toolCall.function.name }) else {
            throw AIError.toolNotFound
        }

        return try await tool.execute(toolCall.function.arguments)
    }

    private func createAnalysisTools(for note: Note, storageManager: StorageManager) -> [AITool] {
        return [
            AITool(
                name: "extract_handwriting",
                description: "Extract text from handwritten content in the note",
                parameters: [
                    "page": "The page number to extract text from (optional, extracts all if not specified)"
                ]
            ) { [weak self] parameters in
                guard let self = self else { return "Error: Service unavailable" }

                await MainActor.run {
                    self.currentStep = "Extracting handwritten text..."
                }

                let recognizedText = await self.handwritingRecognizer.recognizeTextFromMultiplePages(
                    drawingDataByPage: note.drawingDataByPage
                )

                let result = recognizedText.map { page, text in
                    "Page \(page): \(text)"
                }.joined(separator: "\n\n")

                return result.isEmpty ? "No handwritten text found" : result
            },

            AITool(
                name: "search_related_notes",
                description: "Find notes related to the current topic based on keywords",
                parameters: [
                    "keywords": "Comma-separated keywords to search for"
                ]
            ) { parameters in
                await MainActor.run {
                    self.currentStep = "Searching related notes..."
                }

                guard let keywordsString = parameters["keywords"] as? String else {
                    return "No keywords provided"
                }

                let keywords = keywordsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let relatedNotes = self.findRelatedNotes(to: note, in: storageManager.notes, keywords: keywords)

                if relatedNotes.isEmpty {
                    return "No related notes found"
                }

                return relatedNotes.map { note in
                    "Title: \(note.title)\nSubject: \(note.subject)\nContent preview: \(String(note.content.prefix(150)))..."
                }.joined(separator: "\n\n")
            },

            AITool(
                name: "analyze_content_gaps",
                description: "Identify missing information or incomplete thoughts in the content",
                parameters: [
                    "content": "The content to analyze for gaps"
                ]
            ) { [weak self] parameters in
                guard let self = self else { return "Error: Service unavailable" }

                await MainActor.run {
                    self.currentStep = "Analyzing content gaps..."
                }

                let analysis = await self.noteAnalyzer.analyzeNote(note)
                let gaps = analysis.gaps

                if gaps.isEmpty {
                    return "No significant content gaps identified"
                }

                return gaps.map { gap in
                    "Gap Type: \(gap.type)\nDescription: \(gap.description)\nSuggested Action: \(gap.suggestedAction)"
                }.joined(separator: "\n\n")
            },

            AITool(
                name: "find_key_concepts",
                description: "Extract main concepts, definitions, and key points from the content",
                parameters: [
                    "content": "The content to analyze for key concepts"
                ]
            ) { [weak self] parameters in
                guard let self = self else { return "Error: Service unavailable" }

                await MainActor.run {
                    self.currentStep = "Finding key concepts..."
                }

                let analysis = await self.noteAnalyzer.analyzeNote(note)
                let insights = analysis.insights

                var result = ""
                if !insights.mainTopics.isEmpty {
                    result += "Main Topics: \(insights.mainTopics.joined(separator: ", "))\n\n"
                }
                if !insights.keyDefinitions.isEmpty {
                    result += "Key Definitions:\n"
                    for (term, definition) in insights.keyDefinitions {
                        result += "- \(term): \(definition)\n"
                    }
                    result += "\n"
                }
                if !insights.questions.isEmpty {
                    result += "Questions Found: \(insights.questions.joined(separator: "; "))\n\n"
                }

                return result.isEmpty ? "No key concepts identified" : result
            },

            AITool(
                name: "suggest_connections",
                description: "Find potential connections between ideas and concepts",
                parameters: [
                    "concepts": "The concepts to find connections for"
                ]
            ) { parameters in
                await MainActor.run {
                    self.currentStep = "Suggesting connections..."
                }

                let analysis = await self.noteAnalyzer.analyzeNote(note, relatedNotes: storageManager.notes)
                let connections = analysis.insights.connections

                if connections.isEmpty {
                    return "No significant connections identified"
                }

                return "Potential Connections:\n" + connections.joined(separator: "\n")
            }
        ]
    }

    private func findRelatedNotes(to note: Note, in allNotes: [Note], keywords: [String]) -> [Note] {
        return allNotes.filter { otherNote in
            otherNote.id != note.id && (
                keywords.contains { keyword in
                    otherNote.title.lowercased().contains(keyword.lowercased()) ||
                    otherNote.content.lowercased().contains(keyword.lowercased()) ||
                    otherNote.subject.lowercased().contains(keyword.lowercased())
                }
            )
        }.prefix(5).map { $0 }
    }

    private func parseAIAnalysis(_ response: String, conversation: AIConversation) async throws -> IntelligentAnalysis {
        // Extract the analysis results from conversation context and AI response
        let noteId = UUID(uuidString: conversation.context["noteId"] as? String ?? "") ?? UUID()

        return IntelligentAnalysis(
            noteId: noteId,
            summary: response,
            keyInsights: extractInsights(from: response),
            suggestions: extractSuggestions(from: response),
            relatedNotes: extractRelatedNoteIds(from: conversation),
            handwritingAnalysis: extractHandwritingAnalysis(from: conversation),
            contentGaps: extractContentGaps(from: conversation),
            timestamp: Date()
        )
    }

    private func createBasicAnalysis(for note: Note, storageManager: StorageManager) async -> IntelligentAnalysis {
        let basicAnalysis = await noteAnalyzer.analyzeNote(note, relatedNotes: storageManager.notes)

        return IntelligentAnalysis(
            noteId: note.id,
            summary: "Basic analysis completed. \(basicAnalysis.suggestions.count) suggestions generated.",
            keyInsights: basicAnalysis.insights.mainTopics,
            suggestions: basicAnalysis.suggestions.map { $0.title },
            relatedNotes: [],
            handwritingAnalysis: "Handwriting analysis available",
            contentGaps: basicAnalysis.gaps.map { $0.description },
            timestamp: Date()
        )
    }

    // Helper methods for parsing AI responses
    private func extractInsights(from response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        return lines.filter { line in
            line.lowercased().contains("insight") || line.lowercased().contains("key point") || line.lowercased().contains("important")
        }.prefix(5).map { String($0) }
    }

    private func extractSuggestions(from response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        return lines.filter { line in
            line.lowercased().contains("suggest") || line.lowercased().contains("recommend") || line.lowercased().contains("consider")
        }.prefix(5).map { String($0) }
    }

    private func extractRelatedNoteIds(from conversation: AIConversation) -> [UUID] {
        // Extract note IDs from tool responses that mentioned related notes
        return []
    }

    private func extractHandwritingAnalysis(from conversation: AIConversation) -> String {
        // Find handwriting extraction results in conversation
        let handwritingMessages = conversation.messages.filter { message in
            message.role == "tool" && message.content.contains("Page")
        }

        return handwritingMessages.first?.content ?? "No handwriting analysis available"
    }

    private func extractContentGaps(from conversation: AIConversation) -> [String] {
        // Extract gap analysis from tool responses
        let gapMessages = conversation.messages.filter { message in
            message.role == "tool" && message.content.contains("Gap Type")
        }

        return gapMessages.map { $0.content }
    }
}

struct IntelligentAnalysis {
    let noteId: UUID
    let summary: String
    let keyInsights: [String]
    let suggestions: [String]
    let relatedNotes: [UUID]
    let handwritingAnalysis: String
    let contentGaps: [String]
    let timestamp: Date
}

enum AIError: Error {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case toolNotFound
    case analysisTimeout

    var localizedDescription: String {
        switch self {
        case .missingAPIKey:
            return "Missing API key for AI service"
        case .invalidURL:
            return "Invalid AI service URL"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .toolNotFound:
            return "Requested AI tool not found"
        case .analysisTimeout:
            return "AI analysis timed out"
        }
    }
}