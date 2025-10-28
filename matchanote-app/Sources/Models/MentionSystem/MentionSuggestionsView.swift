import SwiftUI

/// Displays a dropdown list of mention suggestions
struct MentionSuggestionsView: View {
    let suggestions: [MentionSuggestion]
    let onSelect: (Mention) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button(action: {
                        onSelect(suggestion.mention)
                    }) {
                        HStack(spacing: 8) {
                            // Icon
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 13))
                                .foregroundColor(iconColor(for: suggestion.mention.type))
                                .frame(width: 16, height: 16)

                            // Display name only
                            Text(suggestion.mention.displayName)
                                .font(.jost(.callout(14)))
                                .foregroundColor(
                                    colorScheme == .dark ? .white : .black
                                )
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        Rectangle()
                            .fill(Color.gray.opacity(0.0001))
                    )
                    .hoverEffect(.highlight)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxHeight: 140) // Height for ~4 items
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private func iconColor(for type: MentionType) -> Color {
        switch type {
        case .note:
            return .blue
        case .folder:
            return .orange
        case .subject:
            return .green
        }
    }

    private func typeBadge(for type: MentionType) -> String {
        switch type {
        case .note:
            return "Note"
        case .folder:
            return "Folder"
        case .subject:
            return "Subject"
        }
    }
}

// MARK: - Preview

struct MentionSuggestionsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSuggestions = [
            MentionSuggestion(
                mention: Mention(id: "1", type: .note, displayName: "Physics Notes"),
                subtitle: "Science"
            ),
            MentionSuggestion(
                mention: Mention(id: "2", type: .folder, displayName: "Math Homework"),
                subtitle: "Folder / Assignments"
            ),
            MentionSuggestion(
                mention: Mention(id: "3", type: .subject, displayName: "Chemistry"),
                subtitle: "Subject"
            )
        ]

        VStack {
            Spacer()
            MentionSuggestionsView(suggestions: sampleSuggestions) { mention in
                print("Selected: \(mention.displayName)")
            }
            .frame(width: 300)
            .padding()
            Spacer()
        }
        .background(Color.gray.opacity(0.2))
    }
}
