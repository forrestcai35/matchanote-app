import SwiftUI
import PencilKit

#if canImport(UIKit)
  import UIKit
  import PhotosUI
#elseif canImport(AppKit)
  import AppKit
#endif

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

    // AI capabilities
    @Published var aiManager = AIAssistantManager()
    @Published var currentNote: Note?
    
    // Callback for saving canvas data before AI analysis
    var saveCanvasDataCallback: (() -> Void)?
    
    // Performance optimization
    private var userInputDebounceTimer: Timer?
    
    deinit {
        userInputDebounceTimer?.invalidate()
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
    @State private var keyboardHeight: CGFloat = 0
    private let inputOuterPadding: CGFloat = 16
    @State private var userScrollTrigger: Int = 0
    @State private var shouldScrollToUserMessage = false
    
    var body: some View {
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
                    .padding(.top, 12) // Add some top padding when at bottom
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
                
                // Show AI analysis progress when running
                if state.aiManager.isAnalyzing {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Analyzing your note...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        Text(state.aiManager.currentAnalysisStep)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
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
        VStack(spacing: 8) {
            // + icon and media items above text input
            HStack {
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
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Media items display (smaller and inline)
                if !state.tempMediaItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.tempMediaItems) { item in
                                ZStack(alignment: .topTrailing) {
                                    if case .image = item.type {
#if canImport(UIKit)
                                        if let uiImage = UIImage(data: item.data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .cornerRadius(4)
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
                                        .frame(height: 32)
                                    }
                                    
                                    Button(action: {
                                        removeMediaItem(item)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white.opacity(0.8))
                                            .clipShape(Circle())
                                            .font(.caption2)
                                    }
                                    .offset(x: 2, y: -2)
                                }
                                .frame(width: 40, height: 40) // Ensure enough space for the X button
                            }
                        }
                        .padding(.horizontal, 8) // Increased padding to prevent clipping
                        .padding(.vertical, 4) // Add vertical padding for the X button
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            ZStack(alignment: .bottomTrailing) {
                GrowingTextEditor(
                    text: $state.userInput,
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .padding(1)
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

        
        // Configure with available keys (allow partial configuration)
        LlmAPI.configure(
            openRouterAPIKey: openRouterKey,
            openAIAPIKey: openAIKey,
            anthropicAPIKey: anthropicKey,
            deepSeekAPIKey: deepSeekKey,
            googleAPIKey: googleKey,
            xAPIKey: xKey,
            mistralAPIKey: mistralKey
        )
        
        Task {
            await state.subscriptionManager.fetchUserProfile()
            await MainActor.run {
                refreshAvailableModels()
            }
        }
    }
    
    func setCurrentNote(_ note: Note) {
        state.currentNote = note
    }
    
    private func saveCurrentNote() {
        guard let note = state.currentNote else { 
            print("❌ No current note to save")
            return 
        }
        
        print("💾 Saving note: \(note.title)")
        
        // Get the latest version of the note from storage to ensure we have the most recent data
        if let latestNote = storageManager.notes.first(where: { $0.id == note.id }) {
            // Update the current note reference with the latest version
            state.currentNote = latestNote
            print("🔄 Updated note reference with latest data")
        }
        
        // Force save the current note to ensure all changes are persisted
        let savedNote = storageManager.saveNote(note)
        
        // Update the current note reference with the saved version
        state.currentNote = savedNote
        
        print("✅ Note saved successfully")
    }
    
    // Public function for saving notes (useful for exporting)
    func saveNote() -> Note? {
        guard var note = state.currentNote else { return nil }
        
        // Update the modified date
        note.dateModified = Date()
        
        // Save the note through StorageManager
        let savedNote = storageManager.saveNote(note)
        
        // Update the current note reference
        state.currentNote = savedNote
        
        return savedNote
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
                    // Convert note to images for visual analysis
                    let noteImages = await convertNoteToImages(note)
                    finalMediaItems.append(contentsOf: noteImages)
                    
                    // Create rich context prompt
                    contextualPrompt = """
                    User question: \(input)
                    
                    I've provided images of the note for visual analysis. Please examine the note content (both typed text and handwritten content) and answer the user's question based on what you can see in the note.
                    
                    Note details:
                    Title: \(note.title)
                    Subject: \(note.subject)
                    """
                }
                
                // Send to AI with context and images
                let response = try await LlmAPI.sendMessage(
                    userMessage: contextualPrompt,
                    model_string: selectedModel,
                    mediaItems: finalMediaItems.isEmpty ? nil : finalMediaItems
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
                    mediaItems: mediaItems.isEmpty ? nil : mediaItems
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
