import SwiftUI

// MARK: - Study Mode Toggle
struct StudySubModeToggle: View {
    @Binding var selectedMode: StudySubMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            quizButton
            flashcardsButton
        }
        .padding(3)
        .background(containerBackground)
    }
    
    // MARK: - Quiz Button
    private var quizButton: some View {
        Button(action: quizAction) {
            quizContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var quizAction: () -> Void {
        return {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedMode = .quiz
            }
        }
    }
    
    private var quizContent: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle.fill")
                .font(.jost(.caption2()))
            Text("Quiz")
                .font(.jost(.caption()))
        }
        .foregroundColor(selectedMode == .quiz ? .white : .secondary)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(quizBackground)
        .contentShape(Rectangle())
    }
    
    private var quizBackground: some View {
        ZStack {
            if selectedMode == .quiz {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.quizGradient)
                    .shadow(color: Color.matchaGreen.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Flashcards Button
    private var flashcardsButton: some View {
        Button(action: flashcardsAction) {
            flashcardsContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var flashcardsAction: () -> Void {
        return {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedMode = .flashcards
            }
        }
    }
    
    private var flashcardsContent: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.stack.fill")
                .font(.jost(.caption2()))
            Text("Flashcards")
                .font(.jost(.caption()))
        }
        .foregroundColor(selectedMode == .flashcards ? .white : .secondary)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(flashcardsBackground)
        .contentShape(Rectangle())
    }
    
    private var flashcardsBackground: some View {
        ZStack {
            if selectedMode == .flashcards {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.flashcardsGradient)
                    .shadow(color: Color.premiumBlue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Container Background
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                colorScheme == .dark
                    ? Color(white: 0.15).opacity(0.5)
                    : Color.gray.opacity(0.12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.gray.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Responsive Quiz Header
struct ResponsiveQuizHeader: View {
    let current: Int
    let total: Int
    let score: (correct: Int, total: Int)?
    let onEdit: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Full layout for wider windows
            fullLayout

            // Compact layout for medium windows
            compactLayout

            // Minimal layout for narrow windows
            minimalLayout
        }
    }

    private var fullLayout: some View {
        HStack(spacing: 8) {
            ProgressIndicator(current: current, total: total)

            Spacer()

            StudyActionButton(
                title: "Edit",
                icon: "pencil.circle",
                color: .matchadark_light,
                action: onEdit
            )
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 8) {
            ProgressIndicator(current: current, total: total)

            Spacer()

            IconOnlyButton(icon: "pencil.circle", color: .matchadark_light, action: onEdit)
        }
    }

    private var minimalLayout: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressIndicator(current: current, total: total)
                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()
                IconOnlyButton(icon: "pencil.circle", color: .matchadark_light, action: onEdit)
            }
        }
    }
}

// MARK: - Responsive Flashcard Header
struct ResponsiveFlashcardHeader: View {
    let current: Int
    let total: Int
    let progress: (favorites: Int, total: Int)?
    let onEdit: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Full layout for wider windows
            fullLayout

            // Compact layout for medium windows
            compactLayout

            // Minimal layout for narrow windows
            minimalLayout
        }
    }

    private var fullLayout: some View {
        HStack(spacing: 8) {
            ProgressIndicator(current: current, total: total)

            Spacer()

            StudyActionButton(
                title: "Edit",
                icon: "pencil.circle",
                color: .matchadark_light,
                action: onEdit
            )
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 8) {
            ProgressIndicator(current: current, total: total)

            Spacer()

            IconOnlyButton(icon: "pencil.circle", color: .matchadark_light, action: onEdit)
        }
    }

    private var minimalLayout: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressIndicator(current: current, total: total)
                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()
                IconOnlyButton(icon: "pencil.circle", color: .matchadark_light, action: onEdit)
            }
        }
    }
}

// MARK: - Progress Indicator
struct ProgressIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.jost(.caption()))
                .foregroundColor(.gray)
            Text("\(current)/\(total)")
                .font(.jost(.caption()))
                .fontWeight(.medium)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Icon-Only Button
struct IconOnlyButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.jost(.body()))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Action Buttons
struct StudyActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.jost(.caption()))
                Text(title)
                    .font(.jost(.caption()))
                    .lineLimit(1)
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State View
struct StudyEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text(title)
                    .font(.jost(.headline()))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.jost(.subheadline()))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                MatchaButton(actionTitle, icon: "sparkles", action: action)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
    }
}

// MARK: - Loading View
struct StudyLoadingView: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.jost(.subheadline()))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
    }
}

// MARK: - Feedback Badge
struct FeedbackBadge: View {
    let isCorrect: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.jost(.caption()))
            Text(isCorrect ? "Correct" : "Incorrect")
                .font(.jost(.caption()))
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isCorrect ? Color.green : Color.red)
        )
    }
}
