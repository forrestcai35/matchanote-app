import SwiftUI

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
    @Published var selectedModel = "Matcha Assistant"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels = ModelConfiguration.getFreeModelNames()
    @Published var subscriptionManager = SubscriptionManager()

    // AI capabilities
    @Published var aiManager = AIAssistantManager()
    @Published var currentNote: Note?
    
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
    private let inputOuterPadding: CGFloat = 16

    var body: some View {
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
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
        .onAppear {
            setupAI()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.messages) { message in
                    if message.isUser {
                        UserMessageView(message: message)
                    } else {
                        AssistantMessageView(message: message)
                    }
                }

                // Show AI analysis progress when running
                if state.aiManager.isAnalyzing {
                    HStack {
                        ProgressView()
                            .padding(.horizontal, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analyzing your note...")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(state.aiManager.currentAnalysisStep)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                    )
                }

                if state.isLoading {
                    HStack {
                        ProgressView()
                            .padding(.horizontal, 4)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }

                if let error = state.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
    }

    private var inputSection: some View {
        VStack(spacing: 8) {
            // Controls row
            HStack {
                // AI Model dropdown
                Menu {
                    ForEach(state.availableModels, id: \.self) { model in
                        Button(model) {
                            state.selectedModel = model
                        }
                    }
                } label: {
                    HStack {
                        Text(state.selectedModel)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 6)
                    .cornerRadius(8)
                }

                // Request status indicator
                if let profile = state.subscriptionManager.userProfile {
                    HStack(spacing: 4) {
                        let isPremium = ModelConfiguration.isPremiumModel(state.selectedModel)
                        let requestType: RequestType = isPremium ? .premium : .normal
                        let remainingRequests =
                            requestType == .premium ? Int64(profile.premiumRequests) : profile.normalRequests
                        let requestTypeText = requestType == .premium ? "Premium" : "Free"

                        Text("\(remainingRequests) \(requestTypeText)")
                            .font(.caption)
                            .foregroundColor(remainingRequests > 0 ? .green : .red)
                            .padding(.horizontal, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                // Add media menu
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
                    Image(systemName: "plus.circle")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 6)

                Spacer()
            }
            .padding(.horizontal)

            ZStack(alignment: .bottomTrailing) {
                VStack {
                    if !state.tempMediaItems.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(state.tempMediaItems) { item in
                                    ZStack(alignment: .topTrailing) {
                                        if case .image = item.type {
                                            #if canImport(UIKit)
                                                if let uiImage = UIImage(data: item.data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(height: 60)
                                                        .cornerRadius(6)
                                                }
                                            #endif
                                        } else if case .file(let name) = item.type {
                                            HStack {
                                                Image(systemName: "doc")
                                                Text(name)
                                                    .lineLimit(1)
                                            }
                                            .padding(6)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(6)
                                            .frame(height: 60)
                                        }

                                        Button(action: {
                                            removeMediaItem(item)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                        .padding(2)
                                    }
                                    .padding(2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    GrowingTextEditor(text: $state.userInput, placeholderText: "Ask me about your notesxf vcszz...")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
                        .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isInputTargeted) {
                            providers, _ in
                            for provider in providers {
                                if provider.canLoadObject(ofClass: URL.self) {
                                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                                        guard let url = url else { return }
                                        DispatchQueue.main.async {
                                            handleDroppedMedia(from: url)
                                        }
                                    }
                                    return true
                                }
                            }
                            return false
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isInputTargeted ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }

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
    }

    // MARK: - AI Intelligence Methods

    private func setupAI() {
        if let apiKey = EnvironmentManager.shared.getLlmAPIKey(for: "OPENROUTER") {
            OpenRouterAPI.configure(apiKey: apiKey)
        }

        Task {
            await state.subscriptionManager.fetchUserProfile()
            await MainActor.run {
                if let profile = state.subscriptionManager.userProfile {
                    state.availableModels = ModelConfiguration.getAvailableModelNames(for: profile.subscriptionTier)
                } else {
                    state.availableModels = ModelConfiguration.getFreeModelNames()
                }
            }
        }
    }

    func setCurrentNote(_ note: Note) {
        state.currentNote = note
    }

    private func sendIntelligentMessage() {
        guard !state.userInput.isEmpty || !state.tempMediaItems.isEmpty else { return }
        guard let note = state.currentNote else {
            sendRegularMessage()
            return
        }

        // Check if user can make this request type
        let isPremium = ModelConfiguration.isPremiumModel(state.selectedModel)
        let requestType: RequestType = isPremium ? .premium : .normal
        guard state.subscriptionManager.canMakeRequest(type: requestType) else {
            state.errorMessage = "Insufficient \(requestType == .premium ? "premium" : "free") requests remaining"
            return
        }

        // Add user message to chat
        let userMessage = ChatMessage(
            content: state.userInput,
            isUser: true,
            mediaItems: state.tempMediaItems.isEmpty ? nil : state.tempMediaItems
        )
        state.messages.append(userMessage)

        // Store input and clear
        let input = state.userInput
        let selectedModel = state.selectedModel
        state.userInput = ""
        state.tempMediaItems = []
        state.isLoading = true
        state.errorMessage = nil

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

                // If needed, analyze the note first to provide context
                if needsAnalysis {
                    // Run quick analysis to get note context
                    let handwritingText = await state.aiManager.quickAnalyzeHandwriting(note)
                    let contentAnalysis = await state.aiManager.quickAnalyzeContent(note)
                    let relatedNotes = state.aiManager.findRelatedNotes(for: note, in: storageManager.notes)

                    // Create rich context prompt
                    contextualPrompt = """
                    User question: \(input)

                    Current note context:
                    Title: \(note.title)
                    Subject: \(note.subject)
                    Typed content: \(note.content)
                    Handwritten content: \(handwritingText)

                    Analysis insights:
                    - Main topics: \(contentAnalysis.insights.mainTopics.joined(separator: ", "))
                    - Questions found: \(contentAnalysis.insights.questions.joined(separator: "; "))
                    - Content gaps: \(contentAnalysis.gaps.map { $0.description }.joined(separator: "; "))

                    Related notes: \(relatedNotes.map { $0.title }.joined(separator: ", "))

                    Please answer the user's question using this note context. Be specific and reference the actual content when possible.
                    """
                }

                // Send to AI with context
                let response = try await OpenRouterAPI.sendMessage(
                    userMessage: contextualPrompt,
                    model_string: selectedModel
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

    private func sendRegularMessage() {
        // Fallback to regular chat without note context
        guard !state.userInput.isEmpty else { return }

        let isPremium = ModelConfiguration.isPremiumModel(state.selectedModel)
        let requestType: RequestType = isPremium ? .premium : .normal
        guard state.subscriptionManager.canMakeRequest(type: requestType) else {
            state.errorMessage = "Insufficient \(requestType == .premium ? "premium" : "free") requests remaining"
            return
        }

        let userMessage = ChatMessage(
            content: state.userInput,
            isUser: true,
            mediaItems: state.tempMediaItems.isEmpty ? nil : state.tempMediaItems
        )
        state.messages.append(userMessage)

        let input = state.userInput
        let selectedModel = state.selectedModel
        state.userInput = ""
        state.tempMediaItems = []
        state.isLoading = true
        state.errorMessage = nil

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

                let response = try await OpenRouterAPI.sendMessage(
                    userMessage: input,
                    model_string: selectedModel
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
        let analysisKeywords = [
            "analyze", "analysis", "what", "how", "why", "explain", "summary", "summarize",
            "gaps", "missing", "incomplete", "improve", "suggest", "help", "understand",
            "clarify", "examples", "related", "connections", "handwriting", "content",
            "topics", "main points", "key concepts", "questions", "review"
        ]

        let lowercaseInput = input.lowercased()
        return analysisKeywords.contains { keyword in
            lowercaseInput.contains(keyword)
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
}