import Foundation

enum LlmError: Error {
  case invalidURL
  case requestFailed(Error)
  case invalidResponse
  case decodingFailed(Error)
  case missingAPIKey

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
    }
  }
}

struct OpenRouterAPI {
  private static var apiKey: String? = nil
  private static let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"

  static func configure(apiKey: String) {
    self.apiKey = apiKey
  }

  static func sendMessage(userMessage: String, model_string: String) async throws -> String {
    guard let apiKey = apiKey else {
      throw LlmError.missingAPIKey
    }

    guard let url = URL(string: openRouterEndpoint) else {
      throw LlmError.invalidURL
    }

    // Create request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Matcha Note App", forHTTPHeaderField: "HTTP-Referer")
    
    // Get the actual model ID from the centralized configuration
    let model = ModelConfiguration.getModelId(for: model_string) ?? model_string
      
    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": "You are a helpful assistant called Matcha Assistant."],
        ["role": "user", "content": userMessage],
      ],
      "temperature": 0.7,
    ]

    // Serialize to JSON
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw LlmError.requestFailed(error)
    }

    // Send request
    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      // Check response
      guard let httpResponse = response as? HTTPURLResponse else {
        throw LlmError.invalidResponse
      }

      // Debug response
      if httpResponse.statusCode != 200 {
        if let errorString = String(data: data, encoding: .utf8) {
          print("API Error: \(errorString)")
        }
        throw LlmError.invalidResponse
      }

      // Parse response
      do {
        let responseObject = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        if let message = responseObject.choices.first?.message.content {
          return message
        } else {
          throw LlmError.invalidResponse
        }
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
