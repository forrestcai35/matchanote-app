import Foundation

// MARK: - Study Session Model
struct StudySession: Codable {
    let id: UUID
    let noteId: UUID
    var contentHash: String // Hash of note content to detect changes
    var quizQuestions: [QuizQuestion]
    var flashcards: [Flashcard]
    let createdAt: Date
    var lastUpdatedAt: Date

    init(
        id: UUID = UUID(),
        noteId: UUID,
        contentHash: String,
        quizQuestions: [QuizQuestion] = [],
        flashcards: [Flashcard] = [],
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.noteId = noteId
        self.contentHash = contentHash
        self.quizQuestions = quizQuestions
        self.flashcards = flashcards
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    // Check if session is expired (older than 30 days)
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return lastUpdatedAt < thirtyDaysAgo
    }

    // Check if content is stale (content hash doesn't match)
    func isStale(currentHash: String) -> Bool {
        return contentHash != currentHash
    }

    // Update timestamp
    mutating func updateTimestamp() {
        lastUpdatedAt = Date()
    }

    // Add quiz questions
    mutating func addQuizQuestions(_ questions: [QuizQuestion]) {
        quizQuestions.append(contentsOf: questions)
        updateTimestamp()
    }

    // Add flashcards
    mutating func addFlashcards(_ cards: [Flashcard]) {
        flashcards.append(contentsOf: cards)
        updateTimestamp()
    }

    // Reset all quiz answers
    mutating func resetQuiz() {
        for i in 0..<quizQuestions.count {
            quizQuestions[i].reset()
        }
    }

    // Reset all flashcard progress
    mutating func resetFlashcards() {
        for i in 0..<flashcards.count {
            flashcards[i].reset()
        }
    }

    // Get quiz score
    var quizScore: (correct: Int, total: Int) {
        let answered = quizQuestions.filter { $0.userAnswer != nil }
        let correct = answered.filter { $0.isCorrect == true }.count
        return (correct, answered.count)
    }

    // Get flashcard progress
    var flashcardProgress: (reviewed: Int, total: Int) {
        let reviewed = flashcards.filter { $0.confidence != .notSeen }.count
        return (reviewed, flashcards.count)
    }
}
