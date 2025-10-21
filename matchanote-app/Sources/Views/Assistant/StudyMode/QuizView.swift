import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showingExplanation = false
    @State private var fillInBlankText: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var questions: [QuizQuestion] {
        state.studySession?.quizQuestions ?? []
    }

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                StudyEmptyState(
                    icon: "questionmark.circle",
                    title: "No Quiz Questions",
                    message: "Generate quiz questions from your notes to start studying",
                    actionTitle: "Generate Quiz",
                    action: generateQuiz
                )
            } else {
                // Header with progress - Responsive layout
                ResponsiveQuizHeader(
                    current: currentQuestionIndex + 1,
                    total: questions.count,
                    score: state.studySession?.quizScore,
                    onAddMore: addMoreQuestions,
                    onRegenerate: regenerateQuiz
                )
                .padding()

                // Question area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let question = currentQuestion {
                            // Question text
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Question \(currentQuestionIndex + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(question.question)
                                    .font(.title3)
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
                                                        Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.9),
                                                        Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.9)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.95),
                                                        Color(red: 0.98, green: 0.98, blue: 1.0).opacity(0.95)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )
                                    
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: colorScheme == .dark
                                                    ? [Color.white.opacity(0.1), Color.white.opacity(0.05)]
                                                    : [Color.white.opacity(0.7), Color.gray.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, x: 0, y: 4)
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

                            // Show explanation if answer selected
                            if showingExplanation, let explanation = question.explanation {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Text("Explanation")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(explanation)
                                        .font(.subheadline)
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
                    loadQuestionState()
                }
                .onChange(of: currentQuestionIndex) { _, _ in
                    loadQuestionState()
                }

                // Navigation buttons
                HStack(spacing: 12) {
                    Button(action: previousQuestion) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
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

                    Button(action: nextQuestion) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
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

    // MARK: - Answer Option View
    @ViewBuilder
    private func answerOption(_ option: String, for question: QuizQuestion) -> some View {
        let isSelected = selectedAnswer == option
        let isCorrect = option == question.correctAnswer
        let showFeedback = selectedAnswer != nil

        Button(action: { selectAnswer(option) }) {
            HStack(alignment: .top, spacing: 12) {
                Text(option)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showFeedback && isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                        .font(.body)
                }
            }
            .padding()
            .frame(minHeight: 44)
            .background(
                ZStack {
                    // Glassy background
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            showFeedback && isSelected
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
                            showFeedback && isSelected
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
                            lineWidth: isSelected || (showFeedback && isSelected) ? 1.5 : 1
                        )
                }
                .shadow(
                    color: (showFeedback && isSelected 
                        ? (isCorrect ? Color.green : Color.red) 
                        : Color.black
                    ).opacity(0.1),
                    radius: isSelected ? 8 : 4,
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
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                TextField("Type your answer...", text: $fillInBlankText)
                    .textFieldStyle(.plain)
                    .font(.body)
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
                                    showingExplanation
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
                            .font(.subheadline)
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
            
            // Show feedback after submission
            if showingExplanation, let userAnswer = selectedAnswer {
                let isCorrect = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                               question.correctAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCorrect ? "Correct!" : "Incorrect")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isCorrect ? .green : .red)
                        
                        if !isCorrect {
                            Text("Correct answer: \(question.correctAnswer)")
                                .font(.caption)
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
        } else {
            // Show final score
            if let score = state.studySession?.quizScore {
                state.studyModeMessage = "Quiz completed! Score: \(score.correct)/\(score.total)"
            }
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

    private func addMoreQuestions() {
        guard let note = state.currentNote else { return }

        Task {
            do {
                try await state.generateQuizQuestions(note: note, storageManager: storageManager, count: 5)
            } catch {
                print("Failed to add more questions: \(error)")
            }
        }
    }

    private func regenerateQuiz() {
        guard let note = state.currentNote else { return }

        // Clear existing questions
        if var session = state.studySession {
            session.quizQuestions = []
            state.studySession = session
            state.studyStorage.saveSession(session)
        }

        currentQuestionIndex = 0
        selectedAnswer = nil
        showingExplanation = false

        Task {
            do {
                try await state.generateQuizQuestions(note: note, storageManager: storageManager)
            } catch {
                print("Failed to regenerate quiz: \(error)")
            }
        }
    }
}
