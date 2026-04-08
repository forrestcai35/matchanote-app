import SwiftUI
import PencilKit
import Foundation

#if canImport(UIKit)
  import UIKit
  import PhotosUI
#elseif canImport(AppKit)
  import AppKit
#endif

// MARK: - Assistant Mode Types
enum AssistantMode {
    case chat
    case study
}

enum StudySubMode {
    case quiz
    case flashcards
}

// Shared types
struct ChatMessage: Identifiable {
  let id = UUID()
  var content: String
  let isUser: Bool
  let model: String
  var mediaItems: [MediaItem]? = nil
  var isComplete: Bool

  init(content: String, isUser: Bool, model: String = "", mediaItems: [MediaItem]? = nil, isComplete: Bool = true) {
    self.content = content
    self.isUser = isUser
    self.model = model
    self.mediaItems = mediaItems
    self.isComplete = isComplete
  }
}

struct MediaItem: Identifiable {
  let id = UUID()
  let data: Data
  let type: MediaType

  enum MediaType {
    case image
    case file(String)
  }
}


//  AI Assistant State
class AIAssistantState: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var userInput = "" {
        didSet {
            // Debounce user input changes to reduce UI updates
            if userInput != oldValue {
                userInputDebounceTimer?.invalidate()
                userInputDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    // Optional: Add any debounced logic here if needed
                }
            }
        }
    }
    @Published var selectedModel = ""
    @Published var isLoading = false  // For chat operations only
    @Published var isGeneratingQuiz = false  // For quiz generation
    @Published var isGeneratingFlashcards = false  // For flashcard generation
    @Published var quizGenerationError = false  // Error state for quiz generation
    @Published var flashcardGenerationError = false  // Error state for flashcard generation
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels: [String] = []
    @Published var subscriptionManager = SubscriptionManager()
    @Published var chatStorage = ChatStorageManager.shared
    @Published var showingChatHistory = false
    
    // Task management to prevent race conditions
    var currentMessageTask: Task<Void, Never>?

    // AI capabilities

    /// Current note being viewed - automatically updates when user switches tabs/notes
    /// - Chat mode: AI uses this note's context for all queries (global chat with note-aware context)
    /// - Study mode: Loads/switches quiz/flashcards for this specific note
    @Published var currentNote: Note?

    // Study Mode properties
    @Published var currentMode: AssistantMode = .chat
    @Published var studySubMode: StudySubMode = .quiz
    @Published var studySession: StudySession?
    @Published var isAnalyzingContent = false
    @Published var canEnableStudyMode = false
    @Published var studyModeMessage: String?
    @Published var studyStorage = StudyStorageManager.shared

    // Mention system for @-tagging notes, folders, subjects
    var mentionManager: MentionManager?

    // Callback for saving canvas data before AI analysis
    var saveCanvasDataCallback: (() -> Void)?

    // Callback for handling auto-fill results
    var autoFillCallback: ((AutoFillResult) -> Void)?

    // Performance optimization
    private var userInputDebounceTimer: Timer?

    deinit {
        userInputDebounceTimer?.invalidate()
        currentMessageTask?.cancel()
    }
    
    // Load conversation from storage
    func loadConversation(_ conversation: ChatConversation) {
        messages = conversation.messages
        chatStorage.selectConversation(conversation)
    }
    
    // Start a new conversation
    func startNewConversation() {
        messages = []
        chatStorage.createNewConversation(noteId: currentNote?.id)
    }
    
    // Save current conversation
    func saveCurrentConversation() {
        chatStorage.updateCurrentConversation(with: messages)
    }

    // MARK: - Study Mode Functions

    /// Analyze note content to determine if study mode can be enabled
    func analyzeNoteForStudy(note: Note, storageManager: StorageManager, saveCanvasCallback: @escaping () -> Void) async {
        await MainActor.run {
            isAnalyzingContent = true
            canEnableStudyMode = false
            studyModeMessage = nil
        }

        // Save canvas data first
        saveCanvasCallback()

        // Get latest note
        guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
            await MainActor.run {
                isAnalyzingContent = false
                canEnableStudyMode = false
                studyModeMessage = "Note not found"
            }
            return
        }

        // Check cache first
        if studyStorage.isCacheValid(for: latestNote) {
            await MainActor.run {
                canEnableStudyMode = true
                isAnalyzingContent = false
                studySession = studyStorage.loadSession(for: latestNote.id)
            }
            return
        }

        // Build content string for analysis
        var contentString = latestNote.title + "\n" + latestNote.subject + "\n" + latestNote.content

        // Add text from text boxes
        for (_, textBoxes) in latestNote.textBoxDataByPage {
            for textBoxData in textBoxes {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
                    contentString += "\n" + textBox.text
                }
            }
        }

        // Convert note pages to images for visual analysis (overview query for study mode analysis)
        let noteImages = await convertNoteToImages(latestNote, userQuery: "overview of educational content")

        // Use LLM via secure backend with contentAnalysis prompt to analyze if content is educational
        do {
            let response = try await SecureLlmAPI.sendMessageCompat(
                userMessage: contentString.isEmpty
                    ? "Analyze the provided note images to determine if they contain educational content suitable for generating quizzes and flashcards."
                    : "Analyze this note content and images:\n\n\(contentString)",
                model_string: selectedModel.isEmpty ? "Matcha Assistant" : selectedModel,
                mediaItems: noteImages.isEmpty ? nil : noteImages,
                conversationHistory: nil,
                systemPrompt: .contentAnalysis
            )

            // Better response parsing - look for YES/NO anywhere in first line
            let firstLine = response.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
            let isEducational = firstLine.contains("YES")

            await MainActor.run {
                canEnableStudyMode = isEducational
                isAnalyzingContent = false

                if !isEducational {
                    // Extract reason from response if available
                    let lines = response.components(separatedBy: .newlines)
                    if lines.count > 1 {
                        studyModeMessage = lines[1...].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        studyModeMessage = "Add more educational content to unlock Study Mode"
                    }
                } else {
                    // Create new session
                    studySession = studyStorage.getOrCreateSession(for: latestNote)
                }
            }
        } catch {
            await MainActor.run {
                isAnalyzingContent = false
                canEnableStudyMode = false
                studyModeMessage = "Could not analyze content: \(error.localizedDescription)"
            }
        }
    }

    /// Generate quiz questions for current note
    func generateQuizQuestions(note: Note, storageManager: StorageManager, count: Int = 10, regenerate: Bool = false) async throws {
        // Get latest note
        guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
            throw NSError(domain: "StudyMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Note not found"])
        }

        // Build content string
        var contentString = latestNote.title + "\n" + latestNote.subject + "\n" + latestNote.content

        for (_, textBoxes) in latestNote.textBoxDataByPage {
            for textBoxData in textBoxes {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
                    contentString += "\n" + textBox.text
                }
            }
        }

        // Convert note pages to images for visual analysis (overview for quiz generation)
        let noteImages = await convertNoteToImages(latestNote, userQuery: "generate quiz questions from all content")

        await MainActor.run {
            isGeneratingQuiz = true
            quizGenerationError = false
            errorMessage = nil
        }

        do {
            let response = try await SecureLlmAPI.sendMessageCompat(
                userMessage: contentString.isEmpty
                    ? "Generate \(count) quiz questions from the provided note images."
                    : "Generate \(count) quiz questions from this content and images:\n\n\(contentString)",
                model_string: selectedModel.isEmpty ? "Matcha Assistant" : selectedModel,
                mediaItems: noteImages.isEmpty ? nil : noteImages,
                conversationHistory: nil,
                systemPrompt: .quizGeneration
            )

            // Extract JSON from response (handle markdown code blocks)
            let jsonString = JSONExtractor.extractJSON(from: response, repair: true, verbose: true)
            print("📋 Extracted JSON string (first 200 chars): \(String(jsonString.prefix(200)))")

            // Parse JSON response
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("❌ Failed to convert extracted string to data")
                throw NSError(domain: "StudyMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to data"])
            }
            
            do {
                let decoded = try JSONDecoder().decode([String: [QuizQuestion]].self, from: jsonData)
                guard let questions = decoded["questions"] else {
                    print("❌ JSON decoded but 'questions' key not found")
                    throw NSError(domain: "StudyMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Questions array not found in response"])
                }
                
                print("✅ Successfully decoded \(questions.count) quiz questions")
                
                await MainActor.run {
                    if var session = studySession {
                        if regenerate {
                            session.setQuizQuestions(questions)
                        } else {
                            session.addQuizQuestions(questions)
                        }
                        studySession = session
                        studyStorage.saveSession(session)
                    }
                    isGeneratingQuiz = false
                    quizGenerationError = false
                }
            } catch {
                print("❌ JSON decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("📝 Detailed decoding error: \(decodingError)")
                }
                print("📄 Extracted JSON: \(jsonString)")
                throw NSError(domain: "StudyMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse quiz questions: \(error.localizedDescription)"])
            }
        } catch {
            await MainActor.run {
                // Don't set errorMessage here - it's displayed in chat section
                // QuizView handles this error with quizGenerationError flag
                isGeneratingQuiz = false
                quizGenerationError = true
            }
            throw error
        }
    }

    /// Generate flashcards for current note
    func generateFlashcards(note: Note, storageManager: StorageManager, count: Int = 15, regenerate: Bool = false) async throws {
        // Get latest note
        guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
            throw NSError(domain: "StudyMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Note not found"])
        }

        // Build content string
        var contentString = latestNote.title + "\n" + latestNote.subject + "\n" + latestNote.content

        for (_, textBoxes) in latestNote.textBoxDataByPage {
            for textBoxData in textBoxes {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: textBoxData) {
                    contentString += "\n" + textBox.text
                }
            }
        }

        // Convert note pages to images for visual analysis (overview for flashcard generation)
        let noteImages = await convertNoteToImages(latestNote, userQuery: "generate flashcards from all content")

        await MainActor.run {
            isGeneratingFlashcards = true
            flashcardGenerationError = false
            errorMessage = nil
        }

        do {
            let response = try await SecureLlmAPI.sendMessageCompat(
                userMessage: contentString.isEmpty
                    ? "Generate \(count) flashcards from the provided note images."
                    : "Generate \(count) flashcards from this content and images:\n\n\(contentString)",
                model_string: selectedModel.isEmpty ? "Matcha Assistant" : selectedModel,
                mediaItems: noteImages.isEmpty ? nil : noteImages,
                conversationHistory: nil,
                systemPrompt: .flashcardGeneration
            )

            // Extract JSON from response (handle markdown code blocks)
            let jsonString = JSONExtractor.extractJSON(from: response, repair: true, verbose: true)
            print("📋 Extracted JSON string (first 200 chars): \(String(jsonString.prefix(200)))")

            // Parse JSON response
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("❌ Failed to convert extracted string to data")
                throw NSError(domain: "StudyMode", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to data"])
            }
            
            do {
                let decoded = try JSONDecoder().decode([String: [Flashcard]].self, from: jsonData)
                guard let flashcards = decoded["flashcards"] else {
                    print("❌ JSON decoded but 'flashcards' key not found")
                    throw NSError(domain: "StudyMode", code: 3, userInfo: [NSLocalizedDescriptionKey: "Flashcards array not found in response"])
                }
                
                print("✅ Successfully decoded \(flashcards.count) flashcards")

                await MainActor.run {
                    if var session = studySession {
                        if regenerate {
                            session.setFlashcards(flashcards)
                        } else {
                            session.addFlashcards(flashcards)
                        }
                        studySession = session
                        studyStorage.saveSession(session)
                    }
                    isGeneratingFlashcards = false
                    flashcardGenerationError = false
                }
            } catch {
                print("❌ JSON decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("📝 Detailed decoding error: \(decodingError)")
                }
                print("📄 Extracted JSON: \(jsonString)")
                throw NSError(domain: "StudyMode", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse flashcards: \(error.localizedDescription)"])
            }
        } catch {
            await MainActor.run {
                // Don't set errorMessage here - it's displayed in chat section
                // FlashcardView handles this error with flashcardGenerationError flag
                isGeneratingFlashcards = false
                flashcardGenerationError = true
            }
            throw error
        }
    }

    // MARK: - Note Context for AI (Delegated to AssistantContext module)

    /// Convert note to images for AI analysis using centralized context provider
    private func convertNoteToImages(_ note: Note, userQuery: String = "") async -> [MediaItem] {
        return await NoteContextProvider.shared.generateMediaItems(
            from: note,
            userQuery: userQuery,
            maxPages: 10,
            scale: 0.6
        )
    }
}

