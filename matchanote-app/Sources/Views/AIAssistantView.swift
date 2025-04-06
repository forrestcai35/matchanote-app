import SwiftUI
import matchanote_app

// AI Assistant View
struct AIAssistantView: View {
  @State private var assistantText = ""
  @State private var userInput = ""

  var body: some View {
    VStack(spacing: 0) {
      // Assistant header
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(.blue)

        Text("Matcha Assistant")
          .font(.headline)

        Spacer()
      }
      .padding()
      .background(Color.gray.opacity(0.1))

      // Chat history area
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          // Sample messages
          AssistantMessageView(
            message: "Hi! I'm your Matcha assistant. How can I help you with your notes today?")

        }
        .padding()
      }

      // Input area
      HStack {
        TextField("Ask Matcha Assistant...", text: $userInput)
          .textFieldStyle(RoundedBorderTextFieldStyle())

        Button(action: {
          // Send message functionality would go here
          userInput = ""
        }) {
          Image(systemName: "arrow.up.circle.fill")
            .foregroundColor(.blue)
            .font(.title2)
        }
      }
      .padding()
    }
    .background(Color(.systemBackground))
    .cornerRadius(10)
    .shadow(radius: 2)
    .padding(.trailing)
  }
}

struct AssistantMessageView: View {
  var message: String

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "sparkles")
        .foregroundColor(.blue)
        .padding(.top, 4)

      Text(message)
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
  }
}

struct UserMessageView: View {
  var message: String

  var body: some View {
    HStack {
      Spacer()

      Text(message)
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
  }
}
