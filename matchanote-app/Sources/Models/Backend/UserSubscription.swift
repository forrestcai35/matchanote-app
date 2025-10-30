import Foundation
import Supabase

// Import the global supabase instance
private let globalSupabase = supabase
private let globalSupabaseAdmin = supabaseAdmin


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
    var normalRequests: Int16
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
        
        // Simple UUID decoding - just use a placeholder since we get user_id from auth session
        userId = UUID() // Placeholder - actual user_id comes from auth session

        // Handle JSONB fields - decode as raw JSON data from Supabase
        if let notesString = try? container.decodeIfPresent(String.self, forKey: .notesJson) {
            notesJson = notesString.data(using: .utf8)
        } else {
            notesJson = try? container.decodeIfPresent(Data.self, forKey: .notesJson)
        }
        
        if let foldersString = try? container.decodeIfPresent(String.self, forKey: .foldersJson) {
            foldersJson = foldersString.data(using: .utf8)
        } else {
            foldersJson = try? container.decodeIfPresent(Data.self, forKey: .foldersJson)
        }

        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        premiumRequests = try container.decodeIfPresent(Int16.self, forKey: .premiumRequests) ?? 0
        normalRequests = try container.decodeIfPresent(Int16.self, forKey: .normalRequests) ?? 0

        let tierString = try container.decodeIfPresent(String.self, forKey: .subscriptionTier) ?? SubscriptionTier.free.rawValue
        subscriptionTier = SubscriptionTier(rawValue: tierString) ?? .free

        subscriptionStartDate = try container.decodeIfPresent(Date.self, forKey: .subscriptionStartDate)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        stripeSubscriptionId = try container.decodeIfPresent(String.self, forKey: .stripeSubscriptionId)
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
    init(createdAt: Date?, userId: UUID, notesJson: Data?, foldersJson: Data?, updatedAt: Date?, premiumRequests: Int16, normalRequests: Int16, subscriptionTier: SubscriptionTier, subscriptionStartDate: Date?, stripeCustomerId: String?, stripeSubscriptionId: String?) {
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

            // Query user_subscription table to get complete user profile
            // All subscription data including request counts are stored in user_subscription table
            let subscriptionResponse = try await supabase
                .from("user_subscription")
                .select("*")
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            // Parse subscription data including request counts
            var subscriptionTier: SubscriptionTier = .free
            var subscriptionStartDate: Date? = nil
            var stripeCustomerId: String? = nil
            var stripeSubscriptionId: String? = nil
            var normalRequests: Int16 = 0
            var premiumRequests: Int16 = 0
            
            if let subscriptionData = try? JSONSerialization.jsonObject(with: subscriptionResponse.data) as? [[String: Any]],
               let subscriptionRecord = subscriptionData.first {
                let subscriptionTierString = subscriptionRecord["subscription_tier"] as? String ?? "FREE"
                subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString) ?? .free
                subscriptionStartDate = (subscriptionRecord["subscription_start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                stripeCustomerId = subscriptionRecord["stripe_customer_id"] as? String
                stripeSubscriptionId = subscriptionRecord["stripe_subscription_id"] as? String
                
                // Request counts are also stored in user_subscription table
                normalRequests = subscriptionRecord["normal_requests"] as? Int16 ?? 0
                premiumRequests = subscriptionRecord["premium_requests"] as? Int16 ?? 0
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
            
            await MainActor.run {
                userProfile = combinedProfile
            }

        } catch {
            await MainActor.run {
                if error.localizedDescription.contains("sessionMissing") {
                    errorMessage = "Please sign in to view your subscription details"
                } else {
                    errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
                }
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
            // PRO users always have access to free models regardless of normal_requests balance
            if profile.subscriptionTier == .pro {
                return true
            }
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

                // Update the database - premium requests are stored in user_subscription table
                // Use admin client to bypass RLS policies
                do {
                    print("🔍 SubscriptionManager: Updating premium requests using admin client (service role)")
                    let _ = try await globalSupabaseAdmin
                        .from("user_subscription")
                        .update([
                            "premium_requests": profile.premiumRequests - 1
                        ])
                        .eq("user_id", value: profile.userId.uuidString)
                        .execute()
                    print("🔍 SubscriptionManager: Successfully updated premium requests")
                } catch {
                    print("🔍 SubscriptionManager: Error updating premium requests: \(error)")
                }

            case .normal:
                // Double check PRO users can always use free models and do not consume normal_requests
                if profile.subscriptionTier == .pro {
                    break
                }
                guard profile.normalRequests > 0 else {
                    return false
                }

                // Update the database - normal requests are stored in user_subscription table
                // Use admin client to bypass RLS policies
                do {
                    print("🔍 SubscriptionManager: Updating normal requests using admin client (service role)")
                    let _ = try await globalSupabaseAdmin
                        .from("user_subscription")
                        .update([
                            "normal_requests": profile.normalRequests - 1
                        ])
                        .eq("user_id", value: profile.userId.uuidString)
                        .execute()
                    print("🔍 SubscriptionManager: Successfully updated normal requests")
                } catch {
                    print("🔍 SubscriptionManager: Error updating normal requests: \(error)")
                }
            }

            // Fetch the updated profile using admin client to maintain service role context
            do {
                // Get updated data from user_subscription table using admin client
                let subscriptionResponse = try await globalSupabaseAdmin
                    .from("user_subscription")
                    .select("*")
                    .eq("user_id", value: profile.userId.uuidString)
                    .execute()
            
                // Parse updated data from user_subscription table
                var updatedNormalRequests: Int16 = profile.normalRequests
                var updatedPremiumRequests: Int16 = profile.premiumRequests
                var subscriptionTier: SubscriptionTier = profile.subscriptionTier
                var subscriptionStartDate: Date? = profile.subscriptionStartDate
                var stripeCustomerId: String? = profile.stripeCustomerId
                var stripeSubscriptionId: String? = profile.stripeSubscriptionId
                
                if let subscriptionData = try? JSONSerialization.jsonObject(with: subscriptionResponse.data) as? [[String: Any]],
                   let subscriptionRecord = subscriptionData.first {
                    // Get updated request counts
                    updatedNormalRequests = subscriptionRecord["normal_requests"] as? Int16 ?? profile.normalRequests
                    updatedPremiumRequests = subscriptionRecord["premium_requests"] as? Int16 ?? profile.premiumRequests
                    
                    // Get subscription data
                    let subscriptionTierString = subscriptionRecord["subscription_tier"] as? String ?? profile.subscriptionTier.rawValue
                    subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString) ?? profile.subscriptionTier
                    subscriptionStartDate = (subscriptionRecord["subscription_start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? profile.subscriptionStartDate
                    stripeCustomerId = subscriptionRecord["stripe_customer_id"] as? String ?? profile.stripeCustomerId
                    stripeSubscriptionId = subscriptionRecord["stripe_subscription_id"] as? String ?? profile.stripeSubscriptionId
                }
                
                // Create updated UserProfile with the combined data
                updatedProfile = UserProfile(
                    createdAt: profile.createdAt,
                    userId: profile.userId, // Use profile's user ID (no session needed)
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
    
    // MARK: - Admin Client Verification
    
    /// Verify that the admin client is operating with service role privileges
    func verifyAdminClientRole() async {
        do {
            // Try to get the current session from admin client
            let session = try await globalSupabaseAdmin.auth.session
            print("🔍 Admin client session role: \(session.user.role ?? "unknown")")
            print("🔍 Admin client user ID: \(session.user.id)")
        } catch {
            // If there's no session, that's actually good - it means we're operating as service role
            print("🔍 Admin client has no user session (expected for service role): \(error)")
        }
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
