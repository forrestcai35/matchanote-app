import Foundation

/// Secure LLM API client that proxies all requests through your backend
/// This ensures API keys are never exposed in the iOS app bundle
struct SecureLlmAPI {
  
  // MARK: - Configuration
  private static let llmEndpoint = "/api/llm"

  /// Get the backend base URL from environment
  private static func getBackendURL() throws -> String {
    // Try Info.plist first (production), then environment variables (development)
    guard let url = Bundle.main.object(forInfoDictionaryKey: "PUBLIC_APP_URL") as? String
            ?? EnvironmentManager.shared.get("PUBLIC_APP_URL") else {
      print("❌ SecureLlmAPI: PUBLIC_APP_URL not found in environment")
      throw LlmError.invalidURL
    }
    return url
  }

  /// Get the current user's auth token from Supabase
  private static func getAuthToken() async throws -> String {
    do {
      // Get current session from Supabase
      let session = try await supabase.auth.session
      print("✅ SecureLlmAPI: Auth token obtained")
      return session.accessToken
    } catch {
      print("❌ SecureLlmAPI: Failed to get auth token: \(error.localizedDescription)")
      throw LlmError.missingAPIKey
    }
  }

  // MARK: - Main API Method

  /// Send a message to an LLM via your secure backend
  /// - Parameters:
  ///   - userMessage: The user's message
  ///   - model: The model identifier (e.g., "gpt-4o", "claude-3-5-sonnet-20241022")
  ///   - conversationHistory: Optional conversation history
  ///   - systemPrompt: Optional system prompt
  ///   - mediaItems: Optional media items (images/files) to include
  ///   - maxTokens: Maximum tokens to generate (default: 4096)
  ///   - temperature: Temperature setting (default: 0.7)
  /// - Returns: The AI response text
  static func sendMessage(
    userMessage: String,
    model: String,
    conversationHistory: [ChatMessage]? = nil,
    systemPrompt: PromptUseCase? = nil,
    mediaItems: [MediaItem]? = nil,
    maxTokens: Int = 4096,
    temperature: Double = 0.7
  ) async throws -> String {

    // 1. Get auth token
    let authToken = try await getAuthToken()

    // 2. Build messages array
    var messages: [[String: Any]] = []

    // Add system prompt if provided
    if let systemPrompt = systemPrompt {
      let promptText = SystemPrompt.getPrompt(for: systemPrompt)
      messages.append([
        "role": "system",
        "content": promptText
      ])
    }

    // Add conversation history
    if let history = conversationHistory {
      for msg in history {
        messages.append([
          "role": msg.isUser ? "user" : "assistant",
          "content": msg.content
        ])
      }
    }

    // Add current user message with optional media items
    if let mediaItems = mediaItems, !mediaItems.isEmpty {
      // Build content array with text and images
      var contentArray: [[String: Any]] = [
        [
          "type": "text",
          "text": userMessage
        ]
      ]

      // Add images as base64-encoded content
      for mediaItem in mediaItems {
        switch mediaItem.type {
        case .image:
          // Encode to base64 without line breaks for maximum compatibility
          let base64String = mediaItem.data.base64EncodedString(options: [])
          contentArray.append([
            "type": "image",
            "source": [
              "type": "base64",
              "media_type": "image/jpeg",
              "data": base64String
            ]
          ])
        case .file:
          // Files not yet supported, skip
          print("⚠️ Warning: File media items not yet supported in SecureLlmAPI")
        }
      }

      messages.append([
        "role": "user",
        "content": contentArray
      ])
    } else {
      // Text-only message
      messages.append([
        "role": "user",
        "content": userMessage
      ])
    }

    // 3. Build request body
    let requestBody: [String: Any] = [
      "model": model,
      "messages": messages,
      "max_tokens": maxTokens,
      "temperature": temperature
    ]

    // 4. Create URL request
    let backendURL = try getBackendURL()
    let fullURL = "\(backendURL)\(llmEndpoint)"

    guard let url = URL(string: fullURL) else {
      print("❌ SecureLlmAPI: Invalid URL constructed: \(fullURL)")
      throw LlmError.invalidURL
    }

    print("🌐 SecureLlmAPI: Sending request to \(fullURL)")

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 120 // 2 minute timeout for long generations

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    // 5. Make the request
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw LlmError.invalidResponse
    }

