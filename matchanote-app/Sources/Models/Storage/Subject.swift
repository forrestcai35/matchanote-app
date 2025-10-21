
import SwiftUI

struct Subject: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: Color
    var dateCreated: Date

    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case id, name, colorString, dateCreated
    }

    // Custom encoding to handle Color serialization
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(colorToHexString(color), forKey: .colorString)
        try container.encode(dateCreated, forKey: .dateCreated)
    }

    // Custom decoding to handle Color deserialization
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let colorString = try container.decode(String.self, forKey: .colorString)
        color = hexStringToColor(colorString)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
    }

    init(name: String, color: Color = .blue, dateCreated: Date = Date()) {
        self.name = name
        self.color = color
        self.dateCreated = dateCreated
    }

    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Subject, rhs: Subject) -> Bool {
        lhs.id == rhs.id
    }
}
