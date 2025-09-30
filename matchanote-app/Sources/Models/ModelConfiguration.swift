import Foundation

// MARK: - Model Configuration
struct ModelConfiguration {
    
    // MARK: - Model Definition
    struct Model {
        let displayName: String
        let modelId: String
        let isPremium: Bool
        
        init(displayName: String, modelId: String, isPremium: Bool = false) {
            self.displayName = displayName
            self.modelId = modelId
            self.isPremium = isPremium
        }
    }
    
    // MARK: - Free Models
    static let freeModels: [Model] = [
        Model(displayName: "Matcha Assistant", modelId: "x-ai/grok-4-fast:free", isPremium: false)
    ]
    
    // MARK: - Premium Models
    static let premiumModels: [Model] = [
        Model(displayName: "gpt-5", modelId: "openai/gpt-5-flash", isPremium: true),
        Model(displayName: "claude 4.5 Sonnet", modelId: "anthropic/claude-sonnet-4.5", isPremium: true),
        Model(displayName: "o4", modelId: "openai/o4-mini", isPremium: true),
        Model(displayName: "gemini-2.5", modelId: "google/gemini-2.5-flash", isPremium: true),
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
}
