import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showingExplanation = false
    @State private var fillInBlankText: String = ""
    @State private var showingEditSheet = false
    @State private var isQuizCompleted = false
    @State private var isReviewMode = false
    @State private var showUnansweredAlert = false
    @Environment(\.colorScheme) private var colorScheme

    var questions: [QuizQuestion] {
        state.studySession?.quizQuestions ?? []
    }

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var allQuestionsAnswered: Bool {
        questions.allSatisfy { $0.userAnswer != nil }
    }

    var backgroundColor: Color {
        colorScheme == .dark
            ? Color.matchabackground_dark
            : Color.matchabackground_light
    }

    // Load saved index on appear
    private func loadSavedIndex() {
        if let session = state.studySession {
            currentQuestionIndex = min(session.currentQuizIndex, max(0, questions.count - 1))
            loadQuestionState()
        }
    }

    // Save current index to session
    private func saveCurrentIndex() {
        if var session = state.studySession {
            session.currentQuizIndex = currentQuestionIndex
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isGeneratingQuiz && questions.isEmpty {
                // Show loading instead of empty state when generating
                StudyLoadingView(message: "Generating quiz questions...")
            } else if state.quizGenerationError && questions.isEmpty {
                // Show error state when generation failed
                StudyEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Quiz Generation Failed",
                    message: "There was an error generating quiz questions. Please try again.",
                    actionTitle: "Try Again",
                    action: generateQuiz
                )
            } else if questions.isEmpty {
                // Only show empty state if not loading and truly empty
                StudyEmptyState(
                    icon: "questionmark.circle",
                    title: "No Quiz Questions",
                    message: "Generate quiz questions from your notes to start studying",
                    actionTitle: "Generate Quiz",
                    action: generateQuiz
                )
            } else if isQuizCompleted {
                // Show completion screen
                quizCompletionScreen
            } else {
                // Header with progress - Responsive layout
                VStack(spacing: 0) {
                    // Show "Back to Results" button when in review mode
                    if isReviewMode {
                        HStack {
                            Button(action: {
                                isReviewMode = false
                                isQuizCompleted = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.jost(.caption()))
                                    Text("Back to Results")
                                        .font(.jost(.subheadline()))
                                }
                                .foregroundColor(.matchadark_light)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.matchadark_light.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }

                    ResponsiveQuizHeader(
                        current: currentQuestionIndex + 1,
                        total: questions.count,
                        score: state.studySession?.quizScore,
                        onEdit: { showingEditSheet = true }
                    )
                    .padding()
                }

                // Question area
                ZStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let question = currentQuestion {
                            // Question text
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Question \(currentQuestionIndex + 1)")
                                    .font(.jost(.caption()))
                                    .foregroundColor(.secondary)

                                Text(question.question)
                                    .font(.jost(.title3()))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            colorScheme == .dark
                                                ? LinearGradient(
                                                    colors: [
                                                        Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.85),
                                                        Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.85)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.98),
                                                        Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.95)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )

                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: colorScheme == .dark
                                                    ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                                                    : [Color.white.opacity(0.8), Color.gray.opacity(0.12)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 10, x: 0, y: 3)
                            )

                            // Answer options - Different UI based on question type
                            if question.type == .fillInBlank {
                                fillInBlankInput(for: question)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(question.options, id: \.self) { option in
                                        answerOption(option, for: question)
                                    }
                                }
                            }

                            // Show explanation if answer selected AND (preference is on OR in review mode)
                            if showingExplanation,
                               (preferencesManager.quizShowAnswerImmediately || isReviewMode),
                               let explanation = question.explanation {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.jost(.caption()))
                                            .foregroundColor(.yellow)
                                        Text("Explanation")
                                            .font(.jost(.caption()))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(explanation)
                                        .font(.jost(.subheadline()))
                                        .foregroundColor(.primary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.yellow.opacity(colorScheme == .dark ? 0.15 : 0.12),
                                                        Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )

                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: Color.yellow.opacity(0.15), radius: 8, x: 0, y: 2)
                                )
                            }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        loadSavedIndex()
                    }
                    .onChange(of: currentQuestionIndex) { _, _ in
                        loadQuestionState()
                        saveCurrentIndex()
                    }

                    // Top fade effect
                    VStack {
                        backgroundColor
                            .brightness(colorScheme == .dark ? -0.05 : 0.05)
                            .mask(
                                LinearGradient(
                                    colors: [Color.white, Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 20)
                            .allowsHitTesting(false)

                        Spacer()
                    }

                    // Bottom fade effect
                    VStack {
                        Spacer()

                        backgroundColor
                            .brightness(colorScheme == .dark ? -0.05 : 0.05)
                            .mask(
                                LinearGradient(
                                    colors: [Color.clear, Color.white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 30)
                            .allowsHitTesting(false)
                    }
                }

                // Navigation buttons
                HStack(spacing: 12) {
                    Button(action: previousQuestion) {
                        Image(systemName: "chevron.left")
                            .font(.jost(.caption()))
                            .foregroundColor(currentQuestionIndex > 0 ? .matchadark_light : .gray)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .disabled(currentQuestionIndex <= 0)
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Show different button on last question
                    if currentQuestionIndex == questions.count - 1 {
                        Button(action: finishQuiz) {
                            Text("Finish Quiz")
                                .font(.jost(.subheadline()))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.matchadark_light)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: nextQuestion) {
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(
            backgroundColor
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
        .onChange(of: questions.count) { oldCount, newCount in
            // Reset index if it's now out of bounds
            if currentQuestionIndex >= newCount && newCount > 0 {
                currentQuestionIndex = newCount - 1
                selectedAnswer = nil
                showingExplanation = false
            } else if newCount == 0 {
                currentQuestionIndex = 0
                selectedAnswer = nil
                showingExplanation = false
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            QuizEditView(questions: questions)
                .environmentObject(state)
                .environmentObject(storageManager)
        }
        .alert("Unanswered Question", isPresented: $showUnansweredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please answer the current question before finishing the quiz.")
        }
    }

    // MARK: - Answer Option View
    @ViewBuilder
    private func answerOption(_ option: String, for question: QuizQuestion) -> some View {
        let isSelected = selectedAnswer == option
        let isCorrect = option == question.correctAnswer
        let showFeedback = selectedAnswer != nil && (preferencesManager.quizShowAnswerImmediately || isReviewMode)

        Button(action: { selectAnswer(option) }) {
            HStack(alignment: .top, spacing: 12) {
                Text(option)
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Show feedback icon on selected answer or correct answer (when feedback should be shown)
                if showFeedback && (isSelected || isCorrect) {
                    HStack(spacing: 4) {
                        if !isCorrect {
                            Text("You Chose")
                                .font(.jost(.caption()))
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isCorrect ? .green : .red)
                            .font(.jost(.body()))
                    }
                }
            }
            .padding()
            .frame(minHeight: 44)
            .background(
                ZStack {
                    // Glassy background
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            showFeedback && (isSelected || isCorrect)
                                ? (isCorrect
                                    ? LinearGradient(
                                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.red.opacity(0.15), Color.red.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                : (isSelected
                                    ? LinearGradient(
                                        colors: [Color.matchadark_light.opacity(0.15), Color.matchadark_light.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.12), Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                        )

                    // Glassy border
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            showFeedback && (isSelected || isCorrect)
                                ? (isCorrect
                                    ? LinearGradient(
                                        colors: [Color.green.opacity(0.6), Color.green.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.red.opacity(0.6), Color.red.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                : (isSelected
                                    ? LinearGradient(
                                        colors: [Color.matchadark_light.opacity(0.5), Color.matchadark_light.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )),
                            lineWidth: (isSelected || (showFeedback && isCorrect)) ? 1.5 : 1
                        )
                }
                .shadow(
                    color: (showFeedback && (isSelected || isCorrect)
                        ? (isCorrect ? Color.green : Color.red)
                        : Color.black
                    ).opacity(0.1),
                    radius: (isSelected || (showFeedback && isCorrect)) ? 8 : 4,
                    x: 0,
                    y: 2
                )
            )
        }
        .disabled(showingExplanation)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Fill in the Blank Input
    @ViewBuilder
    private func fillInBlankInput(for question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Answer")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                TextField("Type your answer...", text: $fillInBlankText)
                    .textFieldStyle(.plain)
                      .font(.jost(.callout(14)))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    colorScheme == .dark
                                        ? Color(white: 0.15).opacity(0.5)
                                        : Color.white.opacity(0.8)
                                )
                            
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    showingExplanation && (preferencesManager.quizShowAnswerImmediately || isReviewMode)
                                        ? (selectedAnswer?.lowercased() == question.correctAnswer.lowercased()
                                            ? Color.green.opacity(0.6)
                                            : Color.red.opacity(0.6))
                                        : Color.gray.opacity(0.3),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .disabled(showingExplanation)
                
                if !showingExplanation {
                    Button(action: submitFillInBlank) {
                        Text("Submit")
                            .font(.jost(.subheadline()))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        fillInBlankText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? LinearGradient(
                                                colors: [Color.gray, Color.gray],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            : LinearGradient(
                                                colors: [Color.matchadark_light, Color.matchadark_light.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                    )
                            )
                    }
                    .disabled(fillInBlankText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Show feedback after submission (only if preference enabled OR in review mode)
            if showingExplanation,
               (preferencesManager.quizShowAnswerImmediately || isReviewMode),
               let userAnswer = selectedAnswer {
                let isCorrect = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
                               question.correctAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                        .font(.jost(.title3()))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCorrect ? "Correct!" : "Incorrect")
                            .font(.jost(.subheadline()))
                            .fontWeight(.semibold)
                            .foregroundColor(isCorrect ? .green : .red)

                        if !isCorrect {
                            Text("Correct answer: \(question.correctAnswer)")
                                .font(.jost(.caption()))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isCorrect
                                ? Color.green.opacity(0.1)
                                : Color.red.opacity(0.1)
                        )
                )
            }
        }
    }

    // MARK: - Actions
    private func selectAnswer(_ answer: String) {
        guard currentQuestionIndex < questions.count else { return }
        selectedAnswer = answer
        showingExplanation = true

        // Update question in session
        if var session = state.studySession {
            session.quizQuestions[currentQuestionIndex].userAnswer = answer
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }
    
    private func submitFillInBlank() {
        let trimmedAnswer = fillInBlankText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else { return }
        
        selectAnswer(trimmedAnswer)
    }

    private func loadQuestionState() {
        if currentQuestionIndex < questions.count {
            let question = questions[currentQuestionIndex]
            selectedAnswer = question.userAnswer
            showingExplanation = selectedAnswer != nil
            
            // Load fill-in-blank text if it's that type
            if question.type == .fillInBlank {
                fillInBlankText = question.userAnswer ?? ""
            } else {
                fillInBlankText = ""
            }
        }
    }
    
    private func previousQuestion() {
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
            // State will be loaded by onChange
        }
    }

    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            // State will be loaded by onChange
        }
    }

    private func finishQuiz() {
        // Check if current question is answered
        guard let currentQuestion = currentQuestion else { return }

        if currentQuestion.userAnswer == nil {
            showUnansweredAlert = true
            return
        }

        // If showing answers immediately, go to completion screen
        if preferencesManager.quizShowAnswerImmediately {
            isQuizCompleted = true
        } else if allQuestionsAnswered && !isReviewMode {
            // If not showing answers and all answered, show completion
            isQuizCompleted = true
        }
    }

    private func generateQuiz() {
        guard let note = state.currentNote else { return }

        Task {
            do {
                try await state.generateQuizQuestions(note: note, storageManager: storageManager)
            } catch {
                print("Failed to generate quiz: \(error)")
            }
        }
    }

    private func restartQuiz() {
        // Reset all user answers
        if var session = state.studySession {
            for index in session.quizQuestions.indices {
                session.quizQuestions[index].userAnswer = nil
            }
            state.studySession = session
            state.studyStorage.saveSession(session)
        }

        // Reset state
        currentQuestionIndex = 0
        selectedAnswer = nil
        showingExplanation = false
        fillInBlankText = ""
        isQuizCompleted = false
        isReviewMode = false
    }

    private func reviewAnswers() {
        isReviewMode = true
        isQuizCompleted = false
        currentQuestionIndex = 0
        loadQuestionState()
    }

    // MARK: - Completion Screen
    private var quizCompletionScreen: some View {
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
                    Text("Quiz Completed!")
                        .font(.jost(.title()))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let score = state.studySession?.quizScore {
                        Text("\(score.correct) out of \(score.total) correct")
                            .font(.jost(.title3()))
                            .foregroundColor(.secondary)

                        let percentage = score.total > 0 ? Int((Double(score.correct) / Double(score.total)) * 100) : 0
                        Text("\(percentage)%")
                            .font(.jost(.largeTitle()))
                            .fontWeight(.bold)
                            .foregroundColor(.matchadark_light)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Review Answers button
                    Button(action: reviewAnswers) {
                        Text("Review Answers")
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

                    // Restart Quiz button
                    Button(action: restartQuiz) {
                        Text("Restart Quiz")
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
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(
                backgroundColor
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
            )
        }
    }
}