struct AIAssistantView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @State private var showingImagePicker = false
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isInputTargeted = false
    @State private var isTextEditorFocused = false
    @State private var keyboardHeight: CGFloat = 0
    private let inputOuterPadding: CGFloat = 4
    @State private var userScrollTrigger: Int = 0
    @State private var shouldScrollToUserMessage = false
    @State private var selectedMediaItemId: UUID?
    
    // Assistant orientation (passed from parent)
    var assistantOrientation: AssistantOrientation = .right
    
    // Computed property to check if user is PRO
    private var isProUser: Bool {
        state.subscriptionManager.userProfile?.subscriptionTier == .pro
    }

    // MARK: - Mode Toggle Button
    private var modeToggleButton: some View {
        Button(action: {
            // Only allow mode switching for premium/student users
            let userTier = state.subscriptionManager.getEffectiveProfile()?.subscriptionTier ?? .free
            let canSwitchModes = userTier == .pro || userTier == .student

            if canSwitchModes {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.currentMode = state.currentMode == .chat ? .study : .chat
                    // Clear error messages when switching modes to prevent leakage
                    state.errorMessage = nil
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: state.currentMode == .study ? "brain.head.profile" : "bubble.left.and.bubble.right")
                    .font(.jost(.caption()))
                Text(state.currentMode == .study ? "Study" : "Chat")
                    .font(.jost(.caption()))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(LinearGradient.premiumGradient)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(LinearGradient.premiumGradientBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Header Action Buttons
    private var headerActionButtons: some View {
        HStack(spacing: 0) {
            // New chat button - only show when messages exist
            if !state.messages.isEmpty {
                Button(action: {
                    state.startNewConversation()
                }) {
                    Image(systemName: "plus.message")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Chat history dropdown button
            Button(action: {
                // Clean up expired conversations when opening
                if !state.showingChatHistory {
                    state.chatStorage.cleanupExpiredConversations()
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.showingChatHistory.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Chat Mode Content
    private var chatModeContent: some View {
        ZStack {
            VStack(spacing: 0) {
                if state.messages.isEmpty {
                    inputSection
                        .padding(.top, 0)
                    chatHistorySection
                        .padding(.bottom, max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
                } else {
                    chatHistorySection
                        .padding(.bottom, max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
                    inputSection
                        .padding(.top, 0)
                }
            }

            // Overlay mention suggestions above the input
            if let mentionManager = state.mentionManager,
               mentionManager.isShowingSuggestions && !mentionManager.suggestions.isEmpty {

                // Position based on whether messages exist
                if state.messages.isEmpty {
                    // When empty, input is at top - align dropdown to top
                    VStack(spacing: 0) {
                        MentionSuggestionsView(
                            suggestions: mentionManager.suggestions,
                            onSelect: { mention in
                                let newText = mentionManager.insertMention(mention, into: state.userInput)
                                state.userInput = newText
                                mentionManager.clearSuggestions()
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, inputOuterPadding + 100)

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: mentionManager.isShowingSuggestions)
                } else {
                    // When messages exist, input is at bottom - align dropdown to bottom
                    VStack(spacing: 0) {
                        Spacer()

                        MentionSuggestionsView(
                            suggestions: mentionManager.suggestions,
                            onSelect: { mention in
                                let newText = mentionManager.insertMention(mention, into: state.userInput)
                                state.userInput = newText
                                mentionManager.clearSuggestions()
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .offset(y: -max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: mentionManager.isShowingSuggestions)
                    .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with mode toggle and action buttons
            HStack {
                if assistantOrientation == .right {
                    modeToggleButton
                    Spacer()
                    headerActionButtons
                } else {
                    headerActionButtons
                    Spacer()
                    modeToggleButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5),
                alignment: .bottom
            )

            // Conditional content based on mode
            if state.currentMode == .chat {
                chatModeContent
            } else {
                StudyModeView()
                    .transition(.opacity)
            }
        }
        .background(
            (colorScheme == .dark
             ? Color.matchabackground_dark
             : Color.matchabackground_light)
            .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                // Deselect media items when tapping anywhere
                if selectedMediaItemId != nil {
                    selectedMediaItemId = nil
                }
            }
        )
        .onAppear {
            setupAI()
            setupKeyboardObservers()
            // Set initial model immediately to avoid delay
            setInitialModel()
            refreshAvailableModels()

            // Initialize mention manager
            if state.mentionManager == nil {
                state.mentionManager = MentionManager(storageManager: storageManager)
            }

            // Ensure free users are always in chat mode
            let userTier = state.subscriptionManager.getEffectiveProfile()?.subscriptionTier ?? .free
            if userTier == .free && state.currentMode == .study {
                state.currentMode = .chat
            }

            // Start a new conversation if none exists
            if state.chatStorage.currentConversation == nil && state.messages.isEmpty {
                state.startNewConversation()
            }
        }
        .onDisappear {
            removeKeyboardObservers()
            // Cancel any ongoing message task to prevent orphaned tasks
            state.currentMessageTask?.cancel()
        }
        .sheet(isPresented: $showingImagePicker) {
#if canImport(UIKit)
            ImagePickerView(isPresented: $showingImagePicker) { image in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let mediaItem = MediaItem(data: imageData, type: .image)
                    state.tempMediaItems.append(mediaItem)
                }
            }
#endif
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                for url in urls {
#if canImport(UIKit)
                    if url.startAccessingSecurityScopedResource() {
                        handleDroppedMedia(from: url)
                        url.stopAccessingSecurityScopedResource()
                    }
#else
                    handleDroppedMedia(from: url)
#endif
                }
            } catch {
                print("Error importing file: \(error)")
            }
        }
    }
    
    
    private var chatHistorySection: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                    ForEach(state.messages) { message in
                        if message.isUser {
                            UserMessageView(message: message)
                                .id(message.id)
                        } else {
                            AssistantMessageView(message: message)
                                .id(message.id)
                        }
                    }

                    // Show error message inline if there's an error
                    if let error = state.errorMessage, state.currentMode == .chat {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                // Error icon with gradient
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.red.opacity(0.3), Color.orange.opacity(0.2)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.red, Color.orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }

                                // User-friendly error message
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Something went wrong")
                                        .font(.jost(.caption()))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary.opacity(0.9))
                                    
                                    Text(getUserFriendlyErrorMessage(error))
                                        .font(.jost(.caption()))
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }

                                Spacer()
                            }

                            // Retry button with glassy effect
                            Button(action: {
                                retryLastMessage()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Try Again")
                                        .font(.jost(.caption()))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.primary.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                        
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.primary.opacity(0.03))
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.03),
                                                Color.orange.opacity(0.02)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.2),
                                            Color.orange.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.red.opacity(0.08), radius: 12, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                        // Bottom anchor for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("CHAT_BOTTOM")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .background(
                    (colorScheme == .dark
                     ? Color.matchabackground_dark
                     : Color.matchabackground_light)
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
                )

                // Top fade effect
                VStack {
                    (colorScheme == .dark
                        ? Color.matchabackground_dark
                        : Color.matchabackground_light)
                        .brightness(colorScheme == .dark ? -0.05 : 0.05)
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                    Spacer()
                }
            }
            .onAppear {
                // Scroll to bottom on first appear
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                }
            }
            .onChange(of: userScrollTrigger) { _, _ in
                // Scroll to show the user's message, not all the way to bottom
                if shouldScrollToUserMessage {
                    withAnimation(.easeOut(duration: 0.25)) {
                        // Scroll to the last user message instead of bottom
                        if let lastUserMessage = state.messages.last(where: { $0.isUser }) {
                            proxy.scrollTo(lastUserMessage.id, anchor: .center)
                        }
                    }
                    shouldScrollToUserMessage = false
                }
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            // Icons and media items above text input
            HStack(alignment: .center, spacing: 4) {
                // + icon for adding media with larger tap area
                Menu {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Choose Image", systemImage: "photo")
                    }
                    
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import File", systemImage: "doc")
                    }
                    
#if canImport(UIKit)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
#endif
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .font(.jost(.caption()))
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .frame(width: 32, height: 32)
                }
                
                // Media items display (smaller and inline)
                if !state.tempMediaItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(state.tempMediaItems) { item in
                                ZStack(alignment: .topTrailing) {
                                    // Main media content
                                    Group {
                                        if case .image = item.type {
#if canImport(UIKit)
                                            if let uiImage = UIImage(data: item.data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
#endif
                                        } else if case .file(let name) = item.type {
                                            HStack(spacing: 2) {
                                                Image(systemName: "doc")
                                                    .font(.jost(.caption2()))
                                                Text(name)
                                                    .font(.jost(.caption2()))
                                                    .lineLimit(1)
                                            }
                                            .padding(4)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                            .frame(height: 28)
                                        }
                                    }
                                    .onTapGesture {
                                        // Toggle selection
                                        if selectedMediaItemId == item.id {
                                            selectedMediaItemId = nil
                                        } else {
                                            selectedMediaItemId = item.id
                                        }
                                    }

                                    // X button - only show when selected
                                    if selectedMediaItemId == item.id {
                                        Button(action: {
                                            removeMediaItem(item)
                                            selectedMediaItemId = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                                .font(.system(size: 16))
                                        }
                                        .offset(x: 6, y: -6)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .padding(4) // Add padding to prevent cropping
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedMediaItemId)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 40) // Increased to accommodate the X button
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            ZStack(alignment: .bottomTrailing) {
                Group {
                    // Use MentionTextField if mentionManager is available, otherwise fallback to GrowingTextEditor
                    if let mentionManager = state.mentionManager {
                        MentionTextField(
                            text: $state.userInput,
                            isTextEditorFocused: $isTextEditorFocused,
                            mentionManager: mentionManager,
                            placeholderText: "Ask me about your notes...",
                            submitsOnReturn: true,
                            onSubmit: {
                                if (!state.userInput.isEmpty || !state.tempMediaItems.isEmpty) && !state.isLoading {
                                    sendIntelligentMessage()
                                }
                            }
                        )
                    } else {
                        GrowingTextEditor(
                            text: $state.userInput,
                            isTextEditorFocused: $isTextEditorFocused,
                            placeholderText: "Ask me about your notes...",
                            submitsOnReturn: true,
                            onSubmit: {
                                if (!state.userInput.isEmpty || !state.tempMediaItems.isEmpty) && !state.isLoading {
                                    sendIntelligentMessage()
                                }
                            }
                        )
                    }
                }
                .font(.jost(.callout(14)))
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 34)


                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(isTextEditorFocused ? 0.1 : 0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isTextEditorFocused && isProUser
                                    ? LinearGradient.premiumGradient
                                    : LinearGradient(
                                        gradient: Gradient(colors: [Color.gray.opacity(0.3)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isTextEditorFocused ? 2 : 1
                            )
                    )
                    .cornerRadius(8)
                    .shadow(
                        color: isTextEditorFocused && isProUser
                            ? Color.matchaGreen.opacity(0.3)
                            : Color.clear,
                        radius: isTextEditorFocused && isProUser ? 6 : 0,
                        x: 0,
                        y: 0
                    )
                    .shadow(
                        color: isTextEditorFocused && isProUser
                            ? Color.premiumBlue.opacity(0.25)
                            : Color.clear,
                        radius: isTextEditorFocused && isProUser ? 8 : 0,
                        x: 0,
                        y: 0
                    )
                    .padding(1)
                    .animation(.easeInOut(duration: 0.3), value: isTextEditorFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if (!state.userInput.isEmpty || !state.tempMediaItems.isEmpty) && !state.isLoading {
                            sendIntelligentMessage()
                        }
                    }
                    .onDrop(of: ["public.image", "public.file-url", "public.data", "public.png", "public.jpeg"], isTargeted: $isInputTargeted) {
                        providers, _ in
                        for provider in providers {
                            // Try to load as URL first (for file drops)
                            if provider.canLoadObject(ofClass: URL.self) {
                                _ = provider.loadObject(ofClass: URL.self) { url, error in
                                    guard let url = url else { return }
                                    DispatchQueue.main.async {
                                        handleDroppedMedia(from: url)
                                    }
                                }
                                return true
                            }
                            
                            #if canImport(UIKit)
                            // Try to load as UIImage (for lasso tool selections)
                            if provider.canLoadObject(ofClass: UIImage.self) {
                                _ = provider.loadObject(ofClass: UIImage.self) { image, error in
                                    guard let image = image as? UIImage else { return }
                                    DispatchQueue.main.async {
                                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                                            let mediaItem = MediaItem(data: imageData, type: .image)
                                            state.tempMediaItems.append(mediaItem)
                                        }
                                    }
                                }
                                return true
                            }
                            #endif
                        }
                        return false
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isInputTargeted ? Color.blue : Color.clear, lineWidth: 2)
                    )
                
                HStack(spacing: 8) {
                    // Model selection dropdown
                    Menu {
                        ForEach(state.availableModels, id: \.self) { model in
                            Button(action: { state.selectedModel = model }) {
                                ModelNameLabel(name: model)
                                    .font(.jost(.caption()))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            ModelNameLabel(name: state.selectedModel)
                                .font(.jost(.caption()))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }
                    // Send button
                    Button(action: {
                        sendIntelligentMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(
                                (state.userInput.isEmpty && state.tempMediaItems.isEmpty) || state.isLoading
                                ? .gray : .matchadark_light
                            )
                            .font(.jost(.title2()))
                    }
                    .disabled((state.userInput.isEmpty && state.tempMediaItems.isEmpty) || state.isLoading)
                }
                .padding(.bottom, 8)
                .padding(.trailing, 8)
                .padding(.top,2)
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, inputOuterPadding)
        }
        .background(
            (colorScheme == .dark
             ? Color.matchabackground_dark
             : Color.matchabackground_light)
            .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
        .offset(y: state.messages.isEmpty ? 0 : -max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
        .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
    }
    
    // MARK: - Error Handling Methods

    private func getUserFriendlyErrorMessage(_ error: String) -> String {
        let lowercasedError = error.lowercased()

        // Network-related errors
        if lowercasedError.contains("network") || lowercasedError.contains("connection") ||
           lowercasedError.contains("internet") || lowercasedError.contains("offline") {
            return "Unable to connect to the internet. Please check your connection and try again."
        }

        // Timeout errors
        if lowercasedError.contains("timeout") || lowercasedError.contains("timed out") {
            return "The request took too long. Please try again."
        }

        // API key or authentication errors
        if lowercasedError.contains("api key") || lowercasedError.contains("unauthorized") ||
           lowercasedError.contains("authentication") || lowercasedError.contains("401") {
            return "Authentication failed. Please check your API settings."
        }

        // Rate limit errors
        if lowercasedError.contains("rate limit") || lowercasedError.contains("too many requests") ||
           lowercasedError.contains("429") {
            return "Too many requests. Please wait a moment and try again."
        }

        // Server errors
        if lowercasedError.contains("500") || lowercasedError.contains("502") ||
           lowercasedError.contains("503") || lowercasedError.contains("504") ||
           lowercasedError.contains("server error") {
            return "The server is experiencing issues. Please try again in a few moments."
        }

        // Model unavailable
        if lowercasedError.contains("model") && (lowercasedError.contains("not found") ||
           lowercasedError.contains("unavailable")) {
            return "The selected AI model is currently unavailable. Try selecting a different model."
        }

        // Insufficient requests
        if lowercasedError.contains("insufficient") && lowercasedError.contains("requests") {
            return "You've reached your request limit. Please upgrade or wait for your limit to reset."
        }

        // Default message for unknown errors
        return "We couldn't process your request. Please try again."
    }

    private func retryLastMessage() {
        // Cancel any existing task first
        state.currentMessageTask?.cancel()
        
        // Find the last user message
        guard let lastUserMessage = state.messages.last(where: { $0.isUser }) else {
            return
        }

        // Remove the last user message and any incomplete assistant messages after it
        if let lastUserIndex = state.messages.lastIndex(where: { $0.id == lastUserMessage.id }) {
            // Remove all messages from the last user message onwards
            state.messages.removeSubrange(lastUserIndex...)
        }

        // Clear error and loading states
        state.errorMessage = nil
        state.isLoading = false

        // Restore the user input and media items
        state.userInput = lastUserMessage.content
        if let mediaItems = lastUserMessage.mediaItems {
            state.tempMediaItems = mediaItems
        }

        // Resend the message
        sendIntelligentMessage()
    }

    // MARK: - AI Intelligence Methods

    private func setInitialModel() {
        // Set the first available model immediately to avoid delay
        let preferencesManager = PreferencesManager.shared
        let orderedEnabled = preferencesManager.getOrderedEnabledModels()
        
        if !orderedEnabled.isEmpty {
            state.selectedModel = orderedEnabled.first!
        } else {
            // Fallback to first free model if no preferences set
            let freeModels = ModelConfiguration.getFreeModelNames()
            if !freeModels.isEmpty {
                state.selectedModel = freeModels.first!
            }
        }
    }
    
    private func refreshAvailableModels() {
        let preferencesManager = PreferencesManager.shared
        let orderedEnabled = preferencesManager.getOrderedEnabledModels()

        // Use getEffectiveProfile() which has caching/fallback logic, instead of
        // directly accessing userProfile which may be temporarily nil during refresh
        if let profile = state.subscriptionManager.getEffectiveProfile() {
            let availableForTier = ModelConfiguration.getAvailableModelNames(for: profile.subscriptionTier)
            // Filter to only enabled models that are available for the user's tier, maintaining order
            state.availableModels = orderedEnabled.filter { availableForTier.contains($0) }
        } else {
            let freeModels = ModelConfiguration.getFreeModelNames()
            // Filter to only enabled free models, maintaining order
            state.availableModels = orderedEnabled.filter { freeModels.contains($0) }
        }
        
        // Set selectedModel to the first available model only if current selection is not available
        if !state.availableModels.isEmpty && !state.availableModels.contains(state.selectedModel) {
            // Only override if the current selection is empty or invalid
            if state.selectedModel.isEmpty {
                state.selectedModel = state.availableModels.first!
            }
        }
    }
    
    private func setupAI() {
        // All API calls now go through secure backend via SecureLlmAPI
        // No client-side API key configuration needed
        
        Task {
            await state.subscriptionManager.fetchUserProfile()
            await MainActor.run {
                refreshAvailableModels()

                // Ensure free users are in chat mode after profile fetch
                let userTier = state.subscriptionManager.getEffectiveProfile()?.subscriptionTier ?? .free
                if userTier == .free && state.currentMode == .study {
                    state.currentMode = .chat
                }
            }
        }
    }
    
    func setCurrentNote(_ note: Note) {
        state.currentNote = note
    }
    
    private func saveCurrentNote() {
        guard let note = state.currentNote else { 
            return 
        }
        
        // Save canvas data first (same pattern as export feature)
        if let saveCanvasCallback = state.saveCanvasDataCallback {
            saveCanvasCallback()
        }
        
        // Get the latest version of the note from storage after canvas data is saved
        if let latestNote = storageManager.notes.first(where: { $0.id == note.id }) {
            state.currentNote = latestNote
        }
    }
    
    // Public function for saving notes (useful for exporting)
    func saveNote() -> Note? {
        guard let note = state.currentNote else { return nil }
        
        // Save canvas data first (same pattern as export feature)
        if let saveCanvasCallback = state.saveCanvasDataCallback {
            saveCanvasCallback()
        }
        
        // Get the latest version of the note from storage after canvas data is saved
        guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
            return nil
        }
        
        state.currentNote = latestNote
        return latestNote
    }
    
    private func sendIntelligentMessage() {
        // Cancel any existing message task to prevent race conditions
        state.currentMessageTask?.cancel()
        
        // Store input and media items first to avoid race conditions
        let input = state.userInput
        let mediaItems = state.tempMediaItems
        let selectedModel = state.selectedModel

        // Extract mentions from the input
        let mentions = state.mentionManager?.extractMentions(from: input) ?? []

        // Check if we have anything to send
        guard !input.isEmpty || !mediaItems.isEmpty else {
            print("❌ Send button pressed but no input or media items")
            return
        }

        // Clear input immediately to prevent double-sending
        state.userInput = ""
        state.tempMediaItems = []
        selectedMediaItemId = nil
        state.isLoading = true
        state.errorMessage = nil

        // Trigger scroll immediately when user submits
        shouldScrollToUserMessage = true
        userScrollTrigger &+= 1

        guard let note = state.currentNote else {
            sendRegularMessage(input: input, mediaItems: mediaItems, selectedModel: selectedModel, mentions: mentions)
            return
        }

        // Log which note context is being used for this query
        print("💬 Chat: Using note context '\(note.title)' (ID: \(note.id))")

        // Save the note before analysis to ensure AI has access to latest content
        saveCurrentNote()

        // Check if user can make this request type
        let isPremium = ModelConfiguration.isPremiumModel(selectedModel)
        let requestType: RequestType = isPremium ? .premium : .normal
        guard state.subscriptionManager.canMakeRequest(type: requestType) else {
            state.errorMessage = "Insufficient \(requestType == .premium ? "premium" : "free") requests remaining"
            state.isLoading = false
            return
        }

        // Add user message to chat
        let userMessage = ChatMessage(
            content: input,
            isUser: true,
            mediaItems: mediaItems.isEmpty ? nil : mediaItems
        )
        state.messages.append(userMessage)

        // Create and track the new task
        state.currentMessageTask = Task {
            // Ensure isLoading is reset even if Task is cancelled
            defer {
                Task { @MainActor in
                    state.isLoading = false
                    state.currentMessageTask = nil
                }
            }

            do {
                // Check if task was cancelled before starting
                try Task.checkCancellation()

                // Consume request first
                let success = await state.subscriptionManager.consumeRequest(
                    type: requestType, model: selectedModel)
                guard success else {
                    await MainActor.run {
                        state.errorMessage = "Failed to consume request"
                        state.isLoading = false
                    }
                    return
                }

                // Use AssistantMessageHandler for intelligent message routing and context building
                let (stream, _, autoFillResult) = try await AssistantMessageHandler.shared.streamIntelligentMessage(
                    input: input,
                    note: note,
                    storageManager: storageManager,
                    mediaItems: mediaItems,
                    mentions: mentions,
                    mentionManager: state.mentionManager,
                    selectedModel: selectedModel,
                    conversationHistory: state.messages,
                    existingTextBoxesByPage: note.textBoxDataByPage.reduce(into: [:]) { result, pair in
                        if let pageIndex = Int(pair.key) {
                            result[pageIndex] = pair.value.compactMap { try? JSONDecoder().decode(TextBox.self, from: $0) }
                        }
                    },
                    subscriptionManager: state.subscriptionManager
                )

                // Handle auto-fill result by calling the callback
                if let autoFillResult = autoFillResult {
                    print("📝 Auto-fill generated \(autoFillResult.textboxes.count) textboxes")
                    print("📍 Textbox positions: \(autoFillResult.textboxes.map { "(\($0.position.x), \($0.position.y)) on page \($0.pageIndex)" })")

                    // Call the auto-fill callback to insert textboxes
                    await MainActor.run {
                        state.autoFillCallback?(autoFillResult)
                    }
                }

                await MainActor.run {
                    state.messages.append(
                        ChatMessage(
                            content: "",
                            isUser: false,
                            model: selectedModel,
                            isComplete: false
                        )
                    )
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check for cancellation during streaming
                    try Task.checkCancellation()
                    
                    fullResponse += chunk
                    let currentResponse = fullResponse // Capture for closure
                    await MainActor.run {
                        if !state.messages.isEmpty {
                            let lastIndex = state.messages.count - 1
                            // Create a new copy with updated content
                            var lastMessage = state.messages[lastIndex]
                            lastMessage.content = currentResponse
                            state.messages[lastIndex] = lastMessage
                        }
                    }
                }

                await MainActor.run {
                    if !state.messages.isEmpty {
                        let lastIndex = state.messages.count - 1
                        var lastMessage = state.messages[lastIndex]
                        lastMessage.isComplete = true
                        state.messages[lastIndex] = lastMessage
                    }
                    
                    state.isLoading = false

                    // Save conversation after receiving response
                    state.saveCurrentConversation()
                }

            } catch is CancellationError {
                // Task was cancelled - keep partial message and mark as complete
                await MainActor.run {
                    // Mark incomplete assistant message as complete if it exists
                    if !state.messages.isEmpty, let lastMessage = state.messages.last, !lastMessage.isUser, !lastMessage.isComplete {
                        let lastIndex = state.messages.count - 1
                        var completedMessage = state.messages[lastIndex]
                        completedMessage.isComplete = true
                        state.messages[lastIndex] = completedMessage
                    }
                    // Don't show error for cancellation
                    state.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Remove incomplete assistant message if it exists
                    if !state.messages.isEmpty, let lastMessage = state.messages.last, !lastMessage.isUser {
                        state.messages.removeLast()
                    }

                    state.errorMessage = "Error: \(error.localizedDescription)"
                    state.isLoading = false
                }
            }
        }
    }
    
    private func sendRegularMessage(input: String, mediaItems: [MediaItem], selectedModel: String, mentions: [Mention] = []) {
        // Fallback to regular chat without note context
        guard !input.isEmpty else { return }

        let isPremium = ModelConfiguration.isPremiumModel(selectedModel)
        let requestType: RequestType = isPremium ? .premium : .normal
        guard state.subscriptionManager.canMakeRequest(type: requestType) else {
            state.errorMessage = "Insufficient \(requestType == .premium ? "premium" : "free") requests remaining"
            state.isLoading = false
            return
        }

        let userMessage = ChatMessage(
            content: input,
            isUser: true,
            mediaItems: mediaItems.isEmpty ? nil : mediaItems
        )
        state.messages.append(userMessage)

        // Create and track the new task
        state.currentMessageTask = Task {
            // Ensure isLoading is reset even if Task is cancelled
            defer {
                Task { @MainActor in
                    state.isLoading = false
                    state.currentMessageTask = nil
                }
            }
            
            do {
                // Check if task was cancelled before starting
                try Task.checkCancellation()
                
                let success = await state.subscriptionManager.consumeRequest(
                    type: requestType, model: selectedModel)
                guard success else {
                    await MainActor.run {
                        state.errorMessage = "Failed to consume request"
                        state.isLoading = false
                    }
                    return
                }

                // Add context from mentioned items
                var contextualInput = input
                if !mentions.isEmpty, let mentionManager = state.mentionManager {
                    let mentionContext = mentionManager.getContextForMentions(mentions)
                    if !mentionContext.isEmpty {
                        contextualInput += "\n\n--- Referenced Items ---\(mentionContext)"
                    }
                }

                let stream = SecureLlmAPI.streamMessageCompat(
                    userMessage: contextualInput,
                    model_string: selectedModel,
                    mediaItems: mediaItems.isEmpty ? nil : mediaItems,
                    conversationHistory: state.messages
                )
                
                await MainActor.run {
                    state.messages.append(
                        ChatMessage(
                            content: "",
                            isUser: false,
                            model: selectedModel
                        )
                    )
                }
                
                var fullResponse = ""
                for try await chunk in stream {
                    // Check for cancellation during streaming
                    try Task.checkCancellation()
                    
                    fullResponse += chunk
                    let currentResponse = fullResponse // Capture for closure
                    await MainActor.run {
                        if !state.messages.isEmpty {
                            let lastIndex = state.messages.count - 1
                            var lastMessage = state.messages[lastIndex]
                            lastMessage.content = currentResponse
                            state.messages[lastIndex] = lastMessage
                        }
                    }
                }
                
                await MainActor.run {
                    state.isLoading = false

                    // Save conversation after receiving response
                    state.saveCurrentConversation()
                }
            } catch is CancellationError {
                // Task was cancelled - keep partial message and mark as complete
                await MainActor.run {
                    // Mark incomplete assistant message as complete if it exists
                    if !state.messages.isEmpty, let lastMessage = state.messages.last, !lastMessage.isUser, !lastMessage.isComplete {
                        let lastIndex = state.messages.count - 1
                        var completedMessage = state.messages[lastIndex]
                        completedMessage.isComplete = true
                        state.messages[lastIndex] = completedMessage
                    }
                    // Don't show error for cancellation
                    state.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Remove incomplete assistant message if it exists
                    if !state.messages.isEmpty, let lastMessage = state.messages.last, !lastMessage.isUser {
                        state.messages.removeLast()
                    }

                    state.errorMessage = "Error: \(error.localizedDescription)"
                    state.isLoading = false
                }
            }
        }
    }

    private func handleDroppedMedia(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let mediaType: MediaItem.MediaType
            
            if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
                || url.pathExtension.lowercased() == "png" {
                mediaType = .image
            } else {
                mediaType = .file(url.lastPathComponent)
            }
            
            let mediaItem = MediaItem(data: data, type: mediaType)
            state.tempMediaItems.append(mediaItem)
        } catch {
            print("Error handling dropped media: \(error)")
        }
    }
    
    private func removeMediaItem(_ item: MediaItem) {
        if let index = state.tempMediaItems.firstIndex(where: { $0.id == item.id }) {
            state.tempMediaItems.remove(at: index)
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
#if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.keyboardHeight = 0
        }
#endif
    }
    
    private func removeKeyboardObservers() {
#if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
#endif
    }
}
