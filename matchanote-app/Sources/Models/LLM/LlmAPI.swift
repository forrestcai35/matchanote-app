import Foundation

enum LlmError: Error {
  case invalidURL
  case requestFailed(Error)
  case invalidResponse
  case decodingFailed(Error)
  case missingAPIKey
  case rateLimitExceeded

  var localizedDescription: String {
    switch self {
    case .invalidURL:
      return "Invalid URL"
    case .requestFailed(let error):
      return "Request failed: \(error.localizedDescription)"
    case .invalidResponse:
      return "Invalid response from server"
    case .decodingFailed(let error):
      return "Failed to decode response: \(error.localizedDescription)"
    case .missingAPIKey:
      return "Missing API key"
    case .rateLimitExceeded:
      return "Rate limit exceeded"
    }
  }
}

struct LlmAPI {
  // MARK: - API Keys
  private static var openRouterAPIKey: String? = nil
  private static var openAIAPIKey: String? = nil
  private static var anthropicAPIKey: String? = nil
  private static var deepSeekAPIKey: String? = nil
  private static var googleAPIKey: String? = nil
  private static var xAPIKey: String? = nil
  private static var mistralAPIKey: String? = nil
  private static var perplexityAPIKey: String? = nil
  private static var groqAPIKey: String? = nil

  // MARK: - Endpoints
  private static let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"
  private static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
  private static let anthropicEndpoint = "https://api.anthropic.com/v1/messages"
  private static let deepSeekEndpoint = "https://api.deepseek.com/v1/chat/completions"
  private static let googleEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
  private static let xEndpoint = "https://api.x.ai/v1/chat/completions"
  private static let mistralEndpoint = "https://api.mistral.ai/v1/chat/completions"
  private static let perplexityEndpoint = "https://api.perplexity.ai/chat/completions"
  private static let groqEndpoint = "https://api.groq.com/openai/v1/chat/completions"

  // MARK: - Configuration
  static func configure(openRouterAPIKey: String? = nil,
                       openAIAPIKey: String? = nil,
                       anthropicAPIKey: String? = nil,
                       deepSeekAPIKey: String? = nil,
                       googleAPIKey: String? = nil,
                       xAPIKey: String? = nil,
                       mistralAPIKey: String? = nil,
                       perplexityAPIKey: String? = nil,
                       groqAPIKey: String? = nil) {
    self.openRouterAPIKey = openRouterAPIKey
    self.openAIAPIKey = openAIAPIKey
    self.anthropicAPIKey = anthropicAPIKey
    self.deepSeekAPIKey = deepSeekAPIKey
    self.googleAPIKey = googleAPIKey
    self.xAPIKey = xAPIKey
    self.mistralAPIKey = mistralAPIKey
    self.perplexityAPIKey = perplexityAPIKey
    self.groqAPIKey = groqAPIKey
  }

