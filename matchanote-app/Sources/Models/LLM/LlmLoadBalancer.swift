import Foundation

// MARK: - Free Model Definition

/// Represents a free LLM model with its capabilities and metadata
struct FreeModel {
  let name: String
  let modelId: String
  let provider: APIProvider
  let supportsImages: Bool
  let tokensPerMinute: Int // Rate limit in tokens/minute
  let requestsPerDay: Int // Daily request limit
  let requestsPerMinute: Int // Requests per minute limit
  let isGoodForHighTokens: Bool // Good for requests with many tokens
  let isGoodForHighVolume: Bool // Good for many requests

  /// All available free models from OpenRouter, Google, Groq, and Mistral
  static let availableFreeModels: [FreeModel] = [
    // OpenRouter Free Models - Best for high token usage (no per-model token limits)
    FreeModel(
      name: "Gemini 2.0 Flash (OpenRouter)",
      modelId: "google/gemini-2.0-flash-exp:free",
      provider: .openRouter,
      supportsImages: true,
      tokensPerMinute: 999999, // No specific limit - shared quota
      requestsPerDay: 50, // Conservative estimate
      requestsPerMinute: 20,
      isGoodForHighTokens: true, // Best for high token requests
      isGoodForHighVolume: false
    ),
    FreeModel(
      name: "Llama 3.3 70B (OpenRouter)",
      modelId: "meta-llama/llama-3.3-70b-instruct:free",
      provider: .openRouter,
      supportsImages: false,
      tokensPerMinute: 999999, // No specific limit - shared quota
      requestsPerDay: 50,
      requestsPerMinute: 20,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),
    FreeModel(
      name: "Qwen 3 32B (OpenRouter)",
      modelId: "qwen/qwen3-32b:free",
      provider: .openRouter,
      supportsImages: false,
      tokensPerMinute: 999999,
      requestsPerDay: 50,
      requestsPerMinute: 20,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),
    FreeModel(
      name: "DeepSeek R1 (OpenRouter)",
      modelId: "deepseek/deepseek-r1-0528:free",
      provider: .openRouter,
      supportsImages: false,
      tokensPerMinute: 999999,
      requestsPerDay: 50,
      requestsPerMinute: 20,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),

    // Google Direct Models - Good balance of tokens and requests
    FreeModel(
      name: "Gemini 2.0 Flash",
      modelId: "gemini-2.0-flash-exp",
      provider: .google,
      supportsImages: true,
      tokensPerMinute: 250000,
      requestsPerDay: 50,
      requestsPerMinute: 10,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),
    FreeModel(
      name: "Gemini 2.5 Flash",
      modelId: "gemini-2.5-flash",
      provider: .google,
      supportsImages: true,
      tokensPerMinute: 250000,
      requestsPerDay: 250,
      requestsPerMinute: 10,
      isGoodForHighTokens: true,
      isGoodForHighVolume: true
    ),

    // Groq Models - Fast inference, varying limits
    FreeModel(
      name: "Llama 3.1 8B",
      modelId: "llama-3.1-8b-instant",
      provider: .groq,
      supportsImages: false,
      tokensPerMinute: 6000,
      requestsPerDay: 14400, // Excellent for high volume!
      requestsPerMinute: 30,
      isGoodForHighTokens: false,
      isGoodForHighVolume: true // Great for many simple requests
    ),
    FreeModel(
      name: "Llama 3.3 70B",
      modelId: "llama-3.3-70b-versatile",
      provider: .groq,
      supportsImages: false,
      tokensPerMinute: 12000,
      requestsPerDay: 1000,
      requestsPerMinute: 20,
      isGoodForHighTokens: false,
      isGoodForHighVolume: false
    ),
    
    // Mistral Models - Good balance and instruction following
    FreeModel(
      name: "Mistral 7B",
      modelId: "mistral-7b-instruct",
      provider: .mistral,
      supportsImages: false,
      tokensPerMinute: 999999, // No enforced limit on free tier
      requestsPerDay: 1000,
      requestsPerMinute: 10,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),
    FreeModel(
      name: "Mistral Small",
      modelId: "mistral-small-latest",
      provider: .mistral,
      supportsImages: false,
      tokensPerMinute: 999999,
      requestsPerDay: 1000,
      requestsPerMinute: 10,
      isGoodForHighTokens: true,
      isGoodForHighVolume: false
    ),
  ]
}

// MARK: - Token Estimation

