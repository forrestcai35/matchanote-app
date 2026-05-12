import Foundation

/// Handles intelligent message routing and note analysis for the AI assistant
class AssistantMessageHandler {

    // MARK: - Singleton
    static let shared = AssistantMessageHandler()

    private init() {}

    // MARK: - Message Analysis

    /// Determine if a user query requires note analysis
    /// - Parameters:
    ///   - input: User's input message
    ///   - hasNote: Whether a note is currently open
    /// - Returns: True if the query should trigger note analysis
    func shouldAnalyzeNote(input: String, hasNote: Bool) -> Bool {
        guard hasNote else { return false }

        let lowercaseInput = input.lowercased()

        // Direct analysis keywords
        let directAnalysisKeywords = [
            "analyze", "summarize", "explain", "review", "check",
            "what's in", "what is in", "what's on", "what is on",
            "look at", "examine", "study", "go through",
            "tell me about", "show me", "describe",
            "read", "interpret", "understand"
        ]

        // Note-specific possessive patterns
        let notePossessivePatterns = [
            "my note", "this note", "the note", "my notes", "these notes",
            "my writing", "this writing", "the writing",
            "my page", "this page", "the page",
            "my work", "this work", "the work"
        ]

        // Analysis action verbs
        let analysisActionVerbs = [
            "summarize", "explain", "analyze", "review", "check", "examine",
            "help me with", "look at", "go through", "walk through", "break down"
        ]

        // Content inquiry patterns
        let contentInquiryPatterns = [
            "what does", "what's in", "what did i write", "what did i",
            "what's written", "what's on", "what's about", "what contains"
        ]

        // General question words that DON'T need analysis (unless note-specific)
        let generalQuestionWords = [
            "what is", "how do", "why does", "when should", "where can"
        ]

        // Check for direct analysis keywords
        let hasDirectAnalysis = directAnalysisKeywords.contains { keyword in
            lowercaseInput.contains(keyword)
        }

        // Check for note-specific possessive patterns
        let hasNotePossessive = notePossessivePatterns.contains { pattern in
            lowercaseInput.contains(pattern)
        }

        // Check for action verbs + note context
        let hasAnalysisAction = analysisActionVerbs.contains { verb in
            lowercaseInput.contains(verb) && (
                lowercaseInput.contains("note") ||
                lowercaseInput.contains("writing") ||
                lowercaseInput.contains("content") ||
                lowercaseInput.contains("page") ||
                lowercaseInput.contains("drawing")
            )
        }

        // Check for content inquiry patterns
        let hasContentInquiry = contentInquiryPatterns.contains { pattern in
            lowercaseInput.contains(pattern) && (
                lowercaseInput.contains("note") ||
                lowercaseInput.contains("writing") ||
                lowercaseInput.contains("page") ||
                lowercaseInput.contains("drawing") ||
                lowercaseInput.contains("this") ||
                lowercaseInput.contains("my")
            )
        }

        // Check if it's a general question without note context
        let isGeneralQuestion = generalQuestionWords.contains { pattern in
            lowercaseInput.hasPrefix(pattern)
        } && !hasNotePossessive && !lowercaseInput.contains("note")

        // Advanced pattern matching for nuanced requests
        let nuancedPatterns = [
            // Questions about specific content
            "what note", "what writing", "what page", "what drawing",
            "how note", "how writing", "how page", "how drawing",
            "can you note", "can you writing", "can you page", "can you drawing",
            "help me note", "help me writing", "help me page", "help me drawing",
            "show me note", "show me writing", "show me page", "show me drawing",

            // Requests for interpretation
            "what does this mean", "what does this say", "what does this show", "what does this represent",
            "what does my mean", "what does my say", "what does my show", "what does my represent",
            "what does the mean", "what does the say", "what does the show", "what does the represent",

            // Requests for analysis
            "can you analyze", "can you review", "can you check", "can you examine",
            "help me understand", "help me figure out", "help me make sense",
            "what do you think", "what do you see", "what do you notice", "what do you observe"
        ]

        let hasNuancedPattern = nuancedPatterns.contains { pattern in
            lowercaseInput.contains(pattern)
        }

        // Pattern for explicit numbered tasks (e.g. "question 5", "number 2", "q 1", "q1", "1a", "1", "1.", "1)") 
        // We'll broaden this to capture standalone numbers or numbers with a single letter (like 1a) if they follow task verbs.
        let numberedTaskPattern = #/(^|\s)(question|q|number|#|no\.?)?\s*\d+[a-zA-Z]?/#
        // Task completion verbs
        let taskCompletionVerbs = [
            "answer", "solve", "complete", "do", "finish", "help me with", "help with",
            "figure out", "work out", "calculate"
        ]
        
        // Check for direct task completion or numbered tasks
        let hasTaskPattern = taskCompletionVerbs.contains { verb in
            lowercaseInput.contains(verb)
        } && (
            (try? numberedTaskPattern.firstMatch(in: lowercaseInput)) != nil ||
            lowercaseInput.contains("question") ||
            lowercaseInput.contains("problem") ||
            lowercaseInput.contains("exercise") ||
            lowercaseInput.contains("assignment") ||
            lowercaseInput.contains("worksheet")
        )

        // Generalized action/command prompts
        let actionPrefixes = [
            "can you ", "could you ", "would you ", "will you ", "please ",
            "help ", "i need ", "i want ", "let's ", "lets "
        ]
        
        // Starting with an imperative verb
        let imperativeVerbs = [
            "write ", "create ", "make ", "generate ", "give ", "find ", "solve ", 
            "answer ", "do ", "complete ", "finish ", "calculate ", "evaluate ", 
            "translate ", "fix ", "correct ", "proofread ", "summarize ", "explain ", 
            "analyze ", "review ", "check ", "examine ", "list ", "compare ", "define "
        ]
        
        // Common phrases that imply working on something
        let taskPhrases = [
            "help with", "figure out", "work out", "help me", "do this", "solve this", "answer this"
        ]

        let isActionPrompt = actionPrefixes.contains { lowercaseInput.hasPrefix($0) } ||
                             imperativeVerbs.contains { lowercaseInput.hasPrefix($0) } ||
                             taskPhrases.contains { lowercaseInput.contains($0) }

        // Don't analyze for general questions without note context, task pattern, or action prompt
        if isGeneralQuestion && !hasTaskPattern && !isActionPrompt {
            return false
        }

        // Return true if any analysis trigger is detected
        return hasDirectAnalysis || hasNotePossessive || hasAnalysisAction ||
               hasContentInquiry || hasNuancedPattern || hasTaskPattern || isActionPrompt
    }

