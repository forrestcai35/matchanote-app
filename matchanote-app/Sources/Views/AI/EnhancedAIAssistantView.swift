import SwiftUI
import PencilKit

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
            // Look for **bold** patterns first (longer pattern takes precedence)
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
    
    // Callback to save current canvas data before analysis
    var saveCanvasDataCallback: (() -> Void)?
    @Published var selectedModel = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels: [String] = []
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
            // Set initial model immediately to avoid delay
            setInitialModel()
            refreshAvailableModels()
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

                // Text input in the middle
                TextField("Ask about your note...", text: $state.userInput)
                    .font(.system(size: 15))
                    .textFieldStyle(.roundedBorder)
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
        // Configure API
        if let openRouterKey = EnvironmentManager.shared.get("OPENROUTER_API_KEY"),
           let openAIKey = EnvironmentManager.shared.get("OPENAI_API_KEY"),
           let anthropicKey = EnvironmentManager.shared.get("CLAUDE_API_KEY"),
           let deepSeekKey = EnvironmentManager.shared.get("DEEPSEEK_API_KEY"),
           let googleKey = EnvironmentManager.shared.get("GEMINI_API_KEY"),
           let xKey = EnvironmentManager.shared.get("X_API_KEY"),
           let mistralKey = EnvironmentManager.shared.get("MISTRAL_API_KEY") {
            LlmAPI.configure(
                openRouterAPIKey: openRouterKey,
                openAIAPIKey: openAIKey,
                anthropicAPIKey: anthropicKey,
                deepSeekAPIKey: deepSeekKey,
                googleAPIKey: googleKey,
                xAPIKey: xKey,
                mistralAPIKey: mistralKey
            )
        }

        // Load user profile and available models
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
        
        print("💾 AI Analysis (Enhanced): Saving note with latest canvas data: \(note.title)")
        print("📊 Before save - drawingDataByPage keys: \(note.drawingDataByPage.keys.sorted())")
        
        // CRITICAL: Save current canvas data - this collects from active canvases and saves to storage
        if state.saveCanvasDataCallback != nil {
            print("✅ Callback exists, calling saveCurrentCanvasData()...")
            state.saveCanvasDataCallback?()
        } else {
            print("⚠️ WARNING: saveCanvasDataCallback is nil! Canvas data won't be saved!")
        }
        
        // Get the freshly saved note from storage (same as export flow)
        if let latestNote = storageManager.notes.first(where: { $0.id == note.id }) {
            print("📊 After save - drawingDataByPage keys: \(latestNote.drawingDataByPage.keys.sorted())")
            print("✅ Note updated with latest canvas data for AI analysis")
            state.currentNote = latestNote
        } else {
            print("❌ ERROR: Could not find note in storage after save!")
        }
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

    private func runFullAnalysis() {
        guard let note = state.currentNote else { return }
        
        // Save the note before analysis to ensure AI has access to latest content
        saveCurrentNote()

        Task {
            await state.aiManager.analyzeNote(note, with: storageManager)
        }
    }

    private func runQuickHandwritingAnalysis() {
        guard let note = state.currentNote else { return }
        
        // Save the note before analysis
        saveCurrentNote()

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
        
        // Save the note before analysis
        saveCurrentNote()

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
        
        // Save the note before analysis to ensure AI has access to latest content
        saveCurrentNote()

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

        // Determine if we need to analyze the note first
        let needsAnalysis = shouldAnalyzeNote(for: input)
        
        var contextualPrompt = input
        
        if needsAnalysis {
            // Convert note to images for visual analysis
            Task {
                let noteImages = await convertNoteToImages(note)
                
                // Create rich context prompt with images
                contextualPrompt = """
                User question: \(input)
                
                I've provided images of the note for visual analysis. Please examine the note content (both typed text and handwritten content) and answer the user's question based on what you can see in the note.
                
                Note details:
                Title: \(note.title)
                Subject: \(note.subject)
                """
                
                sendMessageWithPromptAndImages(contextualPrompt, images: noteImages)
            }
            return
        } else {
            // Simple contextual prompt without analysis
            contextualPrompt = """
            User question: \(input)

            Current note context:
            Title: \(note.title)
            Subject: \(note.subject)
            Content: \(note.content)

            Please answer the user's question in the context of this note.
            """
        }
        
        sendMessageWithPrompt(contextualPrompt)
    }
    
    private func sendMessageWithPrompt(_ prompt: String) {
        Task {
            do {
                let response = try await LlmAPI.sendMessage(
                    userMessage: prompt,
                    model_string: state.selectedModel,
                    mediaItems: state.tempMediaItems.isEmpty ? nil : state.tempMediaItems
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
    
    private func sendMessageWithPromptAndImages(_ prompt: String, images: [MediaItem]) {
        Task {
            do {
                let response = try await LlmAPI.sendMessage(
                    userMessage: prompt,
                    model_string: state.selectedModel,
                    mediaItems: images
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