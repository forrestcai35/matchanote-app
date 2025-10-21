import Foundation

// MARK: - Flashcard Confidence Level
enum ConfidenceLevel: String, Codable {
    case notSeen
    case hard
    case medium
    case easy
}

// MARK: - Flashcard Model
struct Flashcard: Identifiable, Codable {
    let id: UUID
    let front: String // Question or term
    let back: String // Answer or definition
    var confidence: ConfidenceLevel
    var lastReviewedAt: Date?
    var reviewCount: Int

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        confidence: ConfidenceLevel = .notSeen,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.confidence = confidence
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }

    // Custom decoding to handle LLM responses that don't include id, confidence, etc.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id with default if missing
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        
        // Decode required fields
        self.front = try container.decode(String.self, forKey: .front)
        self.back = try container.decode(String.self, forKey: .back)
        
        // Decode optional fields with defaults
        self.confidence = (try? container.decode(ConfidenceLevel.self, forKey: .confidence)) ?? .notSeen
        self.lastReviewedAt = try? container.decode(Date.self, forKey: .lastReviewedAt)
        self.reviewCount = (try? container.decode(Int.self, forKey: .reviewCount)) ?? 0
    }

    // Mark as reviewed with confidence level
    mutating func markReviewed(confidence: ConfidenceLevel) {
        self.confidence = confidence
        self.lastReviewedAt = Date()
        self.reviewCount += 1
    }

    // Reset confidence level
    mutating func reset() {
        self.confidence = .notSeen
        self.lastReviewedAt = nil
        self.reviewCount = 0
    }
}
