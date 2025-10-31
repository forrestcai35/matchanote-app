import Foundation
import Supabase

/// A simple, synchronous in-memory implementation of AuthLocalStorage.
/// Does NOT persist to disk — all data is lost when the app terminates.
final class MemoryLocalStorage: AuthLocalStorage {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    init() {}

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
