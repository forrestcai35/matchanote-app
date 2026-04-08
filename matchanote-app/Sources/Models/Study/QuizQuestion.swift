import Foundation

// MARK: - Quiz Question Types
enum QuizQuestionType: String, Codable {
    case multipleChoice
    case trueFalse
    case fillInBlank
}

// MARK: - Quiz Question Model
struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    var question: String
    var type: QuizQuestionType
    var options: [String] // For multiple choice, true/false options
    var correctAnswer: String
    var explanation: String? // Optional explanation for the answer
    var userAnswer: String? // Track user's selected answer

    init(
        id: UUID = UUID(),
        question: String,
        type: QuizQuestionType,
        options: [String],
        correctAnswer: String,
        explanation: String? = nil,
        userAnswer: String? = nil
    ) {
        self.id = id
        self.question = question
        self.type = type
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.userAnswer = userAnswer
    }

    // Custom decoding to handle LLM responses that don't include id or userAnswer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id with default if missing
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        
        // Decode required fields
        self.question = try container.decode(String.self, forKey: .question)
        self.type = try container.decode(QuizQuestionType.self, forKey: .type)
        self.options = try container.decode([String].self, forKey: .options)
        self.correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        
        // Decode optional fields
        self.explanation = try? container.decode(String.self, forKey: .explanation)
        self.userAnswer = try? container.decode(String.self, forKey: .userAnswer)
    }

    // Check if user's answer is correct
    var isCorrect: Bool? {
        guard let userAnswer = userAnswer else { return nil }
        return userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
               correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Reset user's answer
    mutating func reset() {
        userAnswer = nil
    }
}
