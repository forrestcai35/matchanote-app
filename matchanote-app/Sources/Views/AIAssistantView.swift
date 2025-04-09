import SwiftUI
import matchanote_app

// Message model to represent chat messages
struct ChatMessage: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
  let model: String?

  init(content: String, isUser: Bool, model: String? = nil) {
    self.content = content
    self.isUser = isUser
    self.model = model
  }
}

// AI Assistant View
struct AIAssistantView: View {
  @State private var messages: [ChatMessage] = []
  @State private var userInput = ""
  @State private var selectedModel = "gpt-4o"
  @State private var showingImagePicker = false
  @State private var contextInfo = "Last updated: Notes section"
  @State private var isLoading = false
  @State private var errorMessage: String? = nil

  // API keys loaded from .env file
  private var openAIKey: String? {
    EnvironmentManager.shared.getAPIKey(for: "OPENAI")
  }

  private var deepSeekKey: String? {
    EnvironmentManager.shared.getAPIKey(for: "DEEPSEEK")
  }

  private var claudeKey: String? {
    EnvironmentManager.shared.getAPIKey(for: "CLAUDE")
  }

  let availableModels = [
    "gpt-4o", "gpt-4o-mini", "o1", "deepseek-r1", "claude-3.7-sonnet",
    "claude-3.5-sonnet",
  ]

  var body: some View {
    VStack(spacing: 0) {
      // Assistant header
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(.green)

        Text("Matcha Assistant")
          .font(.headline)

        Spacer()

      }
      .padding()
      .background(Color.green.opacity(0.1))

      // Chat history area
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {

          // Display messages
          ForEach(messages) { message in
            if message.isUser {
              HStack {
                Spacer()
                Text(message.content)
                  .padding(10)
                  .background(Color.gray.opacity(0.2))
                  .cornerRadius(10)
              }
            } else {
              AssistantMessageView(message: message.content, model: message.model)
            }
          }

          if isLoading {
            HStack {
              ProgressView()
                .padding(.horizontal, 4)
              Text("Thinking...")
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
          }

          if let error = errorMessage {
            Text(error)
              .foregroundColor(.red)
              .font(.caption)
              .padding(.vertical, 8)
          }
        }
        .padding()
      }

      // Input area
      VStack(spacing: 8) {
        // Controls row
        HStack {
          // AI Model dropdown
          Menu {
            ForEach(availableModels, id: \.self) { model in
              Button(model) {
                selectedModel = model
              }
            }
          } label: {
            HStack {
              Text(selectedModel)
                .font(.caption)
                .foregroundColor(.primary)
              Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 6)
            .cornerRadius(8)
          }
          HStack {

            Image(systemName: "photo")
              .foregroundColor(.gray)
          }
          .padding(.horizontal, 6)
          .cornerRadius(8)

          Spacer()
        }
        .padding(.horizontal)

        // Custom text input with embedded button
        ZStack(alignment: .bottomTrailing) {
          // Growing text editor
          GrowingTextEditor(text: $userInput, placeholderText: "Ask Matcha Assistant...")
            .padding(.trailing, 40)  // Prevent text from overlapping the button
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(1)  // Ensure the corner radius is visible

          // Send button inside the text field
          Button(action: {
            sendMessage()
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(
                userInput.isEmpty || isLoading ? .gray : .green
              )
              .font(.title2)
          }
          .disabled(userInput.isEmpty || isLoading)
          .padding(8)
        }
        .padding([.horizontal, .bottom])
      }
    }
    .background(Color(.systemBackground))

  }

