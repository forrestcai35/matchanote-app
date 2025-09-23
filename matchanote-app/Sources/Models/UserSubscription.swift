import Foundation
import Supabase

// Import the global supabase instance
private let globalSupabase = supabase

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
    let createdAt: Date
    let userId: UUID
    
    // Use userId as the identifier since user_storage table doesn't have an id column
    var id: UUID { userId }
    var notesJson: Data?
    var foldersJson: Data?
    let updatedAt: Date?
    
    // Computed properties for backward compatibility
    var notes: Data? { return notesJson }
    var folders: Data? { return foldersJson }
    var premiumRequests: Int16
    var normalRequests: Int64
    var subscriptionTier: SubscriptionTier
    let subscriptionStartDate: Date?
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case userId = "user_id"
        case notesJson = "notes"
        case foldersJson = "folders"
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

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decode(UUID.self, forKey: .userId)

        // Handle JSONB fields - decode as raw JSON data from Supabase
        // Try to decode as string first (if stored as JSON string)
        if let notesString = try? container.decodeIfPresent(String.self, forKey: .notesJson) {
            notesJson = notesString.data(using: .utf8)
        } else {
            // Try to decode as raw data
            notesJson = try? container.decodeIfPresent(Data.self, forKey: .notesJson)
        }
        
        if let foldersString = try? container.decodeIfPresent(String.self, forKey: .foldersJson) {
            foldersJson = foldersString.data(using: .utf8)
        } else {
            // Try to decode as raw data
            foldersJson = try? container.decodeIfPresent(Data.self, forKey: .foldersJson)
        }

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

        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(userId, forKey: .userId)
        // Encode JSONB fields as JSON strings
        if let notesData = notesJson, let notesString = String(data: notesData, encoding: .utf8) {
            try container.encode(notesString, forKey: .notesJson)
        }
        if let foldersData = foldersJson, let foldersString = String(data: foldersData, encoding: .utf8) {
            try container.encode(foldersString, forKey: .foldersJson)
        }
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
        if let client = supabaseClient {
            self.supabase = client
        } else {
            self.supabase = globalSupabase
        }
    }

    func fetchUserProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let session = try await supabase.auth.session
            let user = session.user

            print("DEBUG: Fetching user profile for user ID: \(user.id)")

            // Fetch with explicit column names to ensure proper mapping
            let response: UserProfile =
                try await supabase
                .from("user_storage")
                .select(
                    "created_at, user_id, notes, folders, updated_at, premium_requests, normal_requests, subscription_tier, subscription_start_date, stripe_customer_id, stripe_subscription_id"
                )
                .eq("user_id", value: user.id)
                .single()
                .execute()
                .value

            print("DEBUG: Fetched user profile: \(response)")
            print("DEBUG: Normal requests: \(response.normalRequests)")
            print("DEBUG: Premium requests: \(response.premiumRequests)")
            print("DEBUG: Subscription tier: \(response.subscriptionTier)")

            await MainActor.run {
                userProfile = response
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
            }
            print("DEBUG: Error fetching user profile: \(error)")

            // Try to fetch without single() to see if there are multiple records
            do {
                let session = try await supabase.auth.session
                let user = session.user

                let allRecords: [UserProfile] =
                    try await supabase
                    .from("user_storage")
                    .select("*")
                    .eq("user_id", value: user.id)
                    .execute()
                    .value

                print("DEBUG: Found \(allRecords.count) user profile records")
                for (index, record) in allRecords.enumerated() {
                    print(
                        "DEBUG: Record \(index): normal_requests=\(record.normalRequests), premium_requests=\(record.premiumRequests)"
                    )
                }

                if let firstRecord = allRecords.first {
                    await MainActor.run {
                        userProfile = firstRecord
                    }
                }
            } catch {
                print("DEBUG: Secondary fetch also failed: \(error)")
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func canMakeRequest(type: RequestType) -> Bool {
        guard let profile = userProfile else {
            print("DEBUG: canMakeRequest - No user profile available")
            return false
        }

        let canMake: Bool
        switch type {
        case .premium:
            canMake = profile.premiumRequests > 0
            print(
                "DEBUG: canMakeRequest - Premium request check: \(profile.premiumRequests) > 0 = \(canMake)"
            )
        case .normal:
            canMake = profile.normalRequests > 0
            print(
                "DEBUG: canMakeRequest - Normal request check: \(profile.normalRequests) > 0 = \(canMake)"
            )
        }

        return canMake
    }

    func consumeRequest(type: RequestType, model: String) async -> Bool {
        guard let profile = userProfile else {
            print("DEBUG: consumeRequest - No user profile available")
            return false
        }

        print("DEBUG: consumeRequest - Starting consumption for \(type) request")
        print("DEBUG: consumeRequest - Current normal requests: \(profile.normalRequests)")
        print("DEBUG: consumeRequest - Current premium requests: \(profile.premiumRequests)")

        do {
            let updatedProfile: UserProfile

            switch type {
            case .premium:
                guard profile.premiumRequests > 0 else {
                    print(
                        "DEBUG: consumeRequest - No premium requests available (\(profile.premiumRequests))"
                    )
                    return false
                }

                print(
                    "DEBUG: consumeRequest - Updating premium requests from \(profile.premiumRequests) to \(profile.premiumRequests - 1)"
                )

                updatedProfile =
                    try await supabase
                    .from("user_storage")
                    .update([
                        "premium_requests": profile.premiumRequests - 1
                    ])
                    .eq("user_id", value: profile.userId)
                    .select("*")
                    .single()
                    .execute()
                    .value

            case .normal:
                guard profile.normalRequests > 0 else {
                    print(
                        "DEBUG: consumeRequest - No normal requests available (\(profile.normalRequests))"
                    )
                    return false
                }

                print(
                    "DEBUG: consumeRequest - Updating normal requests from \(profile.normalRequests) to \(profile.normalRequests - 1)"
                )

                updatedProfile =
                    try await supabase
                    .from("user_storage")
                    .update([
                        "normal_requests": profile.normalRequests - 1
                    ])
                    .eq("user_id", value: profile.userId)
                    .select("*")
                    .single()
                    .execute()
                    .value
            }

            print(
                "DEBUG: consumeRequest - Updated profile: normal=\(updatedProfile.normalRequests), premium=\(updatedProfile.premiumRequests)"
            )

            await MainActor.run {
                userProfile = updatedProfile
            }
            return true

        } catch {
            await MainActor.run {
                errorMessage = "Failed to consume request: \(error.localizedDescription)"
            }
            print("DEBUG: consumeRequest - Error consuming request: \(error)")
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

    // Force refresh user profile from Supabase
    func forceRefreshUserProfile() async {
        await fetchUserProfile()
    }

    // Check if the user profile data is potentially stale
    func isProfileDataStale() -> Bool {
        guard let profile = userProfile,
            let updatedAt = profile.updatedAt
        else {
            return true  // No profile or no update timestamp
        }

        // Consider data stale if it's older than 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return updatedAt < fiveMinutesAgo
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
