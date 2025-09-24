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
            // user_id is not included in the response (likely due to RLS policies)
            // We can use a placeholder UUID since the data is already user-specific
            // The actual user identification is handled by the auth session
            userId = UUID() // Placeholder UUID - the real user_id is managed by Supabase auth
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
    
    // Custom initializer for creating UserProfile directly
    init(createdAt: Date?, userId: UUID, notesJson: Data?, foldersJson: Data?, updatedAt: Date?, premiumRequests: Int16, normalRequests: Int64, subscriptionTier: SubscriptionTier, subscriptionStartDate: Date?, stripeCustomerId: String?, stripeSubscriptionId: String?) {
        self.createdAt = createdAt
        self.userId = userId
        self.notesJson = notesJson
        self.foldersJson = foldersJson
        self.updatedAt = updatedAt
        self.premiumRequests = premiumRequests
        self.normalRequests = normalRequests
        self.subscriptionTier = subscriptionTier
        self.subscriptionStartDate = subscriptionStartDate
        self.stripeCustomerId = stripeCustomerId
        self.stripeSubscriptionId = stripeSubscriptionId
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


            // Try to extract subscription data directly from raw JSON to bypass RLS filtering
            let rawResponse = try await supabase
                .from("user_storage")
                .select("*")
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            if let _ = String(data: rawResponse.data, encoding: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: rawResponse.data) as? [[String: Any]],
               let firstRecord = jsonArray.first {
                
                // Extract subscription data directly from the raw JSON
                let normalRequests = firstRecord["normal_requests"] as? Int64 ?? 0
                let premiumRequests = firstRecord["premium_requests"] as? Int16 ?? 0
                let subscriptionTierString = firstRecord["subscription_tier"] as? String ?? "FREE"
                let subscriptionStartDateString = firstRecord["subscription_start_date"] as? String
                let stripeCustomerId = firstRecord["stripe_customer_id"] as? String
                let stripeSubscriptionId = firstRecord["stripe_subscription_id"] as? String
                
                
                // Create a UserProfile with the extracted data
                let extractedProfile = UserProfile(
                    createdAt: nil,
                    userId: user.id,
                    notesJson: nil,
                    foldersJson: nil,
                    updatedAt: nil,
                    premiumRequests: premiumRequests,
                    normalRequests: normalRequests,
                    subscriptionTier: SubscriptionTier(rawValue: subscriptionTierString) ?? .free,
                    subscriptionStartDate: subscriptionStartDateString != nil ? ISO8601DateFormatter().date(from: subscriptionStartDateString!) : nil,
                    stripeCustomerId: stripeCustomerId,
                    stripeSubscriptionId: stripeSubscriptionId
                )
                
                await MainActor.run {
                    userProfile = extractedProfile
                }
            } else {
                // Fallback to the original method
                let fullProfiles: [UserProfile] =
                    try await supabase
                    .from("user_storage")
                    .select("*")
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                    .value

                if let firstProfile = fullProfiles.first {
                    print("🔍 SubscriptionManager: Setting user profile with normalRequests: \(firstProfile.normalRequests), premiumRequests: \(firstProfile.premiumRequests)")
                    await MainActor.run {
                        userProfile = firstProfile
                    }
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

                // Update the database
                let _ = try await supabase
                    .from("user_storage")
                    .update([
                        "premium_requests": profile.premiumRequests - 1
                    ])
                    .eq("user_id", value: profile.userId.uuidString)
                    .execute()

            case .normal:
                guard profile.normalRequests > 0 else {
                    return false
                }

                // Update the database
                let _ = try await supabase
                    .from("user_storage")
                    .update([
                        "normal_requests": profile.normalRequests - 1
                    ])
                    .eq("user_id", value: profile.userId.uuidString)
                    .execute()
            }

            // Fetch the updated profile using the same raw JSON extraction method
            let session = try await supabase.auth.session
            let user = session.user
            
            let rawResponse = try await supabase
                .from("user_storage")
                .select("*")
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: rawResponse.data) as? [[String: Any]],
               let firstRecord = jsonArray.first {
                
                // Extract subscription data directly from the raw JSON
                let normalRequests = firstRecord["normal_requests"] as? Int64 ?? 0
                let premiumRequests = firstRecord["premium_requests"] as? Int16 ?? 0
                let subscriptionTierString = firstRecord["subscription_tier"] as? String ?? "FREE"
                let subscriptionStartDateString = firstRecord["subscription_start_date"] as? String
                let stripeCustomerId = firstRecord["stripe_customer_id"] as? String
                let stripeSubscriptionId = firstRecord["stripe_subscription_id"] as? String
                
                // Create updated UserProfile with the extracted data
                updatedProfile = UserProfile(
                    createdAt: nil,
                    userId: user.id,
                    notesJson: nil,
                    foldersJson: nil,
                    updatedAt: nil,
                    premiumRequests: premiumRequests,
                    normalRequests: normalRequests,
                    subscriptionTier: SubscriptionTier(rawValue: subscriptionTierString) ?? .free,
                    subscriptionStartDate: subscriptionStartDateString != nil ? ISO8601DateFormatter().date(from: subscriptionStartDateString!) : nil,
                    stripeCustomerId: stripeCustomerId,
                    stripeSubscriptionId: stripeSubscriptionId
                )
                
                await MainActor.run {
                    userProfile = updatedProfile
                }
            } else {
                // Fallback: manually update the local profile
                let newNormalRequests = type == .normal ? profile.normalRequests - 1 : profile.normalRequests
                let newPremiumRequests = type == .premium ? profile.premiumRequests - 1 : profile.premiumRequests
                
                updatedProfile = UserProfile(
                    createdAt: profile.createdAt,
                    userId: profile.userId,
                    notesJson: profile.notesJson,
                    foldersJson: profile.foldersJson,
                    updatedAt: profile.updatedAt,
                    premiumRequests: newPremiumRequests,
                    normalRequests: newNormalRequests,
                    subscriptionTier: profile.subscriptionTier,
                    subscriptionStartDate: profile.subscriptionStartDate,
                    stripeCustomerId: profile.stripeCustomerId,
                    stripeSubscriptionId: profile.stripeSubscriptionId
                )
                
                await MainActor.run {
                    userProfile = updatedProfile
                }
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
