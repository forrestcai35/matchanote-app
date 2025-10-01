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

            // Query both tables to get complete user profile
            // 1. Get subscription tier from user_subscription table
            let subscriptionResponse = try await supabase
                .from("user_subscription")
                .select("*")
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            // 2. Get request counts from user_storage table
            let storageResponse = try await supabase
                .from("user_storage")
                .select("normal_requests, premium_requests")
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            // Parse subscription data
            var subscriptionTier: SubscriptionTier = .free
            var subscriptionStartDate: Date? = nil
            var stripeCustomerId: String? = nil
            var stripeSubscriptionId: String? = nil
            
            if let subscriptionData = try? JSONSerialization.jsonObject(with: subscriptionResponse.data) as? [[String: Any]],
               let subscriptionRecord = subscriptionData.first {
                let subscriptionTierString = subscriptionRecord["subscription_tier"] as? String ?? "FREE"
                subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString) ?? .free
                subscriptionStartDate = (subscriptionRecord["subscription_start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                stripeCustomerId = subscriptionRecord["stripe_customer_id"] as? String
                stripeSubscriptionId = subscriptionRecord["stripe_subscription_id"] as? String
                
                print("🔍 SubscriptionManager: Subscription data from user_subscription table:")
                print("  - subscription_tier: \(subscriptionTierString)")
                print("  - subscription_start_date: \(subscriptionRecord["subscription_start_date"] as? String ?? "nil")")
                print("  - stripe_customer_id: \(stripeCustomerId ?? "nil")")
                print("  - stripe_subscription_id: \(stripeSubscriptionId ?? "nil")")
            }
            
            // Parse request counts
            var normalRequests: Int64 = 0
            var premiumRequests: Int16 = 0
            
            if let storageData = try? JSONSerialization.jsonObject(with: storageResponse.data) as? [[String: Any]],
               let storageRecord = storageData.first {
                normalRequests = storageRecord["normal_requests"] as? Int64 ?? 0
                premiumRequests = storageRecord["premium_requests"] as? Int16 ?? 0
                
                print("🔍 SubscriptionManager: Request data from user_storage table:")
                print("  - normal_requests: \(normalRequests)")
                print("  - premium_requests: \(premiumRequests)")
            }
            
            // Create combined UserProfile
            let combinedProfile = UserProfile(
                createdAt: nil,
                userId: user.id,
                notesJson: nil,
                foldersJson: nil,
                updatedAt: nil,
                premiumRequests: premiumRequests,
                normalRequests: normalRequests,
                subscriptionTier: subscriptionTier,
                subscriptionStartDate: subscriptionStartDate,
                stripeCustomerId: stripeCustomerId,
                stripeSubscriptionId: stripeSubscriptionId
            )
            
            print("🔍 SubscriptionManager: Created combined profile with tier: \(combinedProfile.subscriptionTier.rawValue), hasPremiumAccess: \(combinedProfile.subscriptionTier.hasPremiumAccess)")
            
            await MainActor.run {
                userProfile = combinedProfile
            }

        } catch {
            print("🔍 SubscriptionManager: Error fetching user profile: \(error)")
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

        let updatedProfile: UserProfile

            switch type {
            case .premium:
                guard profile.premiumRequests > 0 else {
                    return false
                }

                // Update the database - premium requests are stored in user_storage table
                do {
                    let _ = try await supabase
                        .from("user_storage")
                        .update([
                            "premium_requests": profile.premiumRequests - 1
                        ])
                        .eq("user_id", value: profile.userId.uuidString)
                        .execute()
                } catch {
                    print("🔍 SubscriptionManager: Error updating premium requests: \(error)")
                }

            case .normal:
                guard profile.normalRequests > 0 else {
                    return false
                }

                // Update the database - normal requests are stored in user_storage table
                do {
                    let _ = try await supabase
                        .from("user_storage")
                        .update([
                            "normal_requests": profile.normalRequests - 1
                        ])
                        .eq("user_id", value: profile.userId.uuidString)
                        .execute()
                } catch {
                    print("🔍 SubscriptionManager: Error updating normal requests: \(error)")
                }
            }

            // Fetch the updated profile by querying both tables
            do {
                let session = try await supabase.auth.session
                let user = session.user
                
                // Get updated request counts from user_storage
                let storageResponse = try await supabase
                    .from("user_storage")
                    .select("normal_requests, premium_requests")
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
                
                // Get subscription data from user_subscription
                let subscriptionResponse = try await supabase
                    .from("user_subscription")
                    .select("*")
                    .eq("user_id", value: user.id.uuidString)
                    .execute()
            
                // Parse updated request counts
                var updatedNormalRequests: Int64 = profile.normalRequests
                var updatedPremiumRequests: Int16 = profile.premiumRequests
                
                if let storageData = try? JSONSerialization.jsonObject(with: storageResponse.data) as? [[String: Any]],
                   let storageRecord = storageData.first {
                    updatedNormalRequests = storageRecord["normal_requests"] as? Int64 ?? profile.normalRequests
                    updatedPremiumRequests = storageRecord["premium_requests"] as? Int16 ?? profile.premiumRequests
                }
                
                // Parse subscription data
                var subscriptionTier: SubscriptionTier = profile.subscriptionTier
                var subscriptionStartDate: Date? = profile.subscriptionStartDate
                var stripeCustomerId: String? = profile.stripeCustomerId
                var stripeSubscriptionId: String? = profile.stripeSubscriptionId
                
                if let subscriptionData = try? JSONSerialization.jsonObject(with: subscriptionResponse.data) as? [[String: Any]],
                   let subscriptionRecord = subscriptionData.first {
                    let subscriptionTierString = subscriptionRecord["subscription_tier"] as? String ?? profile.subscriptionTier.rawValue
                    subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString) ?? profile.subscriptionTier
                    subscriptionStartDate = (subscriptionRecord["subscription_start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? profile.subscriptionStartDate
                    stripeCustomerId = subscriptionRecord["stripe_customer_id"] as? String ?? profile.stripeCustomerId
                    stripeSubscriptionId = subscriptionRecord["stripe_subscription_id"] as? String ?? profile.stripeSubscriptionId
                }
                
                // Create updated UserProfile with the combined data
                updatedProfile = UserProfile(
                    createdAt: profile.createdAt,
                    userId: user.id,
                    notesJson: profile.notesJson,
                    foldersJson: profile.foldersJson,
                    updatedAt: profile.updatedAt,
                    premiumRequests: updatedPremiumRequests,
                    normalRequests: updatedNormalRequests,
                    subscriptionTier: subscriptionTier,
                    subscriptionStartDate: subscriptionStartDate,
                    stripeCustomerId: stripeCustomerId,
                    stripeSubscriptionId: stripeSubscriptionId
                )
                
                await MainActor.run {
                    userProfile = updatedProfile
                }
            } catch {
                print("🔍 SubscriptionManager: Error fetching updated profile: \(error)")
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
