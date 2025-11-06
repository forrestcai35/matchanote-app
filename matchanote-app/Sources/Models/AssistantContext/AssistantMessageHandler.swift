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

        // Don't analyze for general questions without note context
        if isGeneralQuestion {
            return false
        }

        // Return true if any analysis trigger is detected
        return hasDirectAnalysis || hasNotePossessive || hasAnalysisAction ||
               hasContentInquiry || hasNuancedPattern
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
    ///   - existingTextBoxesByPage: Existing textboxes for collision detection (optional)
    ///   - subscriptionManager: Subscription manager to check user tier (optional)
    /// - Returns: AI response and generated media items, plus optional auto-fill result
    func sendIntelligentMessage(
        input: String,
        note: Note?,
        storageManager: StorageManager,
        mediaItems: [MediaItem],
        mentions: [Mention],
        mentionManager: MentionManager?,
        selectedModel: String,
        conversationHistory: [ChatMessage],
        existingTextBoxesByPage: [Int: [TextBox]]? = nil,
        subscriptionManager: SubscriptionManager? = nil
    ) async throws -> (response: String, mediaItems: [MediaItem], autoFillResult: AutoFillResult?) {

        // Check if auto-fill is enabled and requested
        if PreferencesManager.shared.assistantAutoFill,
           AutoFillHandler.shared.shouldAutoFill(input: input),
           let note = note {

            // Check if user is PRO (auto-fill is PRO-only feature)
            let userTier = subscriptionManager?.getEffectiveProfile()?.subscriptionTier ?? .free
            guard userTier == .pro else {
                // Return upgrade message for non-PRO users
                let upgradeMessage = "Auto-fill is a PRO feature. Upgrade to PRO to automatically fill out worksheets and forms with AI assistance."
                return (upgradeMessage, mediaItems, nil)
            }

            // Process auto-fill for PRO users
            let autoFillResult = try await AutoFillHandler.shared.processAutoFill(
                note: note,
                query: input,
                model: selectedModel,
                storageManager: storageManager,
                existingTextBoxesByPage: existingTextBoxesByPage
            )

            // Return a simple confirmation message plus the auto-fill result
            let confirmationMessage = "✓ \(autoFillResult.message). You can review and undo if needed."
            return (confirmationMessage, mediaItems, autoFillResult)
        }

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

        // If analysis needed, get note images and build context
        if needsAnalysis, let note = note {
            // Get latest saved note
            guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
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

        // Send to LLM
        let response = try await LlmAPI.sendMessage(
            userMessage: contextualPrompt,
            model_string: selectedModel,
            mediaItems: finalMediaItems.isEmpty ? nil : finalMediaItems,
            conversationHistory: conversationHistory
        )

        return (response, finalMediaItems, nil)
    }
}
