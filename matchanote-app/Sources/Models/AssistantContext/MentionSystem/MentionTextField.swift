import SwiftUI

/// A text field that supports @ mentions with autocomplete
struct MentionTextField: View {
    @Binding var text: String
    @Binding var isTextEditorFocused: Bool
    @ObservedObject var mentionManager: MentionManager

    let placeholderText: String
    let submitsOnReturn: Bool
    let onSubmit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Custom binding that immediately processes text changes
    private var textBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                text = newValue
                // Immediately process the text change synchronously
                handleTextChange(newValue)
            }
        )
    }

    var body: some View {
        // The main text editor without suggestions
        GrowingTextEditor(
            text: textBinding,
            isTextEditorFocused: $isTextEditorFocused,
            placeholderText: placeholderText,
            submitsOnReturn: submitsOnReturn,
            onSubmit: {
                // Clear suggestions before submitting
                mentionManager.clearSuggestions()
                onSubmit()
            }
        )
        .onChange(of: isTextEditorFocused) { _, newValue in
            if !newValue {
                // Clear suggestions when focus is lost
                mentionManager.clearSuggestions()
            }
        }
    }

    // MARK: - Text Change Handling

    private func handleTextChange(_ newText: String) {
        // Detect if user is typing a mention
        if let query = mentionManager.detectMentionQuery(in: newText) {
            mentionManager.updateSuggestions(query: query)
        } else {
            mentionManager.clearSuggestions()
        }
    }

    // MARK: - Mention Insertion

    private func insertMention(_ mention: Mention) {
        let newText = mentionManager.insertMention(mention, into: text)
        text = newText
        mentionManager.clearSuggestions()
    }
}

// MARK: - Preview

struct MentionTextField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var isFocused = false
        @StateObject private var mentionManager: MentionManager

        init() {
            // Create a mock storage manager for preview
            let storageManager = StorageManager()
            _mentionManager = StateObject(wrappedValue: MentionManager(storageManager: storageManager))
        }

        var body: some View {
            VStack {
                Text("Type @ to see mentions")
                    .font(.jost(.caption()))
                    .foregroundColor(.gray)

                MentionTextField(
                    text: $text,
                    isTextEditorFocused: $isFocused,
                    mentionManager: mentionManager,
                    placeholderText: "Try typing @...",
                    submitsOnReturn: true,
                    onSubmit: {
                        print("Submitted: \(text)")
                    }
                )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
                .padding()

                Text("Current text: \(text)")
                    .font(.jost(.caption()))
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
