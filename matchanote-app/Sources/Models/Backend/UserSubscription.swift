import Foundation
import Supabase

// Import the global supabase instance
private let globalSupabase = supabase
// Note: Admin client removed - request decrementing now happens on backend


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
    let subscriptionSource: String?

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
        case subscriptionSource = "subscription_source"
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
        subscriptionSource = try container.decodeIfPresent(String.self, forKey: .subscriptionSource)
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
        try container.encodeIfPresent(subscriptionSource, forKey: .subscriptionSource)
    }
    
    // Custom initializer for creating UserProfile directly
    init(createdAt: Date?, userId: UUID, notesJson: Data?, foldersJson: Data?, updatedAt: Date?, premiumRequests: Int16, normalRequests: Int16, subscriptionTier: SubscriptionTier, subscriptionStartDate: Date?, stripeCustomerId: String?, stripeSubscriptionId: String?, subscriptionSource: String?) {
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
        self.subscriptionSource = subscriptionSource
    }
}


// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient

    // MARK: - UserDefaults Caching
    private let userDefaults = UserDefaults.standard
    private let cachedProfileKey = "user.profile.cache"
    private let cacheTimestampKey = "user.profile.cacheTimestamp"
    private let cacheExpirationDuration: TimeInterval = 3600 // 1 hour

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(supabaseClient: SupabaseClient? = nil) {
        if let client = supabaseClient {
            self.supabase = client
        } else {
            self.supabase = globalSupabase
        }

        // Load cached profile on initialization
        if let cached = loadCachedProfile() {
            self.userProfile = cached
        }
    }

    func fetchUserProfile() async {
        // Only show loading indicator if we don't have any profile yet (first load)
        // If we already have cached data, refresh silently in the background
        let showLoading = await MainActor.run { userProfile == nil }
        await MainActor.run {
            if showLoading { isLoading = true }
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
            var subscriptionSource: String? = nil
            var normalRequests: Int16 = 0
            var premiumRequests: Int16 = 0
            
            if let subscriptionData = try? JSONSerialization.jsonObject(with: subscriptionResponse.data) as? [[String: Any]],
               let subscriptionRecord = subscriptionData.first {
                let subscriptionTierString = subscriptionRecord["subscription_tier"] as? String ?? "FREE"
                subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString) ?? .free
                subscriptionStartDate = (subscriptionRecord["subscription_start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                stripeCustomerId = subscriptionRecord["stripe_customer_id"] as? String
                stripeSubscriptionId = subscriptionRecord["stripe_subscription_id"] as? String
                subscriptionSource = subscriptionRecord["subscription_source"] as? String
                
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
                stripeSubscriptionId: stripeSubscriptionId,
                subscriptionSource: subscriptionSource
            )

            // Save to cache for offline access
            saveProfileToCache(combinedProfile)

            await MainActor.run {
                // Only update if data has actually changed to avoid unnecessary re-renders
                if let existing = userProfile,
                   existing.subscriptionTier == combinedProfile.subscriptionTier,
                   existing.premiumRequests == combinedProfile.premiumRequests,
                   existing.normalRequests == combinedProfile.normalRequests,
                   existing.subscriptionSource == combinedProfile.subscriptionSource {
                    // No meaningful change — skip update to prevent layout flash
                } else {
                    userProfile = combinedProfile
                }
            }

        } catch {
            // On error, try to use cached profile to maintain offline access
            if let cachedProfile = loadCachedProfile() {
                await MainActor.run {
                    userProfile = cachedProfile
                    errorMessage = "Using cached profile (offline mode)"
                    print("⚠️ Using cached profile due to fetch error: \(error.localizedDescription)")
                }
            } else {
                await MainActor.run {
                    if error.localizedDescription.contains("sessionMissing") {
                        errorMessage = "Please sign in to view your subscription details"
                    } else {
                        errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
                    }
                }
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func canMakeRequest(type: RequestType) -> Bool {
        // Use cached profile as fallback if current profile is nil
        guard let profile = getEffectiveProfile() else {
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
        // NOTE: This method just checks if user has enough requests
        // Backend (/api/llm) does the actual decrementing securely
        // Call refreshProfile() after API request completes to sync UI

        guard let profile = userProfile else {
            return false
        }

        switch type {
        case .premium:
            // Just check if user has requests
            return profile.premiumRequests > 0

        case .normal:
            // PRO users get unlimited free model access
            if profile.subscriptionTier == .pro {
                return true
            }
            // Just check if user has requests
            return profile.normalRequests > 0
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
    
    // MARK: - Profile Caching

    /// Save user profile to UserDefaults cache
    private func saveProfileToCache(_ profile: UserProfile) {
        do {
            let data = try encoder.encode(profile)
            userDefaults.set(data, forKey: cachedProfileKey)
            userDefaults.set(Date(), forKey: cacheTimestampKey)
            print("✅ Cached user profile (tier: \(profile.subscriptionTier.rawValue))")
        } catch {
            print("❌ Failed to cache user profile: \(error)")
        }
    }

    /// Load cached user profile from UserDefaults
    private func loadCachedProfile() -> UserProfile? {
        // Check if cache is expired
        if isCacheExpired() {
            print("⏰ Profile cache expired, clearing...")
            clearProfileCache()
            return nil
        }

        guard let data = userDefaults.data(forKey: cachedProfileKey) else {
            print("📭 No cached profile found")
            return nil
        }

        do {
            let profile = try decoder.decode(UserProfile.self, from: data)
            print("✅ Loaded cached profile (tier: \(profile.subscriptionTier.rawValue))")
            return profile
        } catch {
            print("❌ Failed to decode cached profile: \(error)")
            clearProfileCache()
            return nil
        }
    }

    /// Check if the cached profile is expired
    private func isCacheExpired() -> Bool {
        guard let cacheDate = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            return true
        }
        let timeSinceCache = Date().timeIntervalSince(cacheDate)
        return timeSinceCache > cacheExpirationDuration
    }

    /// Clear cached profile (call on logout)
    func clearProfileCache() {
        userDefaults.removeObject(forKey: cachedProfileKey)
        userDefaults.removeObject(forKey: cacheTimestampKey)
        print("🗑️ Cleared profile cache")
    }

    /// Get effective profile (current or cached fallback)
    func getEffectiveProfile() -> UserProfile? {
        return userProfile ?? loadCachedProfile()
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