    // MARK: - Context Building

    /// Build contextual prompt with note information
    /// - Parameters:
    ///   - userInput: User's original question
    ///   - note: Note being analyzed
    ///   - textContent: Extracted text content from note
    ///   - mentionContext: Context from mentioned items (optional)
    /// - Returns: Formatted contextual prompt
    func buildNoteAnalysisPrompt(
        userInput: String,
        note: Note,
        textContent: String,
        mentionContext: String = ""
    ) -> String {
        var prompt = """
        User question: \(userInput)

        I've provided images of the note for visual analysis. Please examine the note content (both typed text and handwritten content) and answer the user's question based on what you can see in the note.

        Note details:
        Title: \(note.title)
        Subject: \(note.subject)
        """

        // Add text content if available
        if !textContent.isEmpty {
            prompt += "\n\nTyped text content:\n\(textContent)"
        }

        // Add mention context if provided
        if !mentionContext.isEmpty {
            prompt += mentionContext
        }

        return prompt
    }

    /// Extract all text content from a note
    /// - Parameter note: Note to extract text from
    /// - Returns: Combined text content
    func extractTextContent(from note: Note) -> String {
        var contentString = note.title + "\n" + note.subject + "\n" + note.content

        // Extract text from text boxes
        for (_, textBoxes) in note.textBoxDataByPage {
            for textBoxData in textBoxes {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
                    contentString += "\n" + textBox.text
                }
            }
        }

