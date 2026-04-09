import Foundation

// MARK: - Flashcard Model
struct Flashcard: Identifiable, Codable {
    let id: UUID
    var front: String // Question or term
    var back: String // Answer or definition
    var isFavorite: Bool
    var lastReviewedAt: Date?
    var reviewCount: Int

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        isFavorite: Bool = false,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.isFavorite = isFavorite
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }

    // Custom decoding to handle LLM responses that don't include id, isFavorite, etc.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode id with default if missing
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()

        // Decode required fields
        self.front = try container.decode(String.self, forKey: .front)
        self.back = try container.decode(String.self, forKey: .back)

        // Decode optional fields with defaults
        self.isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
        self.lastReviewedAt = try? container.decode(Date.self, forKey: .lastReviewedAt)
        self.reviewCount = (try? container.decode(Int.self, forKey: .reviewCount)) ?? 0
    }

    // Toggle favorite status
    mutating func toggleFavorite() {
        self.isFavorite.toggle()
        self.lastReviewedAt = Date()
    }

    // Mark as reviewed
    mutating func markReviewed() {
        self.lastReviewedAt = Date()
        self.reviewCount += 1
    }

    // Reset review data
    mutating func reset() {
        self.isFavorite = false
        self.lastReviewedAt = nil
        self.reviewCount = 0
    }
}
