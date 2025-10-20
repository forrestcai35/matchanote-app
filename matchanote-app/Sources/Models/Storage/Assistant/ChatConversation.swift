import Foundation

// MARK: - Chat Conversation Model
struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var lastUpdatedAt: Date
    var noteId: UUID? // Optional: Link to a specific note if chat was within note context
    
    init(id: UUID = UUID(), title: String, messages: [ChatMessage] = [], noteId: UUID? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.noteId = noteId
    }
    
    // Check if conversation is older than 30 days
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return lastUpdatedAt < thirtyDaysAgo
    }
    
    // Get a preview of the conversation (first user message or "New Chat")
    var preview: String {
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let content = firstUserMessage.content
            return content.count > 60 ? String(content.prefix(60)) + "..." : content
        }
        return "New Chat"
    }
    
    // Update last updated timestamp
    mutating func updateTimestamp() {
        lastUpdatedAt = Date()
    }
    
    // Add a message to the conversation
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updateTimestamp()
    }
    
    // Generate a smart title based on the first few messages
    mutating func generateSmartTitle() {
        if messages.isEmpty {
            title = "New Chat"
            return
        }
        
        // Use the first user message as the title
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let content = firstUserMessage.content
            title = content.count > 40 ? String(content.prefix(40)) + "..." : content
        } else {
            title = "Chat \(createdAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }
    
    // Custom time ago formatter without seconds
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(lastUpdatedAt)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if interval < 60 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days < 7 {
            return "\(days)d ago"
        } else {
            return lastUpdatedAt.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Chat Message Extension for Codable
extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, isUser, model, mediaItems
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(UUID.self, forKey: .id)
        let content = try container.decode(String.self, forKey: .content)
        let isUser = try container.decode(Bool.self, forKey: .isUser)
        let model = try container.decode(String.self, forKey: .model)
        
        // Decode media items if present
        let mediaItems = try container.decodeIfPresent([MediaItemCodable].self, forKey: .mediaItems)
        let decodedMediaItems = mediaItems?.map { MediaItem(data: $0.data, type: $0.type == "image" ? .image : .file($0.fileName ?? "")) }
        
        self.init(content: content, isUser: isUser, model: model, mediaItems: decodedMediaItems)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(model, forKey: .model)
        
        // Encode media items if present
        if let mediaItems = mediaItems {
            let codableItems = mediaItems.map { item -> MediaItemCodable in
                switch item.type {
                case .image:
                    return MediaItemCodable(data: item.data, type: "image", fileName: nil)
                case .file(let name):
                    return MediaItemCodable(data: item.data, type: "file", fileName: name)
                }
            }
            try container.encode(codableItems, forKey: .mediaItems)
        }
    }
}

// Helper struct for encoding/decoding MediaItem
private struct MediaItemCodable: Codable {
    let data: Data
    let type: String
    let fileName: String?
}

