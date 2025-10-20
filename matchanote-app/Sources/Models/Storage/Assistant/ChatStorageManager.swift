import Foundation

// MARK: - Chat Storage Manager
class ChatStorageManager: ObservableObject {
    static let shared = ChatStorageManager()
    
    @Published var conversations: [ChatConversation] = []
    @Published var currentConversation: ChatConversation?
    
    private let conversationsKey = "chat_conversations"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadConversations()
        cleanupExpiredConversations()
    }
    
    // MARK: - Load & Save
    
    func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey) else {
            print("📂 No saved conversations found")
            return
        }
        
        do {
            let decodedConversations = try decoder.decode([ChatConversation].self, from: data)
            conversations = decodedConversations.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
            print("📂 Loaded \(conversations.count) conversations")
        } catch {
            print("❌ Failed to decode conversations: \(error)")
            conversations = []
        }
    }
    
    func saveConversations() {
        do {
            let data = try encoder.encode(conversations)
            UserDefaults.standard.set(data, forKey: conversationsKey)
            print("💾 Saved \(conversations.count) conversations")
        } catch {
            print("❌ Failed to encode conversations: \(error)")
        }
    }
    
    // MARK: - Conversation Management
    
    func createNewConversation(noteId: UUID? = nil) {
        let newConversation = ChatConversation(
            title: "New Chat",
            messages: [],
            noteId: noteId
        )
        currentConversation = newConversation
        conversations.insert(newConversation, at: 0)
        saveConversations()
        print("✨ Created new conversation: \(newConversation.id)")
    }
    
    func selectConversation(_ conversation: ChatConversation) {
        currentConversation = conversation
        print("📖 Selected conversation: \(conversation.title)")
    }
    
    func updateCurrentConversation(with messages: [ChatMessage]) {
        guard var conversation = currentConversation else { return }
        
        conversation.messages = messages
        conversation.updateTimestamp()
        
        // Generate smart title if it's still "New Chat" and has messages
        if conversation.title == "New Chat" && !messages.isEmpty {
            conversation.generateSmartTitle()
        }
        
        // Update in conversations array
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        
        currentConversation = conversation
        
        // Re-sort by last updated
        conversations.sort { $0.lastUpdatedAt > $1.lastUpdatedAt }
        
        saveConversations()
    }
    
    func deleteConversation(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }
        saveConversations()
        print("🗑️ Deleted conversation: \(conversation.title)")
    }
    
    func deleteAllConversations() {
        conversations.removeAll()
        currentConversation = nil
        saveConversations()
        print("🗑️ Deleted all conversations")
    }
    
    // MARK: - Auto-deletion (30 days)
    
    func cleanupExpiredConversations() {
        let expiredCount = conversations.filter { $0.isExpired }.count
        
        if expiredCount > 0 {
            conversations.removeAll { $0.isExpired }
            
            // If current conversation was expired, clear it
            if let current = currentConversation, current.isExpired {
                currentConversation = nil
            }
            
            saveConversations()
            print("🧹 Cleaned up \(expiredCount) expired conversations")
        }
    }
    
    // MARK: - Search & Filter
    
    func searchConversations(query: String) -> [ChatConversation] {
        guard !query.isEmpty else { return conversations }
        
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) ||
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    func getConversationsForNote(noteId: UUID) -> [ChatConversation] {
        return conversations.filter { $0.noteId == noteId }
    }
    
    // MARK: - Statistics
    
    var totalMessageCount: Int {
        conversations.reduce(0) { $0 + $1.messages.count }
    }
    
    var oldestConversationDate: Date? {
        conversations.map { $0.createdAt }.min()
    }
}