    // 6. Handle response
    switch httpResponse.statusCode {
    case 200:
      // Success - parse response
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? String else {
        print("❌ SecureLlmAPI: Failed to parse response JSON")
        if let dataString = String(data: data, encoding: .utf8) {
          print("Response data: \(dataString.prefix(200))")
        }
        throw LlmError.decodingFailed(NSError(domain: "SecureLlmAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]))
      }
      print("✅ SecureLlmAPI: Response received (\(content.count) chars)")
      return content

    case 401:
      print("❌ SecureLlmAPI: Authentication failed (401)")
      throw LlmError.missingAPIKey // Auth failure

    case 429:
      print("❌ SecureLlmAPI: Rate limit exceeded (429)")
      throw LlmError.rateLimitExceeded

    case 403:
      // Quota/permission error
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let errorMessage = json["error"] as? String {
        print("❌ SecureLlmAPI: Permission denied (403): \(errorMessage)")
        throw LlmError.requestFailed(NSError(domain: "SecureLlmAPI", code: 403, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
      }
      print("❌ SecureLlmAPI: Permission denied (403)")
      throw LlmError.requestFailed(NSError(domain: "SecureLlmAPI", code: 403, userInfo: [NSLocalizedDescriptionKey: "Permission denied"]))

    default:
      // Try to get error message from response
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let errorMessage = json["error"] as? String {
        print("❌ SecureLlmAPI: Request failed (\(httpResponse.statusCode)): \(errorMessage)")
        throw LlmError.requestFailed(NSError(domain: "SecureLlmAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
      }
      print("❌ SecureLlmAPI: Request failed (\(httpResponse.statusCode))")
      throw LlmError.invalidResponse
    }
  }

  // MARK: - Helper method for existing code integration

  /// Sends a message using the same signature as your existing LlmAPI
  static func sendMessageCompat(
    userMessage: String,
    model_string: String,
    mediaItems: [MediaItem]? = nil,
    conversationHistory: [ChatMessage]? = nil,
    systemPrompt: PromptUseCase? = nil
  ) async throws -> String {

    // Get the model ID from ModelConfiguration
    guard let modelId = ModelConfiguration.getModelId(for: model_string) else {
      throw LlmError.invalidResponse
    }

    return try await sendMessage(
      userMessage: userMessage,
      model: modelId,
      conversationHistory: conversationHistory,
      systemPrompt: systemPrompt,
      mediaItems: mediaItems
    )
  }
}

// MARK: - Extension for streaming support
extension SecureLlmAPI {
  /// Stream a message from an LLM via your secure backend
  /// - Parameters:
  ///   - userMessage: The user's message
  ///   - model: The model identifier
  ///   - conversationHistory: Optional conversation history
  ///   - systemPrompt: Optional system prompt
  ///   - mediaItems: Optional media items (images/files) to include
  ///   - maxTokens: Maximum tokens to generate (default: 4096)
  ///   - temperature: Temperature setting (default: 0.7)
  /// - Returns: An async throwing stream of text chunks
  static func streamMessage(
    userMessage: String,
    model: String,
    conversationHistory: [ChatMessage]? = nil,
    systemPrompt: PromptUseCase? = nil,
    mediaItems: [MediaItem]? = nil,
    maxTokens: Int = 4096,
    temperature: Double = 0.7
  ) -> AsyncThrowingStream<String, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          // 1. Get auth token
          let authToken = try await getAuthToken()

          // 2. Build messages array
          var messages: [[String: Any]] = []

          // Add system prompt if provided
          if let systemPrompt = systemPrompt {
            let promptText = SystemPrompt.getPrompt(for: systemPrompt)
            messages.append([
              "role": "system",
              "content": promptText
            ])
          }

          // Add conversation history
          if let history = conversationHistory {
            for msg in history {
              messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
              ])
            }
          }

          // Add current user message with optional media items
          if let mediaItems = mediaItems, !mediaItems.isEmpty {
            // Build content array with text and images
            var contentArray: [[String: Any]] = [
              [
                "type": "text",
                "text": userMessage
              ]
            ]

            // Add images as base64-encoded content
            for mediaItem in mediaItems {
              switch mediaItem.type {
              case .image:
                // Encode to base64 without line breaks for maximum compatibility
                let base64String = mediaItem.data.base64EncodedString(options: [])
                contentArray.append([
                  "type": "image",
                  "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64String
                  ]
                ])
              case .file:
                print("⚠️ Warning: File media items not yet supported in SecureLlmAPI streaming")
              }
            }

            messages.append([
              "role": "user",
              "content": contentArray
            ])
          } else {
            // Text-only message
            messages.append([
              "role": "user",
              "content": userMessage
            ])
          }

          // 3. Build request body with streaming enabled
          let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "stream": true
          ]

          // 4. Create URL request
          let backendURL = try getBackendURL()
          let fullURL = "\(backendURL)\(llmEndpoint)"
          
          guard let url = URL(string: fullURL) else {
            print("❌ SecureLlmAPI Stream: Invalid URL constructed: \(fullURL)")
            throw LlmError.invalidURL
          }

          print("🌐 SecureLlmAPI Stream: Connecting to \(fullURL)")

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.timeoutInterval = 120

          request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

          // 5. Make streaming request
          let (bytes, response) = try await URLSession.shared.bytes(for: request)

          guard let httpResponse = response as? HTTPURLResponse else {
            throw LlmError.invalidResponse
          }

          guard httpResponse.statusCode == 200 else {
            // Handle error responses
            print("❌ SecureLlmAPI Stream: HTTP \(httpResponse.statusCode)")
            switch httpResponse.statusCode {
            case 401:
              throw LlmError.missingAPIKey
            case 429:
              throw LlmError.rateLimitExceeded
            case 403:
              throw LlmError.requestFailed(NSError(domain: "SecureLlmAPI", code: 403, userInfo: [NSLocalizedDescriptionKey: "Permission denied or quota exceeded"]))
            default:
              throw LlmError.requestFailed(NSError(domain: "SecureLlmAPI", code: httpResponse.statusCode))
            }
          }

          print("✅ SecureLlmAPI Stream: Connected, receiving chunks...")

          // 6. Parse SSE stream
      
          for try await line in bytes.lines {
            // SSE format: "data: {...}"
            if line.hasPrefix("data: ") {
              let data = String(line.dropFirst(6)) // Remove "data: " prefix
              
              // Check for done signal
              if data == "[DONE]" {
                continuation.finish()
                return
              }

              // Parse JSON chunk
              if let jsonData = data.data(using: .utf8),
                 let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                 let content = json["content"] as? String {
                continuation.yield(content)
              }
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  /// Streaming compatibility method for existing code
  static func streamMessageCompat(
    userMessage: String,
    model_string: String,
    mediaItems: [MediaItem]? = nil,
    conversationHistory: [ChatMessage]? = nil,
    systemPrompt: PromptUseCase? = nil
  ) -> AsyncThrowingStream<String, Error> {

    return AsyncThrowingStream { continuation in
      Task {
        do {
          // Get the model ID from ModelConfiguration
          guard let modelId = ModelConfiguration.getModelId(for: model_string) else {
            throw LlmError.invalidResponse
          }

          // Stream the message
          let stream = streamMessage(
            userMessage: userMessage,
            model: modelId,
            conversationHistory: conversationHistory,
            systemPrompt: systemPrompt,
            mediaItems: mediaItems
          )

          // Forward chunks from the inner stream
          for try await chunk in stream {
            continuation.yield(chunk)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
