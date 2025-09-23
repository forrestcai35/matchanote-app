import Foundation
import Supabase

// Import the global supabase instance
private let globalSupabase = supabase

// MARK: - Simple User Profile for Testing
struct SimpleUserProfile: Codable {
    let createdAt: Date?
    let userId: UUID
    let premiumRequests: Int16
    let normalRequests: Int64
    let subscriptionTier: String
    let subscriptionStartDate: Date?
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case userId = "user_id"
        case premiumRequests = "premium_requests"
        case normalRequests = "normal_requests"
        case subscriptionTier = "subscription_tier"
        case subscriptionStartDate = "subscription_start_date"
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Profile Model
struct UserProfile: Codable, Identifiable {
    let createdAt: Date?
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

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        
        // Handle UUID decoding - try as UUID first, then as string, then check if key exists
        if let uuidValue = try? container.decode(UUID.self, forKey: .userId) {
            userId = uuidValue
        } else if let stringValue = try? container.decode(String.self, forKey: .userId),
                  let uuidFromString = UUID(uuidString: stringValue) {
            userId = uuidFromString
        } else if container.contains(.userId) {
            // Key exists but couldn't decode
            throw DecodingError.typeMismatch(UUID.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Could not decode user_id as UUID or string"
            ))
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "user_id key not found in response"
            ))
        }

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
        premiumRequests = try container.decodeIfPresent(Int16.self, forKey: .premiumRequests) ?? 0
        normalRequests = try container.decodeIfPresent(Int64.self, forKey: .normalRequests) ?? 0

        let tierString = try container.decodeIfPresent(String.self, forKey: .subscriptionTier) ?? SubscriptionTier.free.rawValue
        subscriptionTier = SubscriptionTier(rawValue: tierString) ?? .free

        subscriptionStartDate = try container.decodeIfPresent(
            Date.self, forKey: .subscriptionStartDate)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        stripeSubscriptionId = try container.decodeIfPresent(
            String.self, forKey: .stripeSubscriptionId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(createdAt, forKey: .createdAt)
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


// MARK: - Premium Models Configuration (Deprecated - Use ModelConfiguration instead)
struct PremiumModels {
    static let premiumModelsList: [String] = ModelConfiguration.getPremiumModelNames()
    static let freeModels: [String] = ModelConfiguration.getFreeModelNames()

    static func isPremiumModel(_ model: String) -> Bool {
        return ModelConfiguration.isPremiumModel(model)
    }

    static func getAvailableModels(for tier: SubscriptionTier) -> [String] {
        return ModelConfiguration.getAvailableModelNames(for: tier)
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



            // Now try with the full UserProfile struct using string UUID
            let fullProfiles: [UserProfile] =
                try await supabase
                .from("user_storage")
                .select("*")
                .eq("user_id", value: user.id.uuidString)
                .execute()
                .value

            if let firstProfile = fullProfiles.first {
                
                await MainActor.run {
                    userProfile = firstProfile
                }
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func canMakeRequest(type: RequestType) -> Bool {
        guard let profile = userProfile else {
            return false
        }

        let canMake: Bool
        switch type {
        case .premium:
            canMake = profile.premiumRequests > 0
        case .normal:
            canMake = profile.normalRequests > 0
        }

        return canMake
    }

    func consumeRequest(type: RequestType, model: String) async -> Bool {
        guard let profile = userProfile else {
            return false
        }


        do {
            let updatedProfile: UserProfile

            switch type {
            case .premium:
                guard profile.premiumRequests > 0 else {
                    return false
                }


                updatedProfile =
                    try await supabase
                    .from("user_storage")
                    .update([
                        "premium_requests": profile.premiumRequests - 1
                    ])
                    .eq("user_id", value: profile.userId.uuidString)
                    .select("*")
                    .single()
                    .execute()
                    .value

            case .normal:
                guard profile.normalRequests > 0 else {
                    return false
                }


                updatedProfile =
                    try await supabase
                    .from("user_storage")
                    .update([
                        "normal_requests": profile.normalRequests - 1
                    ])
                    .eq("user_id", value: profile.userId.uuidString)
                    .select("*")
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
            return false
        }
    }

    func getAvailableModels() -> [String] {
        guard let profile = userProfile else {
            return ModelConfiguration.getFreeModelNames()
        }

        return ModelConfiguration.getAvailableModelNames(for: profile.subscriptionTier)
    }

    func getRequestType(for model: String) -> RequestType {
        return ModelConfiguration.isPremiumModel(model) ? .premium : .normal
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
