import SwiftUI

struct FlashcardView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @State private var currentCardIndex = 0
    @State private var isFlipped = false
    @State private var showingEditSheet = false
    @State private var isFlashcardsCompleted = false
    @State private var isReviewingFavorites = false
    @Environment(\.colorScheme) private var colorScheme

    var flashcards: [Flashcard] {
        let allFlashcards = state.studySession?.flashcards ?? []
        if isReviewingFavorites {
            return allFlashcards.filter { $0.isFavorite }
        }
        return allFlashcards
    }

    var currentCard: Flashcard? {
        guard currentCardIndex < flashcards.count else { return nil }
        return flashcards[currentCardIndex]
    }

    var hasFavorites: Bool {
        state.studySession?.flashcards.contains(where: { $0.isFavorite }) ?? false
    }

    // Load saved index on appear
    private func loadSavedIndex() {
        if let session = state.studySession {
            currentCardIndex = min(session.currentFlashcardIndex, max(0, flashcards.count - 1))
        }
    }

    // Save current index to session
    private func saveCurrentIndex() {
        if var session = state.studySession {
            session.currentFlashcardIndex = currentCardIndex
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isGeneratingFlashcards && flashcards.isEmpty {
                // Show loading instead of empty state when generating
                StudyLoadingView(message: "Generating flashcards...")
            } else if state.flashcardGenerationError && flashcards.isEmpty {
                // Show error state when generation failed
                StudyEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Flashcard Generation Failed",
                    message: "There was an error generating flashcards. Please try again.",
                    actionTitle: "Try Again",
                    action: generateFlashcards
                )
            } else if flashcards.isEmpty && !isReviewingFavorites {
                // Only show empty state if not loading and truly empty
                StudyEmptyState(
                    icon: "rectangle.stack",
                    title: "No Flashcards",
                    message: "Generate flashcards from your notes to start studying",
                    actionTitle: "Generate Flashcards",
                    action: generateFlashcards
                )
            } else if flashcards.isEmpty && isReviewingFavorites {
                // Show empty state for no favorites
                StudyEmptyState(
                    icon: "star",
                    title: "No Favorite Flashcards",
                    message: "Mark flashcards as favorites to review them separately",
                    actionTitle: "Review All",
                    action: reviewAll
                )
            } else if isFlashcardsCompleted {
                // Show completion screen
                flashcardCompletionScreen
            } else {
                // Header with progress - Responsive layout
                ResponsiveFlashcardHeader(
                    current: currentCardIndex + 1,
                    total: flashcards.count,
                    progress: state.studySession?.flashcardProgress,
                    onEdit: { showingEditSheet = true }
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
                .onAppear {
                    loadSavedIndex()
                }

                // Action buttons
                HStack(spacing: 16) {
                    // Favorite button
                    Button(action: toggleFavorite) {
                        HStack(spacing: 4) {
                            Image(systemName: currentCard?.isFavorite == true ? "star.fill" : "star")
                                .font(.jost(.body()))
                            Text(currentCard?.isFavorite == true ? "Favorited" : "Favorite")
                                .font(.jost(.caption()))
                        }
                        .foregroundColor(currentCard?.isFavorite == true ? .yellow : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(currentCard == nil)
                }
                .padding(.bottom, 8)

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
        .onChange(of: flashcards.count) { oldCount, newCount in
            // Reset index if it's now out of bounds
            if currentCardIndex >= newCount && newCount > 0 {
                currentCardIndex = newCount - 1
                isFlipped = false
            } else if newCount == 0 {
                currentCardIndex = 0
                isFlipped = false
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            FlashcardEditView(flashcards: flashcards)
                .environmentObject(state)
                .environmentObject(storageManager)
        }
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

                ZStack {
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

                    // Top fade effect
                    VStack {
                        LinearGradient(
                            colors: [
                                colorScheme == .dark
                                    ? Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88)
                                    : Color.white.opacity(0.98),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                        Spacer()
                    }

                    // Bottom fade effect
                    VStack {
                        Spacer()

                        LinearGradient(
                            colors: [
                                Color.clear,
                                colorScheme == .dark
                                    ? Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.88)
                                    : Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 30)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .background(
                ZStack {
                    // Glassy background with gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            colorScheme == .dark
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88),
                                        Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.98),
                                        Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.96)
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
                                    ? [Color.white.opacity(0.1), Color.white.opacity(0.04)]
                                    : [Color.white.opacity(0.85), Color.gray.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 16, x: 0, y: 6)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06), radius: 6, x: 0, y: 3)
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

                ZStack {
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

                            // Show favorite badge if favorited
                            if card.isFavorite {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.jost(.caption2()))
                                    Text("Favorite")
                                        .font(.jost(.caption2()))
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.yellow))
                            }

                            Spacer()
                        }
                        .frame(minHeight: 0)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Top fade effect
                    VStack {
                        LinearGradient(
                            colors: [
                                colorScheme == .dark
                                    ? Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88)
                                    : Color.white.opacity(0.98),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                        Spacer()
                    }

                    // Bottom fade effect
                    VStack {
                        Spacer()

                        LinearGradient(
                            colors: [
                                Color.clear,
                                colorScheme == .dark
                                    ? Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.88)
                                    : Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 30)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .background(
                ZStack {
                    // Glassy background with gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            colorScheme == .dark
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88),
                                        Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.98),
                                        Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.96)
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
                                    ? [Color.white.opacity(0.1), Color.white.opacity(0.04)]
                                    : [Color.white.opacity(0.85), Color.gray.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 16, x: 0, y: 6)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.06), radius: 6, x: 0, y: 3)
            )
            .opacity(isFlipped ? 0 : 1)
        }
    }

    // MARK: - Actions
    private func toggleFavorite() {
        guard currentCardIndex < flashcards.count else { return }
        if var session = state.studySession {
            session.flashcards[currentCardIndex].toggleFavorite()
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }

    private func previousCard() {
        if currentCardIndex > 0 {
            withAnimation(.spring()) {
                currentCardIndex -= 1
                isFlipped = false
            }
            saveCurrentIndex()
        }
    }

    private func nextCard() {
        if currentCardIndex < flashcards.count - 1 {
            withAnimation(.spring()) {
                currentCardIndex += 1
                isFlipped = false
            }
            saveCurrentIndex()
        } else {
            // Show completion screen
            isFlashcardsCompleted = true
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

    private func reviewAll() {
        currentCardIndex = 0
        isFlipped = false
        isFlashcardsCompleted = false
        isReviewingFavorites = false
    }

    private func reviewFavorites() {
        currentCardIndex = 0
        isFlipped = false
        isFlashcardsCompleted = false
        isReviewingFavorites = true
    }

    // MARK: - Completion Screen
    private var flashcardCompletionScreen: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer()

                // Completion icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.matchadark_light.opacity(0.2), Color.matchadark_light.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.matchadark_light)
                }

                // Completion message
                VStack(spacing: 8) {
                    Text(isReviewingFavorites ? "Favorites Reviewed!" : "Done Reviewing!")
                        .font(.jost(.title()))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let progress = state.studySession?.flashcardProgress {
                        Text("\(progress.total) flashcards reviewed")
                            .font(.jost(.title3()))
                            .foregroundColor(.secondary)

                        if progress.favorites > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.jost(.body()))
                                Text("\(progress.favorites) favorites")
                                    .font(.jost(.body()))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Review All button
                    Button(action: reviewAll) {
                        Text("Review All")
                            .font(.jost(.body()))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.matchadark_light, Color.matchadark_light.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.matchadark_light.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Review Starred button (only if there are favorites and not already reviewing them)
                    if hasFavorites && !isReviewingFavorites {
                        Button(action: reviewFavorites) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Review Starred")
                            }
                            .font(.jost(.body()))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
            )
        }
    }
}
