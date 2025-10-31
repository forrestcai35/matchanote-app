import Foundation
import Supabase

/// Conforms to `AuthLocalStorage` (sync, throwing, Data-based) and is safe under Swift 6.
/// Nothing is persisted beyond process lifetime.
final class MemoryLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    init() {}

    func store(key: String, value: Data) throws {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        let v = storage[key]
        lock.unlock()
        return v
    }

    func remove(key: String) throws {
        lock.lock()
        storage.removeValue(forKey: key)
        lock.unlock()
    }
}