/// Estimates the number of tokens in a message
class TokenEstimator {
  /// Rough estimation: ~4 characters per token (conservative)
  static func estimateTokens(userMessage: String, conversationHistory: [ChatMessage]? = nil) -> Int {
    var totalChars = userMessage.count

    // Add conversation history
    if let history = conversationHistory {
      for message in history {
        totalChars += message.content.count
      }
    }

    // Rough estimate: 4 characters per token
    let estimatedTokens = totalChars / 4

    print("📊 Token Estimator: ~\(estimatedTokens) tokens (message: \(userMessage.count) chars, history: \(conversationHistory?.count ?? 0) messages)")
    return estimatedTokens
  }
}

// MARK: - Model Load Balancer

/// Intelligently selects the best free model based on rate limits and task requirements
class ModelLoadBalancer {
  private static var rateLimitedModels: [String: Date] = [:]
  private static var modelUsageCount: [String: Int] = [:]
  private static let rateLimitCooldown: TimeInterval = 60 // 60 seconds cooldown

  // Token thresholds for model selection
  private static let highTokenThreshold = 5000 // Use high-token models above this
  private static let mediumTokenThreshold = 1000 // Use medium models above this

  /// Mark a model as rate limited
  static func markRateLimited(_ modelId: String) {
    rateLimitedModels[modelId] = Date()
    print("📊 Load Balancer: Marked \(modelId) as rate limited for \(Int(rateLimitCooldown))s")
  }

  /// Check if a model is currently rate limited
  static func isRateLimited(_ modelId: String) -> Bool {
    guard let limitedDate = rateLimitedModels[modelId] else { return false }
    let timeSince = Date().timeIntervalSince(limitedDate)
    if timeSince > rateLimitCooldown {
      rateLimitedModels.removeValue(forKey: modelId)
      return false
    }
    return true
  }

  /// Increment usage counter for a model
  private static func recordUsage(_ modelId: String) {
    modelUsageCount[modelId, default: 0] += 1
  }

  /// Select the best available free model for the given task
  static func selectBestModel(hasMediaItems: Bool, estimatedTokens: Int = 0) -> FreeModel? {
    print("📊 Load Balancer: Selecting model (media: \(hasMediaItems), tokens: ~\(estimatedTokens))")

    // Filter available models
    var availableModels = FreeModel.availableFreeModels.filter { model in
      // Must not be rate limited
      guard !isRateLimited(model.modelId) else { return false }

      // Must support images if media is present
      if hasMediaItems && !model.supportsImages {
        return false
      }

      return true
    }

    // If no models available, try all models anyway (cooldown might have expired)
    if availableModels.isEmpty {
      print("⚠️ Load Balancer: No available models, trying all models anyway")
      availableModels = FreeModel.availableFreeModels
    }

    // Sort by strategy based on estimated token count
    availableModels.sort { model1, model2 in
      // Strategy 1: High token requests (>5000 tokens) - prioritize OpenRouter
      if estimatedTokens > highTokenThreshold {
        if model1.isGoodForHighTokens != model2.isGoodForHighTokens {
          return model1.isGoodForHighTokens // Prefer high-token models
        }
      }
      // Strategy 2: Low token requests (<1000 tokens) - prioritize high-volume models
      else if estimatedTokens < mediumTokenThreshold {
        if model1.isGoodForHighVolume != model2.isGoodForHighVolume {
          return model1.isGoodForHighVolume // Prefer high-volume models
        }
      }
      // Strategy 3: Medium tokens - balance both factors
      else {
        let score1 = (model1.isGoodForHighTokens ? 1 : 0) + (model1.isGoodForHighVolume ? 1 : 0)
        let score2 = (model2.isGoodForHighTokens ? 1 : 0) + (model2.isGoodForHighVolume ? 1 : 0)
        if score1 != score2 {
          return score1 > score2
        }
      }

      // Prioritize image-capable models if media is present
      if hasMediaItems {
        if model1.supportsImages != model2.supportsImages {
          return model1.supportsImages
        }
      }

      // Use actual token limits as tiebreaker
      return model1.tokensPerMinute > model2.tokensPerMinute
    }

    // Select the best model
    if let selectedModel = availableModels.first {
      recordUsage(selectedModel.modelId)
      let strategy = estimatedTokens > highTokenThreshold ? "high-token" :
                     estimatedTokens < mediumTokenThreshold ? "high-volume" : "balanced"
      print("📊 Load Balancer: Selected '\(selectedModel.name)' (strategy: \(strategy), tokens/min: \(selectedModel.tokensPerMinute), req/day: \(selectedModel.requestsPerDay))")
      return selectedModel
    }

    print("❌ Load Balancer: No suitable model found")
    return nil
  }

  /// Get all available models that match the criteria
  static func getAvailableModels(hasMediaItems: Bool) -> [FreeModel] {
    return FreeModel.availableFreeModels.filter { model in
      !isRateLimited(model.modelId) && (!hasMediaItems || model.supportsImages)
    }.sorted { $0.tokensPerMinute > $1.tokensPerMinute }
  }

