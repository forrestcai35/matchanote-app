import SwiftUI

struct StudyModeView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Sub-mode toggle (Quiz / Flashcards)
            StudySubModeToggle(selectedMode: $state.studySubMode)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Content area
            if state.isAnalyzingContent {
                StudyLoadingView(message: "Analyzing note content...")
            } else if !state.canEnableStudyMode {
                // Show message if content is not suitable
                StudyEmptyState(
                    icon: "book.closed",
                    title: "Study Mode Unavailable",
                    message: state.studyModeMessage ?? "Add more educational content to your notes to enable Study Mode",
                    actionTitle: "Analyze Again",
                    action: analyzeContent
                )
            } else if state.isLoading {
                StudyLoadingView(message: state.studySubMode == .quiz ? "Generating quiz questions..." : "Generating flashcards...")
            } else {
                // Show appropriate view based on sub-mode
                switch state.studySubMode {
                case .quiz:
                    QuizView()
                        .transition(.opacity)
                case .flashcards:
                    FlashcardView()
                        .transition(.opacity)
                }
            }
        }
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? -0.05 : 0.05)
        )
        .onAppear {
            if !state.isAnalyzingContent && !state.canEnableStudyMode {
                analyzeContent()
            }
        }
    }

    private func analyzeContent() {
        guard let note = state.currentNote,
              let saveCallback = state.saveCanvasDataCallback else { return }

        Task {
            await state.analyzeNoteForStudy(
                note: note,
                storageManager: storageManager,
                saveCanvasCallback: saveCallback
            )

            // Auto-generate content if suitable and cache is empty
            if state.canEnableStudyMode {
                await MainActor.run {
                    if let session = state.studySession {
                        // Generate quiz if empty
                        if session.quizQuestions.isEmpty && state.studySubMode == .quiz {
                            Task {
                                do {
                                    try await state.generateQuizQuestions(note: note, storageManager: storageManager)
                                } catch {
                                    print("Failed to auto-generate quiz: \(error)")
                                }
                            }
                        }

                        // Generate flashcards if empty
                        if session.flashcards.isEmpty && state.studySubMode == .flashcards {
                            Task {
                                do {
                                    try await state.generateFlashcards(note: note, storageManager: storageManager)
                                } catch {
                                    print("Failed to auto-generate flashcards: \(error)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