        return contentString
    }

    // MARK: - Message Sending

    /// Send an intelligent message with optional note context
    /// - Parameters:
    ///   - input: User's input message
    ///   - note: Current note (optional)
    ///   - storageManager: Storage manager to get latest note
    ///   - mediaItems: Additional media items from user
    ///   - mentions: Mentioned items
    ///   - mentionManager: Mention manager for context
    ///   - selectedModel: Model to use
    ///   - conversationHistory: Previous messages
    /// - Returns: AI response and generated media items
    func sendIntelligentMessage(
        input: String,
        note: Note?,
        storageManager: StorageManager,
        mediaItems: [MediaItem],
        mentions: [Mention],
        mentionManager: MentionManager?,
        selectedModel: String,
        conversationHistory: [ChatMessage]
    ) async throws -> (response: String, mediaItems: [MediaItem]) {

        // Determine if note analysis is needed
        let needsAnalysis = shouldAnalyzeNote(input: input, hasNote: note != nil)

        var finalMediaItems = mediaItems
        var contextualPrompt = input

        // Add mention context
        var mentionContext = ""
        if !mentions.isEmpty, let mentionManager = mentionManager {
            mentionContext = mentionManager.getContextForMentions(mentions)
            if !mentionContext.isEmpty {
                mentionContext = "\n\n--- Referenced Items ---\(mentionContext)"
            }
        }

        // Determine which note to analyze (mentioned notes take priority over current note)
        var noteToAnalyze: Note? = nil
        if needsAnalysis {
            // Priority 1: If mentions exist and contain a note, use the mentioned note
            if !mentions.isEmpty {
                // Find first note mention
                if let firstNoteMention = mentions.first(where: { $0.type == .note }) {
                    // Try to find the mentioned note in storage
                    noteToAnalyze = storageManager.notes.first(where: { $0.id.uuidString == firstNoteMention.id })

                    if noteToAnalyze != nil {
                        print("📌 MENTION PRIORITY: Using mentioned note '\(firstNoteMention.displayName)' instead of current note")
                    }
                }
            }

            // Priority 2: Fall back to current note if no mentioned note found
            if noteToAnalyze == nil, let note = note {
                noteToAnalyze = note
                print("📌 Using current note (no mentioned note found)")
            }
        }

        // If analysis needed, get note images and build context
        if let noteToAnalyze = noteToAnalyze {
            // Get latest saved note
            guard let latestNote = storageManager.notes.first(where: { $0.id == noteToAnalyze.id }) else {
                throw NSError(
                    domain: "AssistantMessageHandler",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find latest note data for analysis"]
                )
            }

            // Generate note images with intelligent page selection
            // Support up to 20 pages for large worksheets/notes
            let noteImages = await NoteContextProvider.shared.generateMediaItems(
                from: latestNote,
                userQuery: input,
                maxPages: 20,
                scale: 0.6
            )
            finalMediaItems.append(contentsOf: noteImages)

            // Extract text content
            let textContent = extractTextContent(from: latestNote)

            // Build rich context prompt
            contextualPrompt = buildNoteAnalysisPrompt(
                userInput: input,
                note: latestNote,
                textContent: textContent,
                mentionContext: mentionContext
            )
        } else if !mentionContext.isEmpty {
            // Add mention context even without note analysis
            contextualPrompt += mentionContext
        }

        // Send to LLM via secure backend
        let response = try await SecureLlmAPI.sendMessageCompat(
            userMessage: contextualPrompt,
            model_string: selectedModel,
            mediaItems: finalMediaItems.isEmpty ? nil : finalMediaItems,
            conversationHistory: conversationHistory,
            systemPrompt: .concise
        )

        return (response, finalMediaItems)
    }
    /// Stream an intelligent message with optional note context
    /// - Returns: Tuple containing the response stream and generated media items
    func streamIntelligentMessage(
        input: String,
        note: Note?,
        storageManager: StorageManager,
        mediaItems: [MediaItem],
        mentions: [Mention],
        mentionManager: MentionManager?,
        selectedModel: String,
        conversationHistory: [ChatMessage]
    ) async throws -> (stream: AsyncThrowingStream<String, Error>, mediaItems: [MediaItem]) {

        // Determine if note analysis is needed
        let needsAnalysis = shouldAnalyzeNote(input: input, hasNote: note != nil)

        var finalMediaItems = mediaItems
        var contextualPrompt = input

        // Add mention context
        var mentionContext = ""
        if !mentions.isEmpty, let mentionManager = mentionManager {
            mentionContext = mentionManager.getContextForMentions(mentions)
            if !mentionContext.isEmpty {
                mentionContext = "\n\n--- Referenced Items ---\(mentionContext)"
            }
        }

        // Determine which note to analyze (mentioned notes take priority over current note)
        var noteToAnalyze: Note? = nil
        if needsAnalysis {
            // Priority 1: If mentions exist and contain a note, use the mentioned note
            if !mentions.isEmpty {
                // Find first note mention
                if let firstNoteMention = mentions.first(where: { $0.type == .note }) {
                    // Try to find the mentioned note in storage
                    noteToAnalyze = storageManager.notes.first(where: { $0.id.uuidString == firstNoteMention.id })

                    if noteToAnalyze != nil {
                        print("📌 MENTION PRIORITY: Using mentioned note '\(firstNoteMention.displayName)' instead of current note")
                    }
                }
            }

            // Priority 2: Fall back to current note if no mentioned note found
            if noteToAnalyze == nil, let note = note {
                noteToAnalyze = note
                print("📌 Using current note (no mentioned note found)")
            }
        }

        // If analysis needed, get note images and build context
        if let noteToAnalyze = noteToAnalyze {
            // Get latest saved note
            guard let latestNote = storageManager.notes.first(where: { $0.id == noteToAnalyze.id }) else {
                throw NSError(
                    domain: "AssistantMessageHandler",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find latest note data for analysis"]
                )
            }

            // Generate note images with intelligent page selection
            let noteImages = await NoteContextProvider.shared.generateMediaItems(
                from: latestNote,
                userQuery: input,
                maxPages: 20,
                scale: 0.6
            )
            finalMediaItems.append(contentsOf: noteImages)

            // Extract text content
            let textContent = extractTextContent(from: latestNote)

            // Build rich context prompt
            contextualPrompt = buildNoteAnalysisPrompt(
                userInput: input,
                note: latestNote,
                textContent: textContent,
                mentionContext: mentionContext
            )
        } else if !mentionContext.isEmpty {
            // Add mention context even without note analysis
            contextualPrompt += mentionContext
        }

        // Get the stream from secure backend
        let stream = SecureLlmAPI.streamMessageCompat(
            userMessage: contextualPrompt,
            model_string: selectedModel,
            mediaItems: finalMediaItems.isEmpty ? nil : finalMediaItems,
            conversationHistory: conversationHistory,
            systemPrompt: .concise
        )

        return (stream, finalMediaItems)
    }
}
