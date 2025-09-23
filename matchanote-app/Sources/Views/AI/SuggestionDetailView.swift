import SwiftUI

struct SuggestionDetailView: View {
    let suggestion: ParsedSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingImplementationHint = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    headerCard

                    // Details Card
                    detailsCard

                    // Content Card (if available)
                    if let content = suggestion.content, !content.isEmpty {
                        contentCard(content: content)
                    }

                    // Implementation Guide Card
                    implementationCard

                    // Action Buttons
                    actionButtonsCard
                }
                .padding()
            }
            .navigationTitle("Suggestion Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(suggestion.type.color)
                    .font(.title2)

                Text(suggestion.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(nil)

                Spacer()
            }

            HStack {
                // Priority Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(suggestion.priority.color)
                        .frame(width: 10, height: 10)

                    Text(suggestion.priority.label + " Priority")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(suggestion.priority.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(suggestion.priority.color.opacity(0.1))
                )

                // Type Badge
                HStack(spacing: 4) {
                    Text(suggestion.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(suggestion.type.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(suggestion.type.color.opacity(0.1))
                )

                Spacer()
            }

            Text(suggestion.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
        }
        .padding()
        .background(cardBackground)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                DetailRowWithIcon(
                    icon: "target",
                    title: "Target Location",
                    value: formatTargetLocation(suggestion.targetLocation)
                )

                DetailRowWithIcon(
                    icon: "gear",
                    title: "Action Type",
                    value: formatActionType(suggestion.actionType)
                )

                DetailRowWithIcon(
                    icon: "flag",
                    title: "Priority Level",
                    value: suggestion.priority.label
                )

                if let insertionPoint = suggestion.insertionPoint {
                    DetailRowWithIcon(
                        icon: "location",
                        title: "Insertion Point",
                        value: formatInsertionPoint(insertionPoint)
                    )
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func contentCard(content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Content")
                .font(.headline)
                .fontWeight(.medium)

            Text(content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                .textSelection(.enabled)
        }
        .padding()
        .background(cardBackground)
    }

    private var implementationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Implementation Guide")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: {
                    showingImplementationHint.toggle()
                }) {
                    Image(systemName: showingImplementationHint ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }

            if showingImplementationHint {
                VStack(alignment: .leading, spacing: 8) {
                    Text(getImplementationSteps())
                        .font(.body)
                        .foregroundColor(.secondary)

                    if !getImplementationTips().isEmpty {
                        Text("Tips:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        ForEach(getImplementationTips(), id: \.self) { tip in
                            Text("• \(tip)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.3), value: showingImplementationHint)
    }

    private var actionButtonsCard: some View {
        VStack(spacing: 12) {
            // Primary Actions
            HStack(spacing: 12) {
                Button(action: {
                    onAccept()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept Suggestion")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Dismiss")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Secondary Actions
            HStack(spacing: 12) {
                Button("Copy Content") {
                    if let content = suggestion.content {
                        copyToClipboard(content)
                    } else {
                        copyToClipboard(suggestion.description)
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 1)
                )

                Button("Share") {
                    shareContent()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 1)
                )

                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color.gray.opacity(0.05) : Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Helper Methods

    private func formatTargetLocation(_ location: ParsedSuggestion.TargetLocation) -> String {
        switch location {
        case .beginningOfNote:
            return "Beginning of note"
        case .endOfNote:
            return "End of note"
        case .currentPage:
            return "Current page"
        case .newPage:
            return "New page"
        case .afterSection:
            return "After section"
        case .beforeSection:
            return "Before section"
        case .specificLocation:
            return "Specific location"
        }
    }

    private func formatActionType(_ actionType: ParsedSuggestion.ActionType) -> String {
        switch actionType {
        case .insertText:
            return "Insert text"
        case .insertImage:
            return "Insert image"
        case .createPage:
            return "Create new page"
        case .highlightText:
            return "Highlight text"
        case .addAnnotation:
            return "Add annotation"
        case .linkNote:
            return "Link to note"
        case .scheduleReview:
            return "Schedule review"
        case .researchTopic:
            return "Research topic"
        }
    }

    private func formatInsertionPoint(_ point: ParsedSuggestion.InsertionPoint) -> String {
        var components: [String] = []

        if let pageIndex = point.pageIndex {
            components.append("Page \(pageIndex + 1)")
        }

        if let position = point.textPosition {
            components.append("Position \(position)")
        }

        if let section = point.sectionName {
            components.append("Section: \(section)")
        }

        if let coordinates = point.coordinates {
            components.append("(\(Int(coordinates.x)), \(Int(coordinates.y)))")
        }

        return components.isEmpty ? "Not specified" : components.joined(separator: ", ")
    }

    private func getImplementationSteps() -> String {
        switch suggestion.actionType {
        case .insertText:
            return "This suggestion will add text content to your note at the specified location. The content will be integrated seamlessly with your existing text."

        case .insertImage:
            return "This suggestion involves adding a visual element. You may need to create or find an appropriate image, diagram, or chart to illustrate the concept."

        case .createPage:
            return "This will create a new page in your note specifically for this content. This helps organize complex topics into manageable sections."

        case .highlightText:
            return "This suggestion involves emphasizing certain text in your existing content to draw attention to key points."

        case .addAnnotation:
            return "This will add explanatory notes or comments to specific parts of your content to provide additional context."

        case .linkNote:
            return "This creates connections between this note and related notes in your collection, helping you see relationships between topics."

        case .scheduleReview:
            return "This sets up a reminder to review this content at optimal intervals to improve retention and understanding."

        case .researchTopic:
            return "This identifies topics that would benefit from additional research and provides guidance on what to look for."
        }
    }

    private func getImplementationTips() -> [String] {
        switch suggestion.type {
        case .addDefinition:
            return [
                "Use clear, simple language",
                "Include etymology if relevant",
                "Provide context for when the term is used"
            ]

        case .addExample:
            return [
                "Use concrete, relatable examples",
                "Include both positive and negative examples",
                "Connect examples to personal experience when possible"
            ]

        case .expandConcept:
            return [
                "Break complex ideas into smaller parts",
                "Use analogies and metaphors",
                "Include real-world applications"
            ]

        case .createSummary:
            return [
                "Include only the most important points",
                "Use bullet points for clarity",
                "Keep it concise but comprehensive"
            ]

        case .addDiagram:
            return [
                "Keep diagrams simple and clear",
                "Label all important elements",
                "Use consistent symbols and colors"
            ]

        case .crossReference:
            return [
                "Create meaningful connections",
                "Explain why notes are related",
                "Use consistent linking conventions"
            ]

        case .research:
            return [
                "Use reliable, academic sources",
                "Take notes on key findings",
                "Cite your sources properly"
            ]

        case .clarifyPoint:
            return [
                "Address the specific confusion",
                "Use simpler language",
                "Provide additional context"
            ]

        case .organize:
            return [
                "Group related concepts together",
                "Use clear headings and structure",
                "Create logical flow between sections"
            ]

        case .review:
            return [
                "Schedule reviews at increasing intervals",
                "Test your understanding actively",
                "Update content based on new insights"
            ]
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func shareContent() {
        let shareText = """
        \(suggestion.title)

        \(suggestion.description)

        \(suggestion.content ?? "")
        """

        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #endif
    }
}

struct DetailRowWithIcon: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
