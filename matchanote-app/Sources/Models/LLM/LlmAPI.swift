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
  
  // MARK: - Endpoints
  private static let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"
  private static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
  private static let anthropicEndpoint = "https://api.anthropic.com/v1/messages"
  private static let deepSeekEndpoint = "https://api.deepseek.com/v1/chat/completions"
  private static let googleEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
  private static let xEndpoint = "https://api.x.ai/v1/chat/completions"

  // MARK: - Configuration
  static func configure(openRouterAPIKey: String? = nil, 
                       openAIAPIKey: String? = nil, 
                       anthropicAPIKey: String? = nil, 
                       deepSeekAPIKey: String? = nil, 
                       googleAPIKey: String? = nil,
                       xAPIKey: String? = nil) {
    self.openRouterAPIKey = openRouterAPIKey
    self.openAIAPIKey = openAIAPIKey
    self.anthropicAPIKey = anthropicAPIKey
    self.deepSeekAPIKey = deepSeekAPIKey
    self.googleAPIKey = googleAPIKey
    self.xAPIKey = xAPIKey
  }

  static func sendMessage(userMessage: String, model_string: String, mediaItems: [MediaItem]? = nil) async throws -> String {
    print("🤖 Sending message to model: \(model_string)")
    
    guard let modelConfig = ModelConfiguration.getModelConfig(for: model_string) else {
      print("❌ Model not found: \(model_string)")
      throw LlmError.invalidResponse
    }
    
    print("🔧 Using provider: \(modelConfig.provider.displayName)")
    
    do {
      return try await sendMessageWithProvider(userMessage: userMessage, modelConfig: modelConfig, mediaItems: mediaItems)
    } catch {
      print("❌ Error with \(modelConfig.provider.displayName): \(error)")
      
      // If the primary model is "Matcha Assistant" (free model) and we hit any error, try fallback
      if model_string == "Matcha Assistant" {
        print("🔄 Error with Matcha Assistant, falling back to Gemma 3")
        return try await sendGoogleMessage(userMessage: userMessage, model: "gemma-3-27b-it", mediaItems: mediaItems)
      }
      
      throw error
    }
  }
  
  private static func sendMessageWithProvider(userMessage: String, modelConfig: ModelConfiguration.Model, mediaItems: [MediaItem]? = nil) async throws -> String {
    switch modelConfig.provider {
    case .openRouter:
      return try await sendOpenRouterMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
    case .openai:
      return try await sendOpenAIMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
    case .anthropic:
      return try await sendAnthropicMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
    case .deepseek:
      return try await sendDeepSeekMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
    case .google:
      return try await sendGoogleMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
    case .x:
      return try await sendXMessage(userMessage: userMessage, model: modelConfig.modelId, mediaItems: mediaItems)
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
      return urlError.code == .timedOut // This might need adjustment based on actual error codes
    }
    
    // Check error message for rate limit indicators
    let errorMessage = error.localizedDescription.lowercased()
    return errorMessage.contains("rate limit") || 
           errorMessage.contains("too many requests") ||
           errorMessage.contains("quota exceeded") ||
           errorMessage.contains("429")
  }
  
  // MARK: - Provider-specific Methods
  
  private static func sendOpenRouterMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax."],
        ["role": "user", "content": userContent],
      ],
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
  
  private static func sendOpenAIMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax."],
        ["role": "user", "content": userContent],
      ],
      "temperature": 0.7,
      "max_tokens": 8000,
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: OpenAIResponse.self)
  }
  
  private static func sendAnthropicMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
    
    // Build user message content
    var userContent: Any = "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax.\n\nUser: \(userMessage)"
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      var contentArray: [[String: Any]] = []
      
      // Add text content
      contentArray.append([
        "type": "text",
        "text": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax.\n\nUser: \(userMessage)"
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
      
    let requestBody: [String: Any] = [
      "model": model,
      "max_tokens": 8000,
      "messages": [
        ["role": "user", "content": userContent]
      ]
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    return try await performRequest(request: request, responseType: AnthropicResponse.self)
  }
  
  private static func sendDeepSeekMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax."],
        ["role": "user", "content": userContent],
      ],
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
  
  private static func sendGoogleMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
    
    // Build parts array
    var parts: [[String: Any]] = [
      ["text": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax.\n\nUser: \(userMessage)"]
    ]
    
    // Add images if present
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
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
      
    let requestBody: [String: Any] = [
      "contents": [
        [
          "parts": parts
        ]
      ],
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
  
  private static func sendXMessage(userMessage: String, model: String, mediaItems: [MediaItem]? = nil) async throws -> String {
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
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": "You are a helpful AI assistant. Respond naturally and conversationally. You can use **bold text** for emphasis and *italic text* for subtle emphasis. Do not introduce yourself. Keep responses concise and avoid excessive line breaks. When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax."],
        ["role": "user", "content": userContent],
      ],
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
    
    throw LlmError.invalidResponse
  }
}

// MARK: - Response Models
struct OpenRouterResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [Choice]

  struct Choice: Decodable {
    let index: Int
    let message: Message
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct Message: Decodable {
    let role: String
    let content: String
  }
}

// MARK: - OpenAI Response
struct OpenAIResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [OpenAIChoice]

  struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct OpenAIMessage: Decodable {
    let role: String
    let content: String
  }
}

// MARK: - Anthropic Response
struct AnthropicResponse: Decodable {
  let id: String
  let type: String
  let role: String
  let content: [AnthropicContent]
  let model: String
  let stopReason: String?
  let stopSequence: String?
  let usage: AnthropicUsage

  enum CodingKeys: String, CodingKey {
    case id, type, role, content, model, usage
    case stopReason = "stop_reason"
    case stopSequence = "stop_sequence"
  }
  
  struct AnthropicContent: Decodable {
    let type: String
    let text: String
  }
  
  struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
      case inputTokens = "input_tokens"
      case outputTokens = "output_tokens"
    }
  }
}

// MARK: - DeepSeek Response
struct DeepSeekResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [DeepSeekChoice]

  struct DeepSeekChoice: Decodable {
    let index: Int
    let message: DeepSeekMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct DeepSeekMessage: Decodable {
    let role: String
    let content: String
  }
}

// MARK: - Google Response
struct GoogleResponse: Decodable {
  let candidates: [GoogleCandidate]
  
  struct GoogleCandidate: Decodable {
    let content: GoogleContent
    let finishReason: String?
    let index: Int
    let safetyRatings: [GoogleSafetyRating]?
    
    enum CodingKeys: String, CodingKey {
      case content, index
      case finishReason = "finishReason"
      case safetyRatings = "safetyRatings"
    }
  }
  
  struct GoogleContent: Decodable {
    let parts: [GooglePart]
    let role: String
  }
  
  struct GooglePart: Decodable {
    let text: String
  }
  
  struct GoogleSafetyRating: Decodable {
    let category: String
    let probability: String
  }
}

// MARK: - X (Grok) Response
struct XResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [XChoice]

  struct XChoice: Decodable {
    let index: Int
    let message: XMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct XMessage: Decodable {
    let role: String
    let content: String
  }
}
