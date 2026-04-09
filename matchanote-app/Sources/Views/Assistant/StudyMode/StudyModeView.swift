import SwiftUI

struct StudyModeView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var lastNoteId: UUID? = nil

    // Helper computed property to watch for note ID changes
    private var currentNoteId: UUID? {
        state.currentNote?.id
    }

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
            } else {
                // Show appropriate view based on sub-mode (they handle their own loading states)
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
            // Store the initial note ID
            lastNoteId = currentNoteId
        }
        .onChange(of: currentNoteId) { oldNoteId, newNoteId in
            // Check if the note ID actually changed
            guard newNoteId != lastNoteId else { return }

            // Update tracked note ID
            lastNoteId = newNoteId

            guard let noteId = newNoteId else {
                // Clear study state when no note is selected
                state.studySession = nil
                state.canEnableStudyMode = false
                state.studyModeMessage = nil
                return
            }

            // Load study session for the new note
            print("📚 Study Mode: Note changed, loading session for note \(noteId)")

            // Try to load existing session (even if hash is stale)
            if let existingSession = state.studyStorage.loadSession(for: noteId),
               !existingSession.isExpired {
                // Session exists and not expired - load it immediately
                print("✅ Study Mode: Loaded session with \(existingSession.quizQuestions.count) quiz questions and \(existingSession.flashcards.count) flashcards")

                // Update session hash if stale (preserves quizzes/flashcards)
                if let currentNote = state.currentNote {
                    let currentHash = StudyStorageManager.generateContentHash(from: currentNote)
                    if existingSession.isStale(currentHash: currentHash) {
                        var updatedSession = existingSession
                        updatedSession.contentHash = currentHash
                        updatedSession.updateTimestamp()
                        state.studyStorage.saveSession(updatedSession)
                        state.studySession = updatedSession
                    } else {
                        state.studySession = existingSession
                    }
                }

                state.canEnableStudyMode = true
                state.studyModeMessage = nil
            } else {
                // No session exists or expired, need to analyze
                print("🔍 Study Mode: No valid session, analyzing note content")
                state.studySession = nil
                state.canEnableStudyMode = false
                state.studyModeMessage = nil
                analyzeContent()
            }
        }
    }

    private func analyzeContent() {
        guard let note = state.currentNote,
              let saveCallback = state.saveCanvasDataCallback else { return }

        // Check if we already have a valid session - if so, don't re-analyze
        if let existingSession = state.studyStorage.loadSession(for: note.id),
           !existingSession.isExpired,
           (!existingSession.quizQuestions.isEmpty || !existingSession.flashcards.isEmpty) {
            print("⏭️  Study Mode: Skipping analysis - valid session with \(existingSession.quizQuestions.count) quizzes and \(existingSession.flashcards.count) flashcards already exists")

            // Update hash if stale and load the session
            let currentHash = StudyStorageManager.generateContentHash(from: note)
            if existingSession.isStale(currentHash: currentHash) {
                var updatedSession = existingSession
                updatedSession.contentHash = currentHash
                updatedSession.updateTimestamp()
                state.studyStorage.saveSession(updatedSession)
                state.studySession = updatedSession
            } else {
                state.studySession = existingSession
            }

            state.canEnableStudyMode = true
            state.studyModeMessage = nil
            return
        }

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
                        // Generate quiz if empty (always generate on first open)
                        if session.quizQuestions.isEmpty {
                            // Set loading state immediately to prevent flash
                            state.isGeneratingQuiz = true
                            state.quizGenerationError = false
                            Task {
                                do {
                                    try await state.generateQuizQuestions(note: note, storageManager: storageManager)
                                } catch {
                                    print("Failed to auto-generate quiz: \(error)")
                                }
                            }
                        }

                        // Generate flashcards if empty (always generate on first open)
                        if session.flashcards.isEmpty {
                            // Set loading state immediately to prevent flash
                            state.isGeneratingFlashcards = true
                            state.flashcardGenerationError = false
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
