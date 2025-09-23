import SwiftUI

struct AIAnalysisView: View {
    let analysis: IntelligentAnalysis
    let onSuggestionAccept: (ParsedSuggestion) -> Void
    let onSuggestionDismiss: (ParsedSuggestion) -> Void

    @StateObject private var suggestionParser = SuggestionParser()
    @State private var selectedTab = 0
    @State private var showingDetailView = false
    @State private var selectedSuggestion: ParsedSuggestion?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                        .font(.title2)

                    Text("AI Analysis")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(formatTimestamp(analysis.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(analysis.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.blue.opacity(0.05))
            )

            // Tab Selection
            Picker("Analysis View", selection: $selectedTab) {
                Text("Insights").tag(0)
                Text("Suggestions").tag(1)
                Text("Gaps").tag(2)
                Text("Details").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            // Content
            ScrollView {
                switch selectedTab {
                case 0:
                    insightsView
                case 1:
                    suggestionsView
                case 2:
                    gapsView
                case 3:
                    detailsView
                default:
                    insightsView
                }
            }
        }
        .onAppear {
            loadSuggestions()
        }
    }

    private var insightsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !analysis.keyInsights.isEmpty {
                SectionView(title: "Key Insights", icon: "lightbulb") {
                    ForEach(analysis.keyInsights, id: \.self) { insight in
                        InsightRow(text: insight, icon: "arrow.right")
                    }
                }
            }

            if !analysis.handwritingAnalysis.isEmpty && analysis.handwritingAnalysis != "No handwriting analysis available" {
                SectionView(title: "Handwriting Analysis", icon: "pencil.and.outline") {
                    Text(analysis.handwritingAnalysis)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                        )
                }
            }

            if !analysis.relatedNotes.isEmpty {
                SectionView(title: "Related Notes", icon: "arrow.triangle.branch") {
                    ForEach(analysis.relatedNotes, id: \.self) { noteId in
                        RelatedNoteRow(noteId: noteId)
                    }
                }
            }
        }
        .padding()
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if suggestionParser.suggestions.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "No suggestions available",
                    description: "The AI analysis didn't generate any specific suggestions for this note."
                )
                .padding()
            } else {
                ForEach(suggestionParser.suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }, id: \.id) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        onAccept: { onSuggestionAccept(suggestion) },
                        onDismiss: { onSuggestionDismiss(suggestion) },
                        onShowDetail: {
                            selectedSuggestion = suggestion
                            showingDetailView = true
                        }
                    )
                }
            }
        }
        .padding()
        .sheet(item: $selectedSuggestion) { suggestion in
            SuggestionDetailView(
                suggestion: suggestion,
                onAccept: { onSuggestionAccept(suggestion) },
                onDismiss: { onSuggestionDismiss(suggestion) }
            )
        }
    }

    private var gapsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if analysis.contentGaps.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No gaps found",
                    description: "The AI analysis didn't identify any significant content gaps."
                )
                .padding()
            } else {
                ForEach(analysis.contentGaps, id: \.self) { gap in
                    GapCard(description: gap)
                }
            }
        }
        .padding()
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRow(title: "Analysis Time", value: formatDetailedTimestamp(analysis.timestamp))
            DetailRow(title: "Note ID", value: analysis.noteId.uuidString)

            if !analysis.keyInsights.isEmpty {
                DetailSection(title: "All Insights", items: analysis.keyInsights)
            }

            if !analysis.suggestions.isEmpty {
                DetailSection(title: "All Suggestions", items: analysis.suggestions)
            }
        }
        .padding()
    }

    private func loadSuggestions() {
        let suggestions = suggestionParser.parseAIResponse(analysis.summary + "\n" + analysis.suggestions.joined(separator: "\n"), for: analysis.noteId)
        suggestionParser.suggestions = suggestions
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDetailedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }

            content
        }
    }
}

struct InsightRow: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .padding(.top, 2)

            Text(text)
                .font(.body)
                .lineLimit(nil)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct RelatedNoteRow: View {
    let noteId: UUID

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.gray)

            Text("Related Note")
                .font(.body)

            Spacer()

            Text(noteId.uuidString.prefix(8))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SuggestionCard: View {
    let suggestion: ParsedSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onShowDetail: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: suggestion.type.icon)
                        .foregroundColor(suggestion.type.color)
                        .font(.body)

                    Text(suggestion.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                Spacer()

                // Priority badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(suggestion.priority.color)
                        .frame(width: 8, height: 8)

                    Text(suggestion.priority.label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(suggestion.priority.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(suggestion.priority.color.opacity(0.1))
                )
            }

            // Description
            Text(suggestion.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)

            // Content preview (if available)
            if let content = suggestion.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                    .lineLimit(2)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .clipShape(Capsule())
                }

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                Button(action: onShowDetail) {
                    Text("Details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.05) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct GapCard: View {
    let description: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.body)
                .padding(.top, 2)

            Text(description)
                .font(.body)
                .lineLimit(nil)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text(title)
                .font(.headline)
                .fontWeight(.medium)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.vertical, 4)
    }
}

struct DetailSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.body)
                    .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
}