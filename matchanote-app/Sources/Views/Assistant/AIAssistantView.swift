import SwiftUI
import PencilKit

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
  let content: String
  let isUser: Bool
  let model: String
  var mediaItems: [MediaItem]? = nil

  init(content: String, isUser: Bool, model: String = "", mediaItems: [MediaItem]? = nil) {
    self.content = content
    self.isUser = isUser
    self.model = model
    self.mediaItems = mediaItems
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
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels: [String] = []
    @Published var subscriptionManager = SubscriptionManager()
    @Published var chatStorage = ChatStorageManager.shared
    @Published var showingChatHistory = false

    // AI capabilities

    @Published var currentNote: Note?

    // Study Mode properties
    @Published var currentMode: AssistantMode = .chat
    @Published var studySubMode: StudySubMode = .quiz
    @Published var studySession: StudySession?
    @Published var isAnalyzingContent = false
    @Published var canEnableStudyMode = false
    @Published var studyModeMessage: String?
    @Published var studyStorage = StudyStorageManager.shared

    // Callback for saving canvas data before AI analysis
    var saveCanvasDataCallback: (() -> Void)?

    // Performance optimization
    private var userInputDebounceTimer: Timer?

    deinit {
        userInputDebounceTimer?.invalidate()
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

        // Convert note pages to images for visual analysis
        var noteImages: [MediaItem] = []
        let pageKeys = Array(latestNote.drawingDataByPage.keys).sorted { key1, key2 in
            guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
            return page1 < page2
        }

        for pageKey in pageKeys {
            guard let pageIndex = Int(pageKey),
                  let drawingData = latestNote.drawingDataByPage[pageKey],
                  let drawing = try? PKDrawing(data: drawingData) else { continue }

            let paperSize = PaperUtilities.paperSize(for: latestNote.paperSize)
            let backgroundImages = latestNote.imageDataByPage[pageKey] ?? []
            let overlayImages = PaperUtilities.extractCanvasImages(from: latestNote.imageDataByPage, for: pageIndex)

            let previewImage = PaperUtilities.generatePreviewWithBackground(
                drawing: drawing,
                paperSize: paperSize,
                paperColor: latestNote.paperColor,
                paperStyle: latestNote.paperStyle,
                scale: 0.5,
                backgroundImages: backgroundImages,
                overlayImages: overlayImages
            )

            if let imageData = previewImage.jpegData(compressionQuality: 0.8) {
                noteImages.append(MediaItem(data: imageData, type: .image))
            }
        }

        // Use LLM with contentAnalysis prompt to analyze if content is educational
        do {
            let response = try await LlmAPI.sendMessage(
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
    func generateQuizQuestions(note: Note, storageManager: StorageManager, count: Int = 10) async throws {
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

        // Convert note pages to images for visual analysis
        var noteImages: [MediaItem] = []
        let pageKeys = Array(latestNote.drawingDataByPage.keys).sorted { key1, key2 in
            guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
            return page1 < page2
        }

        for pageKey in pageKeys {
            guard let pageIndex = Int(pageKey),
                  let drawingData = latestNote.drawingDataByPage[pageKey],
                  let drawing = try? PKDrawing(data: drawingData) else { continue }

            let paperSize = PaperUtilities.paperSize(for: latestNote.paperSize)
            let backgroundImages = latestNote.imageDataByPage[pageKey] ?? []
            let overlayImages = PaperUtilities.extractCanvasImages(from: latestNote.imageDataByPage, for: pageIndex)

            let previewImage = PaperUtilities.generatePreviewWithBackground(
                drawing: drawing,
                paperSize: paperSize,
                paperColor: latestNote.paperColor,
                paperStyle: latestNote.paperStyle,
                scale: 0.5,
                backgroundImages: backgroundImages,
                overlayImages: overlayImages
            )

            if let imageData = previewImage.jpegData(compressionQuality: 0.8) {
                noteImages.append(MediaItem(data: imageData, type: .image))
            }
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await LlmAPI.sendMessage(
                userMessage: contentString.isEmpty
                    ? "Generate \(count) quiz questions from the provided note images."
                    : "Generate \(count) quiz questions from this content and images:\n\n\(contentString)",
                model_string: selectedModel.isEmpty ? "Matcha Assistant" : selectedModel,
                mediaItems: noteImages.isEmpty ? nil : noteImages,
                conversationHistory: nil,
                systemPrompt: .quizGeneration
            )

            // Extract JSON from response (handle markdown code blocks)
            let jsonString = extractJSON(from: response)
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
                        session.addQuizQuestions(questions)
                        studySession = session
                        studyStorage.saveSession(session)
                    }
                    isLoading = false
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
                errorMessage = "Failed to generate quiz: \(error.localizedDescription)"
                isLoading = false
            }
            throw error
        }
    }

    /// Generate flashcards for current note
    func generateFlashcards(note: Note, storageManager: StorageManager, count: Int = 15) async throws {
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

        // Convert note pages to images for visual analysis
        var noteImages: [MediaItem] = []
        let pageKeys = Array(latestNote.drawingDataByPage.keys).sorted { key1, key2 in
            guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
            return page1 < page2
        }

        for pageKey in pageKeys {
            guard let pageIndex = Int(pageKey),
                  let drawingData = latestNote.drawingDataByPage[pageKey],
                  let drawing = try? PKDrawing(data: drawingData) else { continue }

            let paperSize = PaperUtilities.paperSize(for: latestNote.paperSize)
            let backgroundImages = latestNote.imageDataByPage[pageKey] ?? []
            let overlayImages = PaperUtilities.extractCanvasImages(from: latestNote.imageDataByPage, for: pageIndex)

            let previewImage = PaperUtilities.generatePreviewWithBackground(
                drawing: drawing,
                paperSize: paperSize,
                paperColor: latestNote.paperColor,
                paperStyle: latestNote.paperStyle,
                scale: 0.5,
                backgroundImages: backgroundImages,
                overlayImages: overlayImages
            )

            if let imageData = previewImage.jpegData(compressionQuality: 0.8) {
                noteImages.append(MediaItem(data: imageData, type: .image))
            }
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await LlmAPI.sendMessage(
                userMessage: contentString.isEmpty
                    ? "Generate \(count) flashcards from the provided note images."
                    : "Generate \(count) flashcards from this content and images:\n\n\(contentString)",
                model_string: selectedModel.isEmpty ? "Matcha Assistant" : selectedModel,
                mediaItems: noteImages.isEmpty ? nil : noteImages,
                conversationHistory: nil,
                systemPrompt: .flashcardGeneration
            )

            // Extract JSON from response (handle markdown code blocks)
            let jsonString = extractJSON(from: response)
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
                        session.addFlashcards(flashcards)
                        studySession = session
                        studyStorage.saveSession(session)
                    }
                    isLoading = false
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
                errorMessage = "Failed to generate flashcards: \(error.localizedDescription)"
                isLoading = false
            }
            throw error
        }
    }

    /// Helper function to extract JSON from LLM response (handles markdown code blocks)
    private func extractJSON(from response: String) -> String {
        print("📝 Extracting JSON from response (length: \(response.count))")

        // Method 1: Split by triple backticks
        let components = response.components(separatedBy: "```")
        if components.count >= 3 {
            // Get the content between first and second ```
            var jsonContent = components[1]

            // Remove "json" language identifier if present
            if jsonContent.hasPrefix("json") {
                jsonContent = String(jsonContent.dropFirst(4))
            }

            let trimmed = jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidJSONStart(trimmed) {
                print("✅ Extracted from markdown code block (length: \(trimmed.count))")
                return trimmed
            }
        }

        // Method 2: Find JSON object by braces (look for proper JSON structure)
        if let extracted = extractJSONByBraces(from: response) {
            print("✅ Extracted by brace matching (length: \(extracted.count))")
            return extracted
        }

        // Method 3: Find JSON array (look for proper array structure)
        if let extracted = extractJSONArray(from: response) {
            print("✅ Extracted by bracket matching (length: \(extracted.count))")
            return extracted
        }

        print("⚠️ No extraction worked, returning trimmed original")
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string starts with valid JSON structure
    private func isValidJSONStart(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }
    
    /// Extract JSON object by finding matching braces
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
    
    /// Extract JSON array by finding matching brackets (with validation)
    private func extractJSONArray(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "[") else { return nil }
        
        // Check if this looks like a real JSON array (next few chars should be {, ", or whitespace)
        let checkIndex = text.index(after: startIndex)
        if checkIndex < text.endIndex {
            let nextChar = text[checkIndex]
            // If next character is a letter (like 'X' in [X]), it's probably not JSON
            if nextChar.isLetter {
                // Look for another [ that might be the actual JSON array
                let remainingText = String(text[text.index(after: startIndex)...])
                if let recursiveResult = extractJSONArray(from: remainingText) {
                    return recursiveResult
                }
                return nil
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
    private let inputOuterPadding: CGFloat = 16
    @State private var userScrollTrigger: Int = 0
    @State private var shouldScrollToUserMessage = false
    
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
            let userTier = state.subscriptionManager.userProfile?.subscriptionTier ?? .free
            let canSwitchModes = userTier == .pro || userTier == .student
            
            if canSwitchModes {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                    state.currentMode = state.currentMode == .chat ? .study : .chat
                }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: state.currentMode == .study ? "brain.head.profile" : "bubble.left.and.bubble.right")
                    .font(.caption)
                Text(state.currentMode == .study ? "Study" : "Chat")
                    .font(.caption)
                    .fontWeight(.medium)
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

    // MARK: - Chat Mode Content
    private var chatModeContent: some View {
        VStack(spacing: 0) {
            if state.messages.isEmpty {
                inputSection
                    .padding(.top, inputOuterPadding)
                chatHistorySection
                    .padding(.bottom, max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
            } else {
                chatHistorySection
                    .padding(.bottom, max(0, keyboardHeight.isFinite ? keyboardHeight : 0))
                inputSection
                    .padding(.top, 12)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle button - position based on assistant orientation
            HStack {
                if assistantOrientation == .right {
                    Spacer()
                }
                modeToggleButton
                if assistantOrientation == .left {
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

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
        .onAppear {
            setupAI()
            setupKeyboardObservers()
            // Set initial model immediately to avoid delay
            setInitialModel()
            refreshAvailableModels()
            
            // Ensure free users are always in chat mode
            let userTier = state.subscriptionManager.userProfile?.subscriptionTier ?? .free
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
                
               
                if state.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let error = state.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        Text(error)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                    // Bottom anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("CHAT_BOTTOM")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                (colorScheme == .dark
                 ? Color.matchabackground_dark
                 : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
            )
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
        VStack(spacing: 4) {
            // Icons and media items above text input
            HStack(alignment: .center, spacing: 8) {
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
                        .font(.caption)
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .frame(width: 32, height: 32)
                }
                
                // Media items display (smaller and inline)
                if !state.tempMediaItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(state.tempMediaItems) { item in
                                ZStack(alignment: .topTrailing) {
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
                                                .font(.caption2)
                                            Text(name)
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                        .padding(4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                        .frame(height: 28)
                                    }
                                    
                                    Button(action: {
                                        removeMediaItem(item)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white.opacity(0.8))
                                            .clipShape(Circle())
                                            .font(.system(size: 14))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                                .frame(width: 32, height: 32)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 32)
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    // New chat button with larger tap area (only show if messages exist)
                    if !state.messages.isEmpty {
                        Button(action: {
                            state.startNewConversation()
                        }) {
                            Image(systemName: "plus.message")
                                .font(.system(size: 14))
                                .foregroundColor(
                                   .gray
                                )
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Chat history dropdown button with larger tap area
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
                            .foregroundColor(
                               .gray
                            )
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            ZStack(alignment: .bottomTrailing) {
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
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.trailing, 40)
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
                    .onTapGesture {
                        if !state.userInput.isEmpty {
                            state.userInput = ""
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
                                    .font(.caption)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            ModelNameLabel(name: state.selectedModel)
                                .font(.caption)
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
                            .font(.title2)
                    }
                    .disabled((state.userInput.isEmpty && state.tempMediaItems.isEmpty) || state.isLoading)
                }
                .padding(8)
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
        
        if let profile = state.subscriptionManager.userProfile {
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
        // Debug: Check which API keys are available
        let openRouterKey = EnvironmentManager.shared.get("OPENROUTER_API_KEY")
        let openAIKey = EnvironmentManager.shared.get("OPENAI_API_KEY")
        let anthropicKey = EnvironmentManager.shared.get("CLAUDE_API_KEY")
        let deepSeekKey = EnvironmentManager.shared.get("DEEPSEEK_API_KEY")
        let googleKey = EnvironmentManager.shared.get("GEMINI_API_KEY")
        let xKey = EnvironmentManager.shared.get("X_API_KEY")
        let mistralKey = EnvironmentManager.shared.get("MISTRAL_API_KEY")
        let perplexityKey = EnvironmentManager.shared.get("PERPLEXITY_API_KEY")

        
        // Configure with available keys (allow partial configuration)
        LlmAPI.configure(
            openRouterAPIKey: openRouterKey,
            openAIAPIKey: openAIKey,
            anthropicAPIKey: anthropicKey,
            deepSeekAPIKey: deepSeekKey,
            googleAPIKey: googleKey,
            xAPIKey: xKey,
            mistralAPIKey: mistralKey,
            perplexityAPIKey: perplexityKey
        )
        
        Task {
            await state.subscriptionManager.fetchUserProfile()
            await MainActor.run {
                refreshAvailableModels()
                
                // Ensure free users are in chat mode after profile fetch
                let userTier = state.subscriptionManager.userProfile?.subscriptionTier ?? .free
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
        // Store input and media items first to avoid race conditions
        let input = state.userInput
        let mediaItems = state.tempMediaItems
        let selectedModel = state.selectedModel
        
        // Check if we have anything to send
        guard !input.isEmpty || !mediaItems.isEmpty else { 
            print("❌ Send button pressed but no input or media items")
            return 
        }
        
        // Clear input immediately to prevent double-sending
        state.userInput = ""
        state.tempMediaItems = []
        state.isLoading = true
        state.errorMessage = nil
        
        // Trigger scroll immediately when user submits
        shouldScrollToUserMessage = true
        userScrollTrigger &+= 1
        
        guard let note = state.currentNote else {
            sendRegularMessage(input: input, mediaItems: mediaItems, selectedModel: selectedModel)
            return
        }
        
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
        
        // Determine if we need to analyze the note first
        let needsAnalysis = shouldAnalyzeNote(for: input)
        
        Task {
            do {
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
                
                var contextualPrompt = input
                var finalMediaItems = mediaItems
                
                // If needed, analyze the note first to provide context
                if needsAnalysis {
                    // Get the latest saved note from storage (same pattern as export)
                    guard let latestNote = storageManager.notes.first(where: { $0.id == note.id }) else {
                        await MainActor.run {
                            state.errorMessage = "Could not find latest note data for analysis"
                            state.isLoading = false
                        }
                        return
                    }
                    
                    // Convert the latest saved note to images for visual analysis
                    let noteImages = await convertNoteToImages(latestNote)
                    finalMediaItems.append(contentsOf: noteImages)
                    
                    // Create rich context prompt using the latest note data
                    contextualPrompt = """
                    User question: \(input)
                    
                    I've provided images of the note for visual analysis. Please examine the note content (both typed text and handwritten content) and answer the user's question based on what you can see in the note.
                    
                    Note details:
                    Title: \(latestNote.title)
                    Subject: \(latestNote.subject)
                    """
                }
                
                // Send to AI with context and images
                let response = try await LlmAPI.sendMessage(
                    userMessage: contextualPrompt,
                    model_string: selectedModel,
                    mediaItems: finalMediaItems.isEmpty ? nil : finalMediaItems,
                    conversationHistory: state.messages
                )
                
                await MainActor.run {
                    state.messages.append(
                        ChatMessage(
                            content: response,
                            isUser: false,
                            model: selectedModel
                        )
                    )
                    state.isLoading = false
                    
                    // Save conversation after receiving response
                    state.saveCurrentConversation()
                }
                
            } catch {
                await MainActor.run {
                    state.errorMessage = "Error: \(error.localizedDescription)"
                    state.isLoading = false
                }
            }
        }
    }
    
    private func sendRegularMessage(input: String, mediaItems: [MediaItem], selectedModel: String) {
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
        
        Task {
            do {
                let success = await state.subscriptionManager.consumeRequest(
                    type: requestType, model: selectedModel)
                guard success else {
                    await MainActor.run {
                        state.errorMessage = "Failed to consume request"
                        state.isLoading = false
                    }
                    return
                }
                
                let response = try await LlmAPI.sendMessage(
                    userMessage: input,
                    model_string: selectedModel,
                    mediaItems: mediaItems.isEmpty ? nil : mediaItems,
                    conversationHistory: state.messages
                )
                
                await MainActor.run {
                    state.messages.append(
                        ChatMessage(
                            content: response,
                            isUser: false,
                            model: selectedModel
                        )
                    )
                    state.isLoading = false
                    
                    // Save conversation after receiving response
                    state.saveCurrentConversation()
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = "Error: \(error.localizedDescription)"
                    state.isLoading = false
                }
            }
        }
    }
    
    private func shouldAnalyzeNote(for input: String) -> Bool {
        let lowercaseInput = input.lowercased()
        
        // Direct analysis keywords
        let directAnalysisKeywords = [
            "analyze", "analysis", "gaps", "missing", "incomplete", "handwriting", 
            "handwritten", "extract text", "suggestions", "improve", "connections", 
            "related", "summary", "summarize", "main points", "key concepts", 
            "review", "feedback", "critique"
        ]
        
        // Note-specific possessive patterns
        let notePossessivePatterns = [
            "my note", "this note", "my notes", "these notes", "the note", "the notes"
        ]
        
        // Action verbs that suggest note analysis
        let analysisActionVerbs = [
            "analyze", "summarize", "explain", "describe", "review", "check", 
            "examine", "study", "extract", "find", "search", "look at"
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
    
    private func convertNoteToImages(_ note: Note) async -> [MediaItem] {
        var mediaItems: [MediaItem] = []
        
        // Get all pages from the note
        let pageKeys = Array(note.drawingDataByPage.keys).sorted { key1, key2 in
            guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
            return page1 < page2
        }
        
        for pageKey in pageKeys {
            guard let pageIndex = Int(pageKey) else { continue }
            
            // Get drawing data for this page
            guard let drawingData = note.drawingDataByPage[pageKey],
                  let drawing = try? PKDrawing(data: drawingData) else { continue }
            
            // Get paper size
            let paperSize = PaperUtilities.paperSize(for: note.paperSize)
            
            // Get background images for this page
            let backgroundImages = note.imageDataByPage[pageKey] ?? []
            
            // Get overlay images for this page
            let overlayImages = PaperUtilities.extractCanvasImages(from: note.imageDataByPage, for: pageIndex)
            
            // Generate preview image
            let previewImage = PaperUtilities.generatePreviewWithBackground(
                drawing: drawing,
                paperSize: paperSize,
                paperColor: note.paperColor,
                paperStyle: note.paperStyle,
                scale: 0.5, // Use smaller scale for faster processing
                backgroundImages: backgroundImages,
                overlayImages: overlayImages
            )
            
            // Convert to JPEG data
            if let imageData = previewImage.jpegData(compressionQuality: 0.8) {
                let mediaItem = MediaItem(data: imageData, type: .image)
                mediaItems.append(mediaItem)
            }
        }
        
        return mediaItems
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
