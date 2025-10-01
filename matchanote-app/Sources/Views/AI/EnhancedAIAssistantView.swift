import SwiftUI

// Message View Components (shared with AIAssistantView)
struct UserMessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User message as a text block
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("User")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                if !message.model.isEmpty {
                    HStack {
                        Text(message.model)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark 
                        ? Color.gray.opacity(0.1) 
                        : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                colorScheme == .dark 
                                    ? Color.gray.opacity(0.3) 
                                    : Color.gray.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AssistantMessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Plain text response underneath user message with basic formatting support
            FormattedTextView(text: message.content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                if !message.model.isEmpty {
                    Text(message.model)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Copy button
                Button(action: {
                    copyToClipboard(message.content)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopyConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(showingCopyConfirmation ? "Copied!" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showingCopyConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCopyConfirmation = false
            }
        }
    }
}

struct FormattedTextView: View {
    let text: String
    
    var body: some View {
        let formattedText = parseFormattedText(text)
        
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(formattedText.enumerated()), id: \.offset) { index, segment in
                if segment.isBold && segment.isItalic {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                        .italic()
                } else if segment.isBold {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                } else if segment.isItalic {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .italic()
                } else {
                    Text(segment.text)
                        .font(.system(size: 15))
                }
            }
        }
    }
    
    private func parseFormattedText(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Look for **bold** or *italic* patterns
            if let boldRange = findPattern(text, from: currentIndex, open: "**", close: "**") {
                // Add text before bold
                if boldRange.start > currentIndex {
                    let beforeText = String(text[currentIndex..<boldRange.start])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add bold text
                let boldText = String(text[boldRange.start..<boldRange.end])
                segments.append(TextSegment(text: boldText, isBold: true, isItalic: false))
                currentIndex = boldRange.end
            } else if let italicRange = findPattern(text, from: currentIndex, open: "*", close: "*") {
                // Add text before italic
                if italicRange.start > currentIndex {
                    let beforeText = String(text[currentIndex..<italicRange.start])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add italic text
                let italicText = String(text[italicRange.start..<italicRange.end])
                segments.append(TextSegment(text: italicText, isBold: false, isItalic: true))
                currentIndex = italicRange.end
            } else {
                // No more formatting, add remaining text
                let remainingText = String(text[currentIndex...])
                if !remainingText.isEmpty {
                    segments.append(TextSegment(text: remainingText, isBold: false, isItalic: false))
                }
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text, isBold: false, isItalic: false)] : segments
    }
    
    private func findPattern(_ text: String, from startIndex: String.Index, open: String, close: String) -> (start: String.Index, end: String.Index)? {
        guard let openRange = text.range(of: open, range: startIndex..<text.endIndex) else { return nil }
        let afterOpen = openRange.upperBound
        
        guard let closeRange = text.range(of: close, range: afterOpen..<text.endIndex) else { return nil }
        
        return (start: afterOpen, end: closeRange.lowerBound)
    }
}

struct TextSegment {
    let text: String
    let isBold: Bool
    let isItalic: Bool
}

// Enhanced AI Assistant State that includes our new capabilities
class EnhancedAIAssistantState: ObservableObject {
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
    @Published var selectedModel = "Matcha Assistant"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels = ["Matcha Assistant"]
    @Published var subscriptionManager = SubscriptionManager()

    // Enhanced AI capabilities
    @Published var currentMode: AIMode = .chat
    @Published var aiManager = AIAssistantManager()
    @Published var showingAnalysisResults = false
    @Published var currentNote: Note?
    
    // Performance optimization
    private var userInputDebounceTimer: Timer?

    enum AIMode {
        case chat
        case analysis
        case suggestions
    }
    
    deinit {
        userInputDebounceTimer?.invalidate()
    }
}

struct EnhancedAIAssistantView: View {
    @EnvironmentObject private var state: EnhancedAIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @State private var showingImagePicker = false
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @State private var contextInfo = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var isInputTargeted = false
    @State private var keyboardHeight: CGFloat = 0
    private let inputOuterPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // Mode Selector
            modeSelector
                .padding(.horizontal)
                .padding(.top, 8)

            // Content based on selected mode
            switch state.currentMode {
            case .chat:
                chatInterfaceView
            case .analysis:
                analysisInterfaceView
            case .suggestions:
                suggestionsInterfaceView
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
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .sheet(isPresented: $state.showingAnalysisResults) {
            if let analysis = state.aiManager.lastAnalysis {
                NavigationView {
                    AIAnalysisView(
                        analysis: analysis,
                        onSuggestionAccept: { suggestion in
                            acceptSuggestion(suggestion)
                        },
                        onSuggestionDismiss: { suggestion in
                            state.aiManager.dismissSuggestion(suggestion)
                        }
                    )
                    .navigationTitle("AI Analysis")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                state.showingAnalysisResults = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var modeSelector: some View {
        Picker("AI Mode", selection: $state.currentMode) {
            Text("Chat").tag(EnhancedAIAssistantState.AIMode.chat)
            Text("Analysis").tag(EnhancedAIAssistantState.AIMode.analysis)
            Text("Suggestions").tag(EnhancedAIAssistantState.AIMode.suggestions)
        }
        .pickerStyle(.segmented)
    }

    private var chatInterfaceView: some View {
        VStack(spacing: 0) {
            if state.messages.isEmpty {
                inputSection
                    .padding(.top, inputOuterPadding)
                chatHistorySection
            } else {
                chatHistorySection
                inputSection
            }
        }
    }

    private var analysisInterfaceView: some View {
        VStack(spacing: 16) {
            // Analysis Controls
            VStack(spacing: 12) {
                Text("AI Note Analysis")
                    .font(.headline)
                    .fontWeight(.medium)

                Text("Analyze your note content using AI to find insights, gaps, and improvement suggestions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Analysis Action Buttons
                VStack(spacing: 8) {
                    analyzeButton

                    quickActionsView
                }
            }
            .padding()

            // Analysis Progress
            if state.aiManager.isAnalyzing {
                analysisProgressView
                    .padding()
            }

            // Quick Analysis Results
            if state.aiManager.lastAnalysis != nil, !state.aiManager.isAnalyzing {
                quickAnalysisView
                    .padding()
            }

            Spacer()
        }
    }

    private var suggestionsInterfaceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("AI Suggestions")
                        .font(.headline)
                        .fontWeight(.medium)

                    Spacer()

                    if !state.aiManager.suggestions.isEmpty {
                        Text("\(state.aiManager.suggestions.count) suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Suggestions
                if state.aiManager.suggestions.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "No suggestions available",
                        description: "Run an AI analysis first to get personalized suggestions for your note."
                    )
                } else {
                    ForEach(state.aiManager.suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }, id: \.id) { suggestion in
                        CompactSuggestionCard(
                            suggestion: suggestion,
                            onAccept: { acceptSuggestion(suggestion) },
                            onDismiss: { state.aiManager.dismissSuggestion(suggestion) }
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var analyzeButton: some View {
        Button(action: {
            runFullAnalysis()
        }) {
            HStack {
                Image(systemName: state.aiManager.isAnalyzing ? "brain.head.profile.fill" : "brain.head.profile")
                Text("Analyze Note with AI")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(state.aiManager.isAnalyzing || state.currentNote == nil)
    }

    private var quickActionsView: some View {
        HStack(spacing: 12) {
            Button("Quick Handwriting") {
                runQuickHandwritingAnalysis()
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .foregroundColor(.green)
            .clipShape(Capsule())

            Button("Content Gaps") {
                runContentGapAnalysis()
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .clipShape(Capsule())

            Button("Find Related") {
                findRelatedNotes()
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.1))
            .foregroundColor(.purple)
            .clipShape(Capsule())
        }
    }

    private var analysisProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: state.aiManager.analysisProgress)
                .progressViewStyle(LinearProgressViewStyle())

            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)

                Text(state.aiManager.currentAnalysisStep)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(state.aiManager.analysisProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
        )
    }

    private var quickAnalysisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Analysis")
                    .font(.headline)

                Spacer()

                Button("View Full Results") {
                    state.showingAnalysisResults = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            if let analysis = state.aiManager.lastAnalysis {
                Text(analysis.summary)
                    .font(.body)
                    .lineLimit(3)

                if !analysis.keyInsights.isEmpty {
                    Text("Key Insights:")
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(analysis.keyInsights.prefix(3), id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if analysis.keyInsights.count > 3 {
                    Text("...and \(analysis.keyInsights.count - 3) more insights")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.05) : Color.gray.opacity(0.02))
        )
    }

    // MARK: - Chat Interface (Preserved from original)

    private var chatHistorySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(state.messages) { message in
                    if message.isUser {
                        UserMessageView(message: message)
                    } else {
                        AssistantMessageView(message: message)
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)

            // Input area with model selection on left and send button on right
            HStack(spacing: 8) {
                // Model selection on the left
                Menu {
                    ForEach(state.availableModels, id: \.self) { model in
                        Button(model) {
                            state.selectedModel = model
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(state.selectedModel)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }

                // Text input in the middle
                TextField("Ask about your note...", text: $state.userInput)
                    .font(.system(size: 15))
                    .textFieldStyle(.roundedBorder)

                // Send button on the right
                Button(action: {
                    sendContextualMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(state.userInput.isEmpty ? .gray : .blue)
                        .font(.title2)
                }
                .disabled(state.userInput.isEmpty || state.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, inputOuterPadding)
        }
        .offset(y: state.messages.isEmpty ? 0 : -keyboardHeight)
        .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
    }

    // MARK: - AI Analysis Methods

    private func setupAI() {
        // Configure API
        if let apiKey = EnvironmentManager.shared.getLlmAPIKey(for: "OPENROUTER") {
            OpenRouterAPI.configure(apiKey: apiKey)
        }

        // Load user profile and available models
        Task {
            await state.subscriptionManager.fetchUserProfile()
            await MainActor.run {
                state.availableModels = state.subscriptionManager.getAvailableModels()
                print("🔍 EnhancedAIAssistantView: Loaded models: \(state.availableModels)")
            }
        }
    }

    func setCurrentNote(_ note: Note) {
        state.currentNote = note
    }

    private func runFullAnalysis() {
        guard let note = state.currentNote else { return }

        Task {
            await state.aiManager.analyzeNote(note, with: storageManager)
        }
    }

    private func runQuickHandwritingAnalysis() {
        guard let note = state.currentNote else { return }

        Task {
            let result = await state.aiManager.quickAnalyzeHandwriting(note)

            await MainActor.run {
                let message = ChatMessage(
                    content: "Handwriting Analysis Result:\n\(result)",
                    isUser: false,
                    model: "AI Assistant"
                )
                state.messages.append(message)
            }
        }
    }

    private func runContentGapAnalysis() {
        guard let note = state.currentNote else { return }

        Task {
            let result = await state.aiManager.quickAnalyzeContent(note)

            await MainActor.run {
                let gapDescription = result.gaps.map { $0.description }.joined(separator: "\n• ")
                let message = ChatMessage(
                    content: "Content Gap Analysis:\n• \(gapDescription)",
                    isUser: false,
                    model: "AI Assistant"
                )
                state.messages.append(message)
            }
        }
    }

    private func findRelatedNotes() {
        guard let note = state.currentNote else { return }

        let relatedNotes = state.aiManager.findRelatedNotes(for: note, in: storageManager.notes)
        let noteList = relatedNotes.map { "• \($0.title)" }.joined(separator: "\n")

        let message = ChatMessage(
            content: "Related Notes Found:\n\(noteList.isEmpty ? "No related notes found." : noteList)",
            isUser: false,
            model: "AI Assistant"
        )
        state.messages.append(message)
    }

    private func sendContextualMessage() {
        guard !state.userInput.isEmpty, let note = state.currentNote else { return }

        // Add user message
        let userMessage = ChatMessage(
            content: state.userInput,
            isUser: true
        )
        state.messages.append(userMessage)

        // Store input and clear
        let input = state.userInput
        state.userInput = ""
        state.isLoading = true
        state.errorMessage = nil

        // Send contextual message with note information
        let contextualPrompt = """
        User question: \(input)

        Current note context:
        Title: \(note.title)
        Subject: \(note.subject)
        Content: \(note.content)

        Please answer the user's question in the context of this note.
        """

        Task {
            do {
                let response = try await OpenRouterAPI.sendMessage(
                    userMessage: contextualPrompt,
                    model_string: state.selectedModel
                )

                await MainActor.run {
                    state.messages.append(
                        ChatMessage(
                            content: response,
                            isUser: false,
                            model: state.selectedModel
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

    private func acceptSuggestion(_ suggestion: ParsedSuggestion) {
        guard var note = state.currentNote else { return }

        let success = state.aiManager.acceptSuggestion(suggestion, for: &note)
        if success {
            let updatedNote = storageManager.saveNote(note)
            state.currentNote = updatedNote

            // Update current mode to show results
            state.currentMode = .suggestions
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
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
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

struct CompactSuggestionCard: View {
    let suggestion: ParsedSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.type.icon)
                .foregroundColor(suggestion.type.color)
                .font(.body)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.green)
                        .clipShape(Circle())
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.05))
        )
    }
}