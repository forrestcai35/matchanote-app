import SwiftUI

struct FlashcardView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @State private var currentCardIndex = 0
    @State private var isFlipped = false
    @Environment(\.colorScheme) private var colorScheme

    var flashcards: [Flashcard] {
        state.studySession?.flashcards ?? []
    }

    var currentCard: Flashcard? {
        guard currentCardIndex < flashcards.count else { return nil }
        return flashcards[currentCardIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if flashcards.isEmpty {
                StudyEmptyState(
                    icon: "rectangle.stack",
                    title: "No Flashcards",
                    message: "Generate flashcards from your notes to start studying",
                    actionTitle: "Generate Flashcards",
                    action: generateFlashcards
                )
            } else {
                // Header with progress - Responsive layout
                ResponsiveFlashcardHeader(
                    current: currentCardIndex + 1,
                    total: flashcards.count,
                    progress: state.studySession?.flashcardProgress,
                    onAddMore: addMoreFlashcards,
                    onRegenerate: regenerateFlashcards
                )
                .padding()

                // Card area
                ZStack {
                    if let card = currentCard {
                        flashcardCard(for: card)
                            .rotation3DEffect(
                                .degrees(isFlipped ? 180 : 0),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isFlipped.toggle()
                                }
                            }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()

                // Flip hint
                if !isFlipped {
                    Text("Tap card to reveal answer")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                } else {
                    // Confidence buttons when flipped
                    VStack(spacing: 12) {
                        Text("How well did you know this?")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            confidenceButton(level: .hard, title: "Hard", color: .red)
                            confidenceButton(level: .medium, title: "Medium", color: .orange)
                            confidenceButton(level: .easy, title: "Easy", color: .green)
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                HStack(spacing: 12) {
                    Button(action: previousCard) {
                        Image(systemName: "chevron.left")
                            .font(.jost(.caption()))
                            .foregroundColor(currentCardIndex > 0 ? .matchadark_light : .gray)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .disabled(currentCardIndex <= 0)
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: nextCard) {
                        Image(systemName: "chevron.right")
                            .font(.jost(.caption()))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.matchadark_light)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
    }

    // MARK: - Flashcard Card View
    @ViewBuilder
    private func flashcardCard(for card: Flashcard) -> some View {
        ZStack {
            // Back of card (answer)
            VStack(spacing: 0) {
                Text("Answer")
                    .font(.jost(.caption()))
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                ScrollView {
                    Text(card.back)
                        .font(.jost(.body()))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    // Glassy background with gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            colorScheme == .dark 
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.95),
                                        Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.98),
                                        Color(red: 0.98, green: 0.98, blue: 1.0).opacity(0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                    
                    // Glassy border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark 
                                    ? [Color.white.opacity(0.15), Color.white.opacity(0.05)]
                                    : [Color.white.opacity(0.8), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 8)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
            )
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)

            // Front of card (question)
            VStack(spacing: 0) {
                Text("Question")
                    .font(.jost(.caption()))
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Text(card.front)
                            .font(.jost(.title()))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity)

                        // Show confidence badge if reviewed
                        if card.confidence != .notSeen {
                            confidenceBadge(for: card.confidence)
                        }
                        
                        Spacer()
                    }
                    .frame(minHeight: 0)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    // Glassy background with gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            colorScheme == .dark 
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.95),
                                        Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.98),
                                        Color(red: 0.98, green: 0.98, blue: 1.0).opacity(0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                    
                    // Glassy border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark 
                                    ? [Color.white.opacity(0.15), Color.white.opacity(0.05)]
                                    : [Color.white.opacity(0.8), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 8)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
            )
            .opacity(isFlipped ? 0 : 1)
        }
    }

    // MARK: - Confidence Button
    @ViewBuilder
    private func confidenceButton(level: ConfidenceLevel, title: String, color: Color) -> some View {
        Button(action: { markConfidence(level) }) {
            Text(title)
                .font(.jost(.subheadline()))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Confidence Badge
    @ViewBuilder
    private func confidenceBadge(for level: ConfidenceLevel) -> some View {
        let (color, icon, text) = confidenceInfo(for: level)

        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.jost(.caption2()))
            Text(text)
                .font(.jost(.caption2()))
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color))
    }

    private func confidenceInfo(for level: ConfidenceLevel) -> (Color, String, String) {
        switch level {
        case .notSeen:
            return (.gray, "circle", "Not Reviewed")
        case .hard:
            return (.red, "exclamationmark.circle.fill", "Hard")
        case .medium:
            return (.orange, "minus.circle.fill", "Medium")
        case .easy:
            return (.green, "checkmark.circle.fill", "Easy")
        }
    }

    // MARK: - Actions
    private func markConfidence(_ level: ConfidenceLevel) {
        if var session = state.studySession {
            session.flashcards[currentCardIndex].markReviewed(confidence: level)
            state.studySession = session
            state.studyStorage.saveSession(session)
        }

        // Auto-advance to next card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nextCard()
        }
    }

    private func previousCard() {
        if currentCardIndex > 0 {
            withAnimation(.spring()) {
                currentCardIndex -= 1
                isFlipped = false
            }
        }
    }

    private func nextCard() {
        if currentCardIndex < flashcards.count - 1 {
            withAnimation(.spring()) {
                currentCardIndex += 1
                isFlipped = false
            }
        } else {
            // Show completion message
            if let progress = state.studySession?.flashcardProgress {
                state.studyModeMessage = "Flashcards completed! Reviewed: \(progress.reviewed)/\(progress.total)"
            }
        }
    }

    private func generateFlashcards() {
        guard let note = state.currentNote else { return }

        Task {
            do {
                try await state.generateFlashcards(note: note, storageManager: storageManager)
            } catch {
                print("Failed to generate flashcards: \(error)")
            }
        }
    }

    private func addMoreFlashcards() {
        guard let note = state.currentNote else { return }

        Task {
            do {
                try await state.generateFlashcards(note: note, storageManager: storageManager, count: 5)
            } catch {
                print("Failed to add more flashcards: \(error)")
            }
        }
    }

    private func regenerateFlashcards() {
        guard let note = state.currentNote else { return }

        // Clear existing flashcards
        if var session = state.studySession {
            session.flashcards = []
            state.studySession = session
            state.studyStorage.saveSession(session)
        }

        currentCardIndex = 0
        isFlipped = false

        Task {
            do {
                try await state.generateFlashcards(note: note, storageManager: storageManager)
            } catch {
                print("Failed to regenerate flashcards: \(error)")
            }
        }
    }
}
