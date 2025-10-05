import Foundation

// MARK: - API Provider
enum APIProvider: String, CaseIterable {
    case openRouter = "openrouter"
    case openai = "openai"
    case anthropic = "anthropic"
    case deepseek = "deepseek"
    case google = "google"
    case x = "x"
    
    var displayName: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .deepseek: return "DeepSeek"
        case .google: return "Google"
        case .x: return "X (Grok)"
        }
    }
}

// MARK: - Model Configuration
struct ModelConfiguration {
    
    // MARK: - Model Definition
    struct Model {
        let displayName: String
        let modelId: String
        let isPremium: Bool
        let provider: APIProvider
        
        init(displayName: String, modelId: String, isPremium: Bool = false, provider: APIProvider = .openRouter) {
            self.displayName = displayName
            self.modelId = modelId
            self.isPremium = isPremium
            self.provider = provider
        }
    }
    
    // MARK: - Free Models
    static let freeModels: [Model] = [
        Model(displayName: "Matcha Assistant", modelId: "google/gemini-2.0-flash-exp:free", isPremium: false, provider: .openRouter)
    ]
    
    // MARK: - Premium Models
    static let premiumModels: [Model] = [
        Model(displayName: "gpt-5", modelId: "gpt-5-nano", isPremium: true, provider: .openai),
        Model(displayName: "claude 4.5 Sonnet", modelId: "claude-sonnet-4-5-20250929", isPremium: true, provider: .anthropic),
        Model(displayName: "gemini-2.5", modelId: "gemini-2.5-flash", isPremium: true, provider: .google),
        Model(displayName: "grok 4", modelId: "grok-4-fast-non-reasoning", isPremium: true, provider: .x),
        Model(displayName: "DeepSeek V3", modelId: "deepseek-chat", isPremium: true, provider: .deepseek),
    ]
    
    // MARK: - All Models
    static let allModels: [Model] = freeModels + premiumModels
    
    // MARK: - Helper Methods
    
    /// Get all available models for a given subscription tier
    static func getAvailableModels(for tier: SubscriptionTier) -> [Model] {
        switch tier {
        case .free:
            return freeModels
        case .student, .pro:
            return allModels
        }
    }
    
    /// Get all available model display names for a given subscription tier
    static func getAvailableModelNames(for tier: SubscriptionTier) -> [String] {
        return getAvailableModels(for: tier).map { $0.displayName }
    }
    
    /// Check if a model (by display name) is premium
    static func isPremiumModel(_ modelDisplayName: String) -> Bool {
        return allModels.first { $0.displayName == modelDisplayName }?.isPremium ?? false
    }
    
    /// Get the model ID for a given display name
    static func getModelId(for displayName: String) -> String? {
        return allModels.first { $0.displayName == displayName }?.modelId
    }
    
    /// Get the model configuration for a given display name
    static func getModel(for displayName: String) -> Model? {
        return allModels.first { $0.displayName == displayName }
    }
    
    /// Get all premium model display names
    static func getPremiumModelNames() -> [String] {
        return premiumModels.map { $0.displayName }
    }
    
    /// Get all free model display names
    static func getFreeModelNames() -> [String] {
        return freeModels.map { $0.displayName }
    }
    
    /// Get the API provider for a given display name
    static func getProvider(for displayName: String) -> APIProvider? {
        return allModels.first { $0.displayName == displayName }?.provider
    }
    
    /// Get the model configuration for a given display name
    static func getModelConfig(for displayName: String) -> Model? {
        return allModels.first { $0.displayName == displayName }
    }
    
}
