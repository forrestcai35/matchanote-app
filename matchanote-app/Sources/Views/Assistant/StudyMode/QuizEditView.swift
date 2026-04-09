import SwiftUI

struct QuizEditView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editedQuestions: [QuizQuestion]
    @State private var showingRegenerateAlert = false
    @State private var showingGenerateMore = false
    @State private var isGenerating = false
    @State private var expandedQuestionId: UUID?

    init(questions: [QuizQuestion]) {
        _editedQuestions = State(initialValue: questions)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
                    .ignoresSafeArea()

                if editedQuestions.isEmpty && !isGenerating {
                    emptyState
                } else {
                    questionsList
                }
            }
            .navigationTitle("Edit Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? .matchabrown_dark : .matchabrown_light)
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        // Add Manually button
                        Button(action: addManualQuestion) {
                            Label("Add Manually", systemImage: "plus.circle")
                                .font(.jost(.subheadline()))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGenerating)

                        Spacer()

                        // Generate More button
                        Button(action: generateMore) {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Generate More", systemImage: "sparkles")
                                    .font(.jost(.subheadline()))
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .disabled(isGenerating)

                        // Regenerate All button
                        Button(action: { showingRegenerateAlert = true }) {
                            Label("Regenerate All", systemImage: "arrow.clockwise")
                                .font(.jost(.subheadline()))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .disabled(isGenerating)
                    }
                }
            }
            .alert("Regenerate All Questions?", isPresented: $showingRegenerateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate", role: .destructive) {
                    regenerateAll()
                }
            } message: {
                Text("This will delete all current questions and generate new ones. This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Questions Yet")
                .font(.jost(.title3()))
                .fontWeight(.semibold)

            Text("Add questions manually or generate them with AI")
                .font(.jost(.subheadline()))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Questions List
    private var questionsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(editedQuestions.enumerated()), id: \.element.id) { index, question in
                    QuizQuestionEditRow(
                        question: binding(for: question),
                        isExpanded: Binding(
                            get: { expandedQuestionId == question.id },
                            set: { isExpanded in
                                expandedQuestionId = isExpanded ? question.id : nil
                            }
                        ),
                        onDelete: { deleteQuestion(at: index) },
                        onChange: { saveChanges() }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .id(question.id)
                }
                .onMove { from, to in
                    editedQuestions.move(fromOffsets: from, toOffset: to)
                    saveChanges()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: expandedQuestionId) { _, newId in
                if let newId = newId {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    // MARK: - Actions
    private func binding(for question: QuizQuestion) -> Binding<QuizQuestion> {
        guard let index = editedQuestions.firstIndex(where: { $0.id == question.id }) else {
            fatalError("Question not found")
        }
        return $editedQuestions[index]
    }

    private func addManualQuestion() {
        let newQuestion = QuizQuestion(
            question: "",
            type: .multipleChoice,
            options: ["", "", "", ""],
            correctAnswer: "",
            explanation: nil
        )
        editedQuestions.append(newQuestion)
        expandedQuestionId = newQuestion.id
        saveChanges()
    }

    private func deleteQuestion(at index: Int) {
        editedQuestions.remove(at: index)
        saveChanges()
    }

    private func generateMore() {
        guard let note = state.currentNote else { return }

        isGenerating = true
        Task {
            do {
                // Temporarily store current questions
                let currentQuestions = editedQuestions

                // Generate new questions (5 at a time)
                try await state.generateQuizQuestions(note: note, storageManager: storageManager, count: 5)

                // Append new questions to current list
                if let session = state.studySession {
                    let newQuestions = session.quizQuestions.filter { newQ in
                        !currentQuestions.contains(where: { $0.id == newQ.id })
                    }
                    await MainActor.run {
                        editedQuestions = currentQuestions + newQuestions
                        isGenerating = false
                        saveChanges()
                    }
                }
            } catch {
                print("Failed to generate more questions: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }

    private func regenerateAll() {
        guard let note = state.currentNote else { return }

        isGenerating = true
        editedQuestions.removeAll()

        Task {
            do {
                try await state.generateQuizQuestions(note: note, storageManager: storageManager, count: 10, regenerate: true)

                if let session = state.studySession {
                    await MainActor.run {
                        editedQuestions = session.quizQuestions
                        isGenerating = false
                        saveChanges()
                    }
                }
            } catch {
                print("Failed to regenerate questions: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }

    private func saveChanges() {
        // Validate questions
        let validQuestions = editedQuestions.filter { question in
            !question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Update session
        if var session = state.studySession {
            session.quizQuestions = validQuestions
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }
}

// MARK: - Quiz Question Edit Row
struct QuizQuestionEditRow: View {
    @Binding var question: QuizQuestion
    @Binding var isExpanded: Bool
    let onDelete: () -> Void
    let onChange: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isExpanded {
                // Collapsed state - just show preview
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.question.isEmpty ? "Empty question" : question.question)
                            .font(.jost(.body()))
                            .fontWeight(.medium)
                            .foregroundColor(question.question.isEmpty ? .secondary : .primary)
                            .lineLimit(1)

                        Text(question.correctAnswer.isEmpty ? "No answer" : question.correctAnswer)
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }
            } else {
                // Expanded state - show editors
                VStack(alignment: .leading, spacing: 12) {
                    // Header with delete button
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    // Question text field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                        TextField("Enter question", text: Binding(
                            get: { question.question },
                            set: { question.question = $0; onChange() }
                        ), axis: .vertical)
                        .font(.jost(.body()))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                        )
                    }

                    Divider()

                // Question Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question Type")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)

                    Picker("Type", selection: Binding(
                        get: { question.type },
                        set: { newType in
                            question.type = newType
                            // Adjust options based on type
                            if newType == .trueFalse {
                                question.options = ["True", "False"]
                            } else if newType == .multipleChoice && question.options.count < 2 {
                                question.options = ["", "", "", ""]
                            } else if newType == .fillInBlank {
                                question.options = []
                            }
                            onChange()
                        }
                    )) {
                        Text("Multiple Choice").tag(QuizQuestionType.multipleChoice)
                        Text("True/False").tag(QuizQuestionType.trueFalse)
                        Text("Fill in the Blank").tag(QuizQuestionType.fillInBlank)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Answer options (only for multiple choice and true/false)
                if question.type != .fillInBlank {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Answer Options")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                    ForEach(0..<question.options.count, id: \.self) { index in
                        HStack(spacing: 8) {
                            // Correct answer indicator
                            Button(action: {
                                question.correctAnswer = question.options[index]
                                onChange()
                            }) {
                                Image(systemName: question.correctAnswer == question.options[index] ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(question.correctAnswer == question.options[index] ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            TextField("Option \(index + 1)", text: Binding(
                                get: { question.options[index] },
                                set: { newValue in
                                    question.options[index] = newValue
                                    onChange()
                                }
                            ), axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                            )

                            if question.options.count > 2 {
                                Button(action: {
                                    question.options.remove(at: index)
                                    onChange()
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                        if question.options.count < 6 && question.type == .multipleChoice {
                            Button(action: {
                                question.options.append("")
                                onChange()
                            }) {
                                Label("Add Option", systemImage: "plus.circle")
                                    .font(.jost(.caption()))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()
                }

                // Correct Answer (for fill in the blank)
                if question.type == .fillInBlank {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Correct Answer")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                        TextField("Enter correct answer", text: Binding(
                            get: { question.correctAnswer },
                            set: { question.correctAnswer = $0; onChange() }
                        ), axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                        )
                    }

                    Divider()
                }

                // Explanation
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explanation (Optional)")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)

                    TextField("Add explanation", text: Binding(
                        get: { question.explanation ?? "" },
                        set: { question.explanation = $0.isEmpty ? nil : $0; onChange() }
                    ), axis: .vertical)
                    .font(.jost(.subheadline()))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                    )
                }

                // Tap to collapse
                HStack {
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }
            }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
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
        )
        .overlay(
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
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
}
