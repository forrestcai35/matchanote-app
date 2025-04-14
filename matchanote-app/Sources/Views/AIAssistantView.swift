import SwiftUI
import matchanote_app

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

// import matchanote_app  // Commented out until correct module name is confirmed

// Add a state object to share assistant state across orientation changes
class AIAssistantState: ObservableObject {
  @Published var messages: [ChatMessage] = []
  @Published var userInput = ""
  @Published var selectedModel = "qwen/qwq-32b:free"
  @Published var isLoading = false
  @Published var errorMessage: String? = nil
  @Published var availableModels = ["qwen/qwq-32b:free", "deepseek/deepseek-r1-zero:free"]
}

struct ChatMessage: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
  let model: String

  init(content: String, isUser: Bool, model: String = "") {
    self.content = content
    self.isUser = isUser
    self.model = model
  }
}

// AI Assistant View
struct AIAssistantView: View {
  // Use an environment object instead of local state to persist across orientation changes
  @EnvironmentObject private var state: AIAssistantState
  @State private var showingImagePicker = false
  @State private var contextInfo = ""

  // Configure models
  init() {
    OpenRouterAPI.configure(apiKey: EnvironmentManager.shared.getLlmAPIKey(for: "OPENROUTER")!)
  }

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
          ForEach(state.messages) { message in
            if message.isUser {
              UserMessageView(message: message)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              AssistantMessageView(message: message)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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

      // Input area
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
          GrowingTextEditor(text: $state.userInput, placeholderText: "Ask Matcha Assistant...")
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
              if !state.userInput.isEmpty && !state.isLoading {
                sendMessage()
              }
            }

          // Send message when the user presses the send button
          Button(action: {
            sendMessage()
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(
                state.userInput.isEmpty || state.isLoading ? .gray : .green
              )
              .font(.title2)
          }
          .disabled(state.userInput.isEmpty || state.isLoading)
          .padding(8)
        }
        .padding([.horizontal, .bottom])
      }
    }
    #if canImport(UIKit)
      .background(Color(UIColor.systemBackground))
    #else
      .background(Color(.windowBackgroundColor))
    #endif

  }

  private func sendMessage() {
    guard !state.userInput.isEmpty else { return }

    // Add user message to chat
    let userMessage = ChatMessage(content: state.userInput, isUser: true)
    state.messages.append(userMessage)

    // Store the input and clear the field
    let input = state.userInput
    state.userInput = ""

    // Set loading state
    state.isLoading = true
    state.errorMessage = nil

    // Call API
    Task {
      do {
        let response = try await OpenRouterAPI.sendMessage(
          userMessage: input, model: state.selectedModel)

        await MainActor.run {
          state.messages.append(
            ChatMessage(
              content: response,
              isUser: false,
              model: state.selectedModel
            ))
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
}

struct AssistantMessageView: View {
  var message: ChatMessage

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {

      Text(message.content)
        .padding(10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)

      HStack {
        Button(action: {
          // Copy to clipboard functionality
          #if canImport(UIKit)
            UIPasteboard.general.string = message.content
          #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content, forType: .string)
          #endif
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
  var message: ChatMessage
  @EnvironmentObject private var state: AIAssistantState

  init(message: ChatMessage) {
    self.message = message
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      // Message section with chat bubble
      Text(message.content)
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .foregroundColor(.primary)
        .cornerRadius(10)
        .padding(.horizontal, 4)

      // Controls
      HStack {
        Menu {
          ForEach(state.availableModels, id: \.self) { model in
            Button(model) {
              // This would update the model if needed
            }
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.caption)
            .foregroundColor(.gray)
        }
        .buttonStyle(.plain)

        Image(systemName: "doc.on.doc")
          .font(.caption)
          .foregroundColor(.gray)
      }
      .padding(.top, 2)
    }
  }
}
