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
    var currentQuizIndex: Int
    var currentFlashcardIndex: Int

    init(
        id: UUID = UUID(),
        noteId: UUID,
        contentHash: String,
        quizQuestions: [QuizQuestion] = [],
        flashcards: [Flashcard] = [],
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        currentQuizIndex: Int = 0,
        currentFlashcardIndex: Int = 0
    ) {
        self.id = id
        self.noteId = noteId
        self.contentHash = contentHash
        self.quizQuestions = quizQuestions
        self.flashcards = flashcards
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.currentQuizIndex = currentQuizIndex
        self.currentFlashcardIndex = currentFlashcardIndex
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

    // Set quiz questions (replaces existing)
    mutating func setQuizQuestions(_ questions: [QuizQuestion]) {
        quizQuestions = questions
        currentQuizIndex = 0
        updateTimestamp()
    }

    // Add flashcards
    mutating func addFlashcards(_ cards: [Flashcard]) {
        flashcards.append(contentsOf: cards)
        updateTimestamp()
    }

    // Set flashcards (replaces existing)
    mutating func setFlashcards(_ cards: [Flashcard]) {
        flashcards = cards
        currentFlashcardIndex = 0
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

    // Get flashcard progress (based on favorites)
    var flashcardProgress: (favorites: Int, total: Int) {
        let favorites = flashcards.filter { $0.isFavorite }.count
        return (favorites, flashcards.count)
    }
}