  static func sendMessage(userMessage: String, model_string: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    print("🤖 Sending message to model: \(model_string)")

    // Special handling for Matcha Assistant - use load balancer
    if model_string == "Matcha Assistant" {
      return try await sendWithLoadBalancer(userMessage: userMessage, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    }

    guard let modelConfig = ModelConfiguration.getModelConfig(for: model_string) else {
      print("❌ Model not found: \(model_string)")
      throw LlmError.invalidResponse
    }

    print("🔧 Using provider: \(modelConfig.provider.displayName)")

    do {
      return try await sendMessageWithProvider(userMessage: userMessage, modelConfig: modelConfig, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    } catch {
      print("❌ Error with \(modelConfig.provider.displayName): \(error)")

      // Mark as rate limited if applicable
      if isRateLimitError(error) {
        ModelLoadBalancer.markRateLimited(modelConfig.modelId)
      }

      // Try universal fallback for all models
      do {
        return try await UniversalFallback.sendMessage(
          userMessage: userMessage,
          mediaItems: mediaItems,
          conversationHistory: conversationHistory,
          originalError: error,
          excludeModels: [modelConfig.modelId],
          systemPrompt: systemPrompt
        )
      } catch let fallbackError {
        print("❌ Universal fallback also failed: \(fallbackError)")
        throw fallbackError
      }
    }
  }

  // MARK: - Load Balancer Integration

  // MARK: - Helper to determine system prompt
  private static func getSystemPromptText(for model: String, customPrompt: PromptUseCase?) -> String {
    if let customPrompt = customPrompt {
      return SystemPrompt.getPrompt(for: customPrompt)
    }
    return SystemPrompt.getPrompt(for: PromptConfiguration.shouldUseConcisePrompt(for: model) ? .concise : .general)
  }

  /// Send message using the load balancer (for Matcha Assistant)
  private static func sendWithLoadBalancer(userMessage: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    let hasMedia = mediaItems != nil && !(mediaItems?.isEmpty ?? true)

    // Estimate token count for intelligent model selection
    let estimatedTokens = TokenEstimator.estimateTokens(userMessage: userMessage, conversationHistory: conversationHistory)

    // Select best model using load balancer with token awareness
    guard let selectedModel = ModelLoadBalancer.selectBestModel(hasMediaItems: hasMedia, estimatedTokens: estimatedTokens) else {
      print("❌ Load Balancer: No models available")
      throw LlmError.invalidResponse
    }

    print("🔧 Load Balancer: Using \(selectedModel.name)")

    do {
      // Try the selected model
      switch selectedModel.provider {
      case .openRouter:
        return try await sendOpenRouterMessage(userMessage: userMessage, model: selectedModel.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
      case .google:
        return try await sendGoogleMessage(userMessage: userMessage, model: selectedModel.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
      case .mistral:
        return try await sendMistralMessage(userMessage: userMessage, model: selectedModel.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
      case .groq:
        return try await sendGroqMessage(userMessage: userMessage, model: selectedModel.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
      default:
        throw LlmError.invalidResponse
      }
    } catch {
      print("❌ Load Balancer: Selected model failed: \(error)")

      // Mark as rate limited if applicable
      if isRateLimitError(error) {
        ModelLoadBalancer.markRateLimited(selectedModel.modelId)
      }

      // Try universal fallback, excluding the model that just failed
      return try await UniversalFallback.sendMessage(
        userMessage: userMessage,
        mediaItems: mediaItems,
        conversationHistory: conversationHistory,
        originalError: error,
        excludeModels: [selectedModel.modelId],
        systemPrompt: systemPrompt
      )
    }
  }
  
  private static func sendMessageWithProvider(userMessage: String, modelConfig: ModelConfiguration.Model, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    switch modelConfig.provider {
    case .openRouter:
      return try await sendOpenRouterMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .openai:
      return try await sendOpenAIMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .anthropic:
      return try await sendAnthropicMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .deepseek:
      return try await sendDeepSeekMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .google:
      return try await sendGoogleMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .x:
      return try await sendXMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .mistral:
      return try await sendMistralMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .perplexity:
      return try await sendPerplexityMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    case .groq:
      return try await sendGroqMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems, conversationHistory: conversationHistory, systemPrompt: systemPrompt)
    }
  }
  
  // MARK: - Rate Limit Detection
  private static func isRateLimitError(_ error: Error) -> Bool {
    if let llmError = error as? LlmError {
      switch llmError {
      case .rateLimitExceeded:
        return true
      default:
        return false
      }
    }
    
    // Check for HTTP 429 status code in URLSession errors
    if let urlError = error as? URLError {
      return urlError.code == .timedOut 
    }
    
    // Check error message for rate limit indicators
    let errorMessage = error.localizedDescription.lowercased()
    return errorMessage.contains("rate limit") || 
           errorMessage.contains("too many requests") ||
           errorMessage.contains("quota exceeded") ||
           errorMessage.contains("429")
  }
  
  // MARK: - Provider-specific Methods

  internal static func sendOpenRouterMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = openRouterAPIKey else {
      print("❌ Missing OpenRouter API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: openRouterEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Matcha Note App", forHTTPHeaderField: "HTTP-Referer")

    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build current user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: OpenRouterResponse.self)
  }
  
  internal static func sendOpenAIMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = openAIAPIKey else {
      print("❌ Missing OpenAI API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: openAIEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    // Build request body - GPT-5 models only support default temperature (1.0)
    var requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "max_completion_tokens": 8000,
    ]
    
    // Only add temperature for non-GPT-5 models
    if !model.hasPrefix("gpt-5") {
      requestBody["temperature"] = 0.7
    }

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: OpenAIResponse.self)
  }
  
  internal static func sendAnthropicMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = anthropicAPIKey else {
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: anthropicEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    
    // Build messages array
    var messages: [[String: Any]] = []
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image",
                "source": [
                  "type": "base64",
                  "media_type": "image/jpeg",
                  "data": base64Image
                ]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image",
            "source": [
              "type": "base64",
              "media_type": "image/jpeg",
              "data": base64Image
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "max_tokens": 8000,
      "system": getSystemPromptText(for: model, customPrompt: systemPrompt),
      "messages": messages
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: AnthropicResponse.self)
  }
  
  internal static func sendDeepSeekMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = deepSeekAPIKey else {
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: deepSeekEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: DeepSeekResponse.self)
  }
  
  internal static func sendGoogleMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = googleAPIKey else {
      print("❌ Missing Google API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: "\(googleEndpoint)/\(model):generateContent?key=\(apiKey)") else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Build contents array
    var contents: [[String: Any]] = []

    // Add system prompt as first user message for Google
    contents.append([
      "role": "user",
      "parts": [
        ["text": getSystemPromptText(for: model, customPrompt: systemPrompt)]
      ]
    ])
    contents.append([
      "role": "model",
      "parts": [
        ["text": "Understood. I'll follow these guidelines."]
      ]
    ])
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "model"
        var parts: [[String: Any]] = [
          ["text": message.content]
        ]
        
        // Add images if present in history
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              parts.append([
                "inline_data": [
                  "mime_type": "image/jpeg",
                  "data": base64Image
                ]
              ])
            }
          }
        }
        
        contents.append(["role": role, "parts": parts])
      }
    }
    
    // Build current message parts
    var currentParts: [[String: Any]] = [
      ["text": userMessage]
    ]
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          currentParts.append([
            "inline_data": [
              "mime_type": "image/jpeg",
              "data": base64Image
            ]
          ])
        }
      }
    }
    
    // Add current user message
    contents.append([
      "role": "user",
      "parts": currentParts
    ])
      
    let requestBody: [String: Any] = [
      "contents": contents,
      "generationConfig": [
        "temperature": 0.7,
        "maxOutputTokens": 8000
      ]
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: GoogleResponse.self)
  }
  
  internal static func sendXMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = xAPIKey else {
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: xEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: XResponse.self)
  }
  
  internal static func sendMistralMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = mistralAPIKey else {
      print("❌ Missing Mistral API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: mistralEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: MistralResponse.self)
  }
  
  internal static func sendPerplexityMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String {
    guard let apiKey = perplexityAPIKey else {
      print("❌ Missing Perplexity API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: perplexityEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]
    
    // Add conversation history if present - Perplexity requires strict alternation
    if let history = conversationHistory {
      var lastRole: String? = "system"
      
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        
        // Skip consecutive messages with the same role to maintain alternation
        if role == lastRole {
          continue
        }
        
        var content: Any = message.content
        
        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]
          
          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }
        
        messages.append(["role": role, "content": content])
        lastRole = role
      }
    }
    
    // Build user message content
    var userContent: Any = userMessage
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])
      
      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }
      
      userContent = contentArray
    }
    
    // Ensure last message in history is assistant if we have history, to maintain alternation
    let lastHistoryRole = conversationHistory?.last?.isUser == false ? "assistant" : (conversationHistory?.last?.isUser == true ? "user" : nil)
    if lastHistoryRole == "user" {
      // If last history message was user, we need to add a placeholder assistant message
      // to maintain alternation before adding the new user message
      messages.append(["role": "assistant", "content": "..."])
    }
    
    // Add current user message
    messages.append(["role": "user", "content": userContent])
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: PerplexityResponse.self)
  }

  internal static func sendGroqMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil, conversationHistory: [ChatMessage]? = nil, systemPrompt: PromptUseCase? = nil) async throws -> String{
    guard let apiKey = groqAPIKey else {
      print("❌ Missing Groq API key")
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: groqEndpoint) else {
      throw LlmError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Build messages array starting with system message
    var messages: [[String: Any]] = [
      ["role": "system", "content": getSystemPromptText(for: model, customPrompt: systemPrompt)]
    ]

    // Add conversation history if present
    if let history = conversationHistory {
      for message in history {
        let role = message.isUser ? "user" : "assistant"
        var content: Any = message.content

        // If message has media items, format as content array
        if let mediaItems = message.mediaItems, !mediaItems.isEmpty {
          var contentArray: [[String: Any]] = [
            ["type": "text", "text": message.content]
          ]

          for mediaItem in mediaItems {
            if case .image = mediaItem.type {
              let base64Image = mediaItem.data.base64EncodedString()
              contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
              ])
            }
          }
          content = contentArray
        }

        messages.append(["role": role, "content": content])
      }
    }

    // Build user message content
    var userContent: Any = userMessage

    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []

      // Add text content
      contentArray.append([
        "type": "text",
        "text": userMessage
      ])

      // Add image content
      for mediaItem in mediaItems {
        if case .image = mediaItem.type {
          let base64Image = mediaItem.data.base64EncodedString()
          contentArray.append([
            "type": "image_url",
            "image_url": [
              "url": "data:image/jpeg;base64,\(base64Image)"
            ]
          ])
        }
      }

      userContent = contentArray
    }

    // Add current user message
    messages.append(["role": "user", "content": userContent])

    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: GroqResponse.self)
  }

  // MARK: - Generic Request Handler
  private static func performRequest<T: Decodable>(request: URLRequest, responseType: T.Type) async throws -> String {
    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw LlmError.invalidResponse
      }

      if httpResponse.statusCode != 200 {
        if let errorString = String(data: data, encoding: .utf8) {
          print("API Error: \(errorString)")
        }
        
        // Check for rate limit errors
        if httpResponse.statusCode == 429 {
          throw LlmError.rateLimitExceeded
        }
        
        throw LlmError.invalidResponse
      }

      do {
        let responseObject = try JSONDecoder().decode(responseType, from: data)
        return try extractContent(from: responseObject)
      } catch {
        print("Decoding error: \(error)")
        throw LlmError.decodingFailed(error)
      }
    } catch {
      if let urlError = error as? URLError {
        print("Network error: \(urlError)")
      }
      throw LlmError.requestFailed(error)
    }
  }
  
  private static func extractContent(from response: Any) throws -> String {
    if let openRouterResponse = response as? OpenRouterResponse {
      if let message = openRouterResponse.choices.first?.message.content {
        return message
      }
    }
    
    if let openAIResponse = response as? OpenAIResponse {
      if let message = openAIResponse.choices.first?.message.content {
        return message
      }
    }
    
    if let anthropicResponse = response as? AnthropicResponse {
      if let content = anthropicResponse.content.first?.text {
        return content
      }
    }
    
    if let deepSeekResponse = response as? DeepSeekResponse {
      if let message = deepSeekResponse.choices.first?.message.content {
        return message
      }
    }
    
    if let googleResponse = response as? GoogleResponse {
      if let text = googleResponse.candidates.first?.content.parts.first?.text {
        return text
      }
    }
    
    if let xResponse = response as? XResponse {
      if let message = xResponse.choices.first?.message.content {
        return message
      }
    }
    
    if let mistralResponse = response as? MistralResponse {
      if let message = mistralResponse.choices.first?.message.content {
        return message
      }
    }
    
    if let perplexityResponse = response as? PerplexityResponse {
      if let message = perplexityResponse.choices.first?.message.content {
        return message
      }
    }

    if let groqResponse = response as? GroqResponse {
      if let message = groqResponse.choices.first?.message.content {
        return message
      }
    }

    throw LlmError.invalidResponse
  }
}


