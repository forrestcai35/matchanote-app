import Foundation

// MARK: - Subscription Types
enum SubscriptionTier: String, CaseIterable {
    case free = "FREE"
    case student = "STUDENT"
    case pro = "PRO"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .student: return "Student"
        case .pro: return "Pro"
        }
    }

    var hasPremiumAccess: Bool {
        switch self {
        case .free, .student: return false
        case .pro: return true
        }
    }
}

// MARK: - Request Tracking Models
enum RequestType {
    case premium
    case normal
}

struct RequestUsage {
    let type: RequestType
    let count: Int
    let timestamp: Date
    let model: String
}
