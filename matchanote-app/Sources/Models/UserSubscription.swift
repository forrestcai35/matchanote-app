import Foundation
import Supabase

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
        case .free: return false
        case .student, .pro: return true
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Codable, Identifiable {
    let id: UUID?
    let createdAt: Date
    let userId: UUID
    var notes: [String: Any]?
    var folders: [String: Any]?
    let updatedAt: Date?
    var premiumRequests: Int16
    var normalRequests: Int64
    var subscriptionTier: SubscriptionTier
    let subscriptionStartDate: Date?
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case userId = "user_id"
        case notes
        case folders
        case updatedAt = "updated_at"
        case premiumRequests = "premium_requests"
        case normalRequests = "normal_requests"
        case subscriptionTier = "subscription_tier"
        case subscriptionStartDate = "subscription_start_date"
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decode(UUID.self, forKey: .userId)

        // Handle JSONB fields - skip for now as they require custom decoding
        notes = nil
        folders = nil

        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        premiumRequests = try container.decode(Int16.self, forKey: .premiumRequests)
        normalRequests = try container.decode(Int64.self, forKey: .normalRequests)

        let tierString = try container.decode(String.self, forKey: .subscriptionTier)
        subscriptionTier = SubscriptionTier(rawValue: tierString) ?? .free

        subscriptionStartDate = try container.decodeIfPresent(
            Date.self, forKey: .subscriptionStartDate)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        stripeSubscriptionId = try container.decodeIfPresent(
            String.self, forKey: .stripeSubscriptionId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(userId, forKey: .userId)
        // Skip notes and folders encoding for now as they require custom JSON handling
        // try container.encodeIfPresent(notes, forKey: .notes)
        // try container.encodeIfPresent(folders, forKey: .folders)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(premiumRequests, forKey: .premiumRequests)
        try container.encode(normalRequests, forKey: .normalRequests)
        try container.encode(subscriptionTier.rawValue, forKey: .subscriptionTier)
        try container.encodeIfPresent(subscriptionStartDate, forKey: .subscriptionStartDate)
        try container.encodeIfPresent(stripeCustomerId, forKey: .stripeCustomerId)
        try container.encodeIfPresent(stripeSubscriptionId, forKey: .stripeSubscriptionId)
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

// MARK: - Premium Models Configuration
struct PremiumModels {
    static let premiumModelsList: [String] = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "gpt-4o",
        "gpt-4o-mini",
        "o1-preview",
        "o1-mini",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
    ]

    static let freeModels: [String] = [
        "Matcha Assistant"  // This maps to "x-ai/grok-4-fast:free"
    ]

    static func isPremiumModel(_ model: String) -> Bool {
        return premiumModelsList.contains(model)
    }

    static func getAvailableModels(for tier: SubscriptionTier) -> [String] {
        switch tier {
        case .free:
            return freeModels
        case .student, .pro:
            return freeModels + premiumModelsList
        }
    }
}

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient

    init(supabaseClient: SupabaseClient? = nil) {
        self.supabase = supabaseClient ?? SupabaseInstance.shared.supabase
    }

    func fetchUserProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let session = try await supabase.auth.session
            let user = session.user

            let response: UserProfile =
                try await supabase
                .from("user_profiles")
                .select()
                .eq("user_id", value: user.id)
                .single()
                .execute()
                .value

            await MainActor.run {
                userProfile = response
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
            }
            print("Error fetching user profile: \(error)")
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func canMakeRequest(type: RequestType) -> Bool {
        guard let profile = userProfile else { return false }

        switch type {
        case .premium:
            return profile.premiumRequests > 0
        case .normal:
            return profile.normalRequests > 0
        }
    }

    func consumeRequest(type: RequestType, model: String) async -> Bool {
        guard let profile = userProfile else { return false }

        do {
            let updatedProfile: UserProfile

            switch type {
            case .premium:
                guard profile.premiumRequests > 0 else { return false }

                updatedProfile =
                    try await supabase
                    .from("user_profiles")
                    .update([
                        "premium_requests": profile.premiumRequests - 1
                    ])
                    .eq("user_id", value: profile.userId)
                    .select()
                    .single()
                    .execute()
                    .value

            case .normal:
                guard profile.normalRequests > 0 else { return false }

                updatedProfile =
                    try await supabase
                    .from("user_profiles")
                    .update([
                        "normal_requests": profile.normalRequests - 1
                    ])
                    .eq("user_id", value: profile.userId)
                    .select()
                    .single()
                    .execute()
                    .value
            }

            await MainActor.run {
                userProfile = updatedProfile
            }
            return true

        } catch {
            await MainActor.run {
                errorMessage = "Failed to consume request: \(error.localizedDescription)"
            }
            print("Error consuming request: \(error)")
            return false
        }
    }

    func getAvailableModels() -> [String] {
        guard let profile = userProfile else {
            return PremiumModels.freeModels
        }

        return PremiumModels.getAvailableModels(for: profile.subscriptionTier)
    }

    func getRequestType(for model: String) -> RequestType {
        return PremiumModels.isPremiumModel(model) ? .premium : .normal
    }
}

// MARK: - Errors
enum SubscriptionError: Error, LocalizedError {
    case userNotAuthenticated
    case insufficientRequests
    case subscriptionExpired
    case invalidSubscriptionTier

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .insufficientRequests:
            return "Insufficient requests remaining"
        case .subscriptionExpired:
            return "Subscription has expired"
        case .invalidSubscriptionTier:
            return "Invalid subscription tier"
        }
    }
}