  /// Reset all rate limit tracking and usage stats
  static func reset() {
    rateLimitedModels.removeAll()
    modelUsageCount.removeAll()
    print("🔄 Load Balancer: Reset all tracking data")
  }

  /// Get current status for debugging
  static func getStatus() -> String {
    var status = "Load Balancer Status:\n"
    status += "Rate Limited Models: \(rateLimitedModels.count)\n"
    for (modelId, date) in rateLimitedModels {
      let remaining = rateLimitCooldown - Date().timeIntervalSince(date)
      status += "  - \(modelId): \(Int(max(0, remaining)))s remaining\n"
    }
    status += "Model Usage:\n"
    for (modelId, count) in modelUsageCount.sorted(by: { $0.value > $1.value }) {
      status += "  - \(modelId): \(count) requests\n"
    }
    return status
  }
}

// MARK: - Universal Fallback System

/// Provides universal fallback functionality for all models
class UniversalFallback {

  /// Attempt to send a message through the universal fallback system
  /// This tries all available free models in order of priority
  static func sendMessage(
    userMessage: String,
    mediaItems: [MediaItem]? = nil,
    conversationHistory: [ChatMessage]? = nil,
    originalError: Error,
    excludeModels: Set<String> = [],
    systemPrompt: PromptUseCase? = nil
  ) async throws -> String {
    print("🔄 Universal Fallback: Activating (original error: \(originalError.localizedDescription))")

    let hasMedia = mediaItems != nil && !(mediaItems?.isEmpty ?? true)
    var lastError = originalError
    let availableModels = ModelLoadBalancer.getAvailableModels(hasMediaItems: hasMedia)

    print("🔄 Universal Fallback: Trying \(availableModels.count) available models")

    // Try each available model in priority order
    for freeModel in availableModels {
      // Skip if this model is in the exclude list
      if excludeModels.contains(freeModel.modelId) {
        print("⏭️  Universal Fallback: Skipping \(freeModel.name) (excluded)")
        continue
      }

      do {
        print("🔄 Universal Fallback: Trying \(freeModel.name)...")
        let result = try await sendWithFreeModel(
          freeModel,
          userMessage: userMessage,
          mediaItems: mediaItems,
          conversationHistory: conversationHistory,
          systemPrompt: systemPrompt
        )
        print("✅ Universal Fallback: Succeeded with \(freeModel.name)")
        return result
      } catch {
        print("❌ Universal Fallback: \(freeModel.name) failed - \(error.localizedDescription)")
        lastError = error

        // Mark as rate limited if it's a rate limit error
        if isRateLimitError(error) {
          ModelLoadBalancer.markRateLimited(freeModel.modelId)
        }
      }
    }

    print("❌ Universal Fallback: All fallback options exhausted")
    throw lastError
  }

  /// Send a message using a specific free model
  private static func sendWithFreeModel(
    _ freeModel: FreeModel,
    userMessage: String,
    mediaItems: [MediaItem]? = nil,
    conversationHistory: [ChatMessage]? = nil,
    systemPrompt: PromptUseCase? = nil
  ) async throws -> String {
    switch freeModel.provider {
    case .openRouter:
      return try await LlmAPI.sendOpenRouterMessage(
        userMessage: userMessage,
        model: freeModel.modelId,
        mediaItems: mediaItems,
        conversationHistory: conversationHistory,
        systemPrompt: systemPrompt
      )
    case .google:
      return try await LlmAPI.sendGoogleMessage(
        userMessage: userMessage,
        model: freeModel.modelId,
        mediaItems: mediaItems,
        conversationHistory: conversationHistory,
        systemPrompt: systemPrompt
      )
    case .mistral:
      return try await LlmAPI.sendMistralMessage(
        userMessage: userMessage,
        model: freeModel.modelId,
        mediaItems: mediaItems,
        conversationHistory: conversationHistory,
        systemPrompt: systemPrompt
      )
    case .groq:
      return try await LlmAPI.sendGroqMessage(
        userMessage: userMessage,
        model: freeModel.modelId,
        mediaItems: mediaItems,
        conversationHistory: conversationHistory,
        systemPrompt: systemPrompt
      )
    default:
      throw LlmError.invalidResponse
    }
  }

  /// Check if an error is a rate limit error
  private static func isRateLimitError(_ error: Error) -> Bool {
    if let llmError = error as? LlmError {
      switch llmError {
      case .rateLimitExceeded:
        return true
      default:
        return false
      }
    }

    // Check error message for rate limit indicators
    let errorMessage = error.localizedDescription.lowercased()
    return errorMessage.contains("rate limit") ||
           errorMessage.contains("too many requests") ||
           errorMessage.contains("quota exceeded") ||
           errorMessage.contains("429")
  }
}