  private func sendMessage() {
    // Add user message to chat
    if !userInput.isEmpty && !isLoading {
      let userMessage = ChatMessage(content: userInput, isUser: true)
      messages.append(userMessage)

      let prompt = userInput
      userInput = ""

      // Start loading
      isLoading = true
      errorMessage = nil

      // Make actual LLM API call based on selected model
      Task {
        do {
          var response: String
          var modelUsed = selectedModel
          var success = false

          // Try to call the appropriate AI service based on selected model
          if selectedModel.contains("gpt") && openAIKey != nil {
            // Configure with the specific OpenAI model
            LLMManager.shared.configureOpenAI(apiKey: openAIKey!, model: selectedModel)
            response = try await LLMManager.shared.generateWithOpenAI(prompt: prompt)
            success = true
          } else if selectedModel.contains("deepseek") && deepSeekKey != nil {
            // Configure with the specific DeepSeek model
            LLMManager.shared.configureDeepSeek(apiKey: deepSeekKey!, model: selectedModel)
            response = try await LLMManager.shared.generateWithDeepSeek(prompt: prompt)
            success = true
          } else if selectedModel.contains("claude") && claudeKey != nil {
            // Configure with the specific Claude model
            LLMManager.shared.configureClaude(apiKey: claudeKey!, model: selectedModel)
            response = try await LLMManager.shared.generateWithClaude(prompt: prompt)
            success = true
          } else if openAIKey != nil {
            // Default to OpenAI if model type is unclear but we have an OpenAI key
            LLMManager.shared.configureOpenAI(apiKey: openAIKey!, model: "gpt-4o")
            response = try await LLMManager.shared.generateWithOpenAI(prompt: prompt)
            modelUsed = "gpt-4o"
            success = true
          } else if claudeKey != nil {
            // Fallback to Claude if we have that API key
            LLMManager.shared.configureClaude(apiKey: claudeKey!)
            response = try await LLMManager.shared.generateWithClaude(prompt: prompt)
            modelUsed = "claude-3.5-sonnet"
            success = true
          } else if deepSeekKey != nil {
            // Last resort: DeepSeek
            LLMManager.shared.configureDeepSeek(apiKey: deepSeekKey!)
            response = try await LLMManager.shared.generateWithDeepSeek(prompt: prompt)
            modelUsed = "deepseek-r1"
            success = true
          } else {
            throw LLMError.apiError("No API keys configured for selected model")
          }

          if success {
            // Update UI on main thread
            await MainActor.run {
              isLoading = false
              let responseMessage = ChatMessage(content: response, isUser: false, model: modelUsed)
              messages.append(responseMessage)
            }
          }
        } catch {
          // Handle errors
          await MainActor.run {
            isLoading = false
            errorMessage = "Error: \(error.localizedDescription)"
          }
        }
      }
    }
  }
}

struct AssistantMessageView: View {
  var message: String
  var model: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let model = model {
        Text("🤖 \(model)")
          .font(.caption2)
          .foregroundColor(.gray)
          .padding(.bottom, 2)
      }

      Text(message)
        .padding(10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)

      HStack {
        Button(action: {
          // Copy to clipboard functionality
          UIPasteboard.general.string = message
        }) {
          Image(systemName: "doc.on.doc")
            .font(.caption)
            .foregroundColor(.gray)
        }
        .buttonStyle(.plain)

      }
      .padding(.top, 4)
    }
  }
}

struct UserMessageView: View {
  var message: String
  @State private var selectedModel = "gpt-4o"
  @State private var showingImagePicker = false
  @State private var contextInfo = "Last updated: Notes section"

  let availableModels = [
    "gpt-4o", "gpt-4o-mini", "o1", "deepseek-r1", "claude-3.7-sonnet",
    "claude-3.5-sonnet",
  ]

  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      // Context section
      Text(contextInfo)
        .font(.caption)
        .foregroundColor(.gray)
        .padding(.horizontal, 10)

      // Message with controls
      HStack {
        // AI Model dropdown
        Menu {
          ForEach(availableModels, id: \.self) { model in
            Button(model) {
              selectedModel = model
            }
          }
        } label: {
          HStack {
            Text(selectedModel)
              .font(.caption)
              .foregroundColor(.primary)

            Spacer()

            Text(message)
              .padding(10)
              .background(Color.gray.opacity(0.2))
              .cornerRadius(10)
          }
        }

        Image(systemName: "document.on.document")
          .foregroundColor(.gray)
      }
    }
  }
}
