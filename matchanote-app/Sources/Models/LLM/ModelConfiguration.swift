import Foundation

// MARK: - API Provider
enum APIProvider: String, CaseIterable, Codable {
    case openRouter = "openrouter"
    case openai = "openai"
    case anthropic = "anthropic"
    case deepseek = "deepseek"
    case google = "google"
    case x = "x"
    case mistral = "mistral"
    case perplexity = "perplexity"
    case groq = "groq"

    var displayName: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .deepseek: return "DeepSeek"
        case .google: return "Google"
        case .x: return "X (Grok)"
        case .mistral: return "Mistral"
        case .perplexity: return "Perplexity"
        case .groq: return "Groq"
        }
    }
}

// MARK: - Model Definition
struct Model: Codable, Identifiable {
    let displayName: String
    let modelId: String
    let isPremium: Bool
    let provider: APIProvider
    let supportsVision: Bool

    var id: String { modelId }
}

// MARK: - JSON Structure
private struct ModelsJSON: Codable {
    let freeModels: [Model]
    let fallbackModels: [Model]
    let premiumModels: [Model]
}

// MARK: - Model Configuration
/// Loads model configuration from bundled models.json file.
/// Single source of truth: matchanote-web/lib/models.json
/// Copy to iOS: matchanote-app/matchanote-app/Resources/models.json
struct ModelConfiguration {

    // MARK: - Loaded Models
    private static let loadedModels: ModelsJSON = {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode(ModelsJSON.self, from: data) else {
            print("⚠️ ModelConfiguration: Failed to load models.json, using fallback")
            return ModelsJSON(
                freeModels: [
                    Model(displayName: "Matcha Assistant",
                          modelId: "google/gemini-2.0-flash-exp:free",
                          isPremium: false,
                          provider: .openRouter,
                          supportsVision: true)
                ],
                fallbackModels: [],
                premiumModels: []
            )
        }
        print("✅ ModelConfiguration: Loaded \(models.freeModels.count + models.premiumModels.count) models from JSON")
        return models
    }()

    // MARK: - Static Accessors
    static var freeModels: [Model] { loadedModels.freeModels }
    static var premiumModels: [Model] { loadedModels.premiumModels }
    static var allModels: [Model] { freeModels + premiumModels }

    // MARK: - Helper Methods

    /// Get all available models for a given subscription tier
    static func getAvailableModels(for tier: SubscriptionTier) -> [Model] {
        switch tier {
        case .free:
            return freeModels
        case .student:
            return freeModels
        case .pro:
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

    /// Get all premium model display names
    static func getPremiumModelNames() -> [String] {
        return premiumModels.map { $0.displayName }
    }

    /// Get all free model display names
    static func getFreeModelNames() -> [String] {
        return freeModels.map { $0.displayName }
    }

}
