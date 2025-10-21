import Foundation
import CryptoKit

// MARK: - Study Storage Manager
class StudyStorageManager: ObservableObject {
    static let shared = StudyStorageManager()

    @Published var currentSession: StudySession?

    private let studySessionsKey = "studySessionsCache"

    private init() {
        cleanupExpiredSessions()
    }

    // MARK: - Content Hashing

    /// Generate a hash of note content to detect changes
    static func generateContentHash(from note: Note) -> String {
        var contentString = ""

        // Include note metadata
        contentString += note.title
        contentString += note.subject
        contentString += note.content

        // Include drawing data (use byte counts as proxy for content)
        for (pageKey, drawingData) in note.drawingDataByPage.sorted(by: { $0.key < $1.key }) {
            contentString += "\(pageKey):\(drawingData.count)"
        }

        // Include text box data
        for (pageKey, textBoxes) in note.textBoxDataByPage.sorted(by: { $0.key < $1.key }) {
            for textBoxData in textBoxes {
                contentString += "\(pageKey):\(textBoxData.count)"
            }
        }

        // Generate SHA256 hash
        let data = Data(contentString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Session Management

    /// Load study session for a note
    func loadSession(for noteId: UUID) -> StudySession? {
        guard let sessions = loadAllSessions() else { return nil }
        return sessions.first { $0.noteId == noteId }
    }

    /// Save or update study session
    func saveSession(_ session: StudySession) {
        var sessions = loadAllSessions() ?? []

        // Remove existing session for this note if present
        sessions.removeAll { $0.noteId == session.noteId }

        // Add updated session
        sessions.append(session)

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: studySessionsKey)
        }

        // Update current session
        if currentSession?.noteId == session.noteId {
            currentSession = session
        }
    }

    /// Delete study session for a note
    func deleteSession(for noteId: UUID) {
        var sessions = loadAllSessions() ?? []
        sessions.removeAll { $0.noteId == noteId }

        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: studySessionsKey)
        }

        if currentSession?.noteId == noteId {
            currentSession = nil
        }
    }

    /// Select current session
    func selectSession(_ session: StudySession) {
        currentSession = session
    }

    /// Clear current session
    func clearCurrentSession() {
        currentSession = nil
    }

    // MARK: - Private Helpers

    private func loadAllSessions() -> [StudySession]? {
        guard let data = UserDefaults.standard.data(forKey: studySessionsKey) else {
            return nil
        }

        return try? JSONDecoder().decode([StudySession].self, from: data)
    }

    private func cleanupExpiredSessions() {
        guard var sessions = loadAllSessions() else { return }

        let originalCount = sessions.count
        sessions.removeAll { $0.isExpired }

        if sessions.count != originalCount {
            if let encoded = try? JSONEncoder().encode(sessions) {
                UserDefaults.standard.set(encoded, forKey: studySessionsKey)
            }
        }
    }

    // MARK: - Cache Validation

    /// Check if cached session is valid for current note content
    func isCacheValid(for note: Note) -> Bool {
        guard let session = loadSession(for: note.id) else { return false }

        let currentHash = Self.generateContentHash(from: note)
        return !session.isStale(currentHash: currentHash) && !session.isExpired
    }

    /// Get or create session for note
    func getOrCreateSession(for note: Note) -> StudySession {
        let currentHash = Self.generateContentHash(from: note)

        if let existingSession = loadSession(for: note.id),
           !existingSession.isStale(currentHash: currentHash),
           !existingSession.isExpired {
            return existingSession
        }

        // Create new session
        return StudySession(noteId: note.id, contentHash: currentHash)
    }
}
