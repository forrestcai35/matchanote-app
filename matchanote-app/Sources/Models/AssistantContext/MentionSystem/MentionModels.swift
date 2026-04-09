import Foundation

// MARK: - Mention Types

/// Types of items that can be mentioned in the assistant
enum MentionType {
    case note
    case folder
    case subject
}

// MARK: - Mention Model

/// Represents a mentioned item in the text
struct Mention: Identifiable, Equatable, Codable {
    let id: String
    let type: MentionType
    let displayName: String

    /// The text representation of the mention (e.g., "@Note Name")
    var mentionText: String {
        "@\(displayName)"
    }

    init(id: String, type: MentionType, displayName: String) {
        self.id = id
        self.type = type
        self.displayName = displayName
    }
}

// MARK: - Codable Support for MentionType

extension MentionType: Codable {
    enum CodingKeys: String, CodingKey {
        case note, folder, subject
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "note": self = .note
        case "folder": self = .folder
        case "subject": self = .subject
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid MentionType")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .note: try container.encode("note")
        case .folder: try container.encode("folder")
        case .subject: try container.encode("subject")
        }
    }
}

// MARK: - Mention Suggestion

/// Represents a suggestion shown in the autocomplete dropdown
struct MentionSuggestion: Identifiable {
    let id: String
    let mention: Mention
    let subtitle: String?
    let icon: String

    init(mention: Mention, subtitle: String? = nil) {
        self.id = mention.id
        self.mention = mention
        self.subtitle = subtitle

        // Set icon based on type
        switch mention.type {
        case .note:
            self.icon = "doc.text"
        case .folder:
            self.icon = "folder"
        case .subject:
            self.icon = "book.closed"
        }
    }
}

// MARK: - Mention Range

/// Tracks the range of a mention in the text
struct MentionRange {
    let mention: Mention
    let range: Range<String.Index>
}
