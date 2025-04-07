import SwiftUI
import matchanote_app

// Message model to represent chat messages
struct ChatMessage: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
}

// AI Assistant View
struct AIAssistantView: View {
  @State private var messages: [ChatMessage] = [
    ChatMessage(
      content: "Hi! I'm your Matcha assistant. How can I help you with your notes today?",
      isUser: false)
  ]
  @State private var userInput = ""
  @State private var selectedModel = "gpt-4o"
  @State private var showingImagePicker = false
  @State private var contextInfo = "Last updated: Notes section"

  let availableModels = ["gpt-4o", "o1", "deepseek-r1", "claude-3.7-sonnet"]

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
              AssistantMessageView(message: message.content)
            }
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
            // Add user message to chat
            if !userInput.isEmpty {
              let userMessage = ChatMessage(content: userInput, isUser: true)
              messages.append(userMessage)

              // Simulate assistant response (in a real app, this would call an API)
              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let responseMessage = ChatMessage(
                  content: "I received your message: \"\(userInput)\"", isUser: false)
                messages.append(responseMessage)
              }

              userInput = ""
            }
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(.green)
              .font(.title2)
          }
          .padding(8)
        }
        .padding([.horizontal, .bottom])
      }
    }
    .background(Color(.systemBackground))
  }
}

struct AssistantMessageView: View {
  var message: String

  var body: some View {
    VStack(alignment: .leading) {

      Text(message)
        .padding(.vertical, 6)

      Image(systemName: "document.on.document")
        .foregroundColor(.gray)
    }
  }
}

struct UserMessageView: View {
  var message: String
  @State private var selectedModel = "GPT-4"
  @State private var showingImagePicker = false
  @State private var contextInfo = "Last updated: Notes section"

  let availableModels = ["gpt-4o", "o1", "deepseek-r1", "claude-3.7-sonnet"]

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
