import Foundation
import SwiftUI

// LLM Protocol defining common methods for all LLM providers
protocol LLM {
  func generateText(prompt: String) async throws -> String
  func getModelName() -> String
}

// Error handling for LLM API calls
enum LLMError: Error {
  case invalidResponse
  case apiError(String)
  case networkError(Error)
}

// OpenAI Implementation
class OpenAIService: LLM {
  private let apiKey: String
  private let model: String
  private let endpoint = "https://api.openai.com/v1/chat/completions"

  init(apiKey: String, model: String = "gpt-4o") {
    self.apiKey = apiKey
    self.model = model
  }

  func getModelName() -> String {
    return model
  }

  func generateText(prompt: String) async throws -> String {
    guard let url = URL(string: endpoint) else {
      throw LLMError.apiError("Invalid endpoint URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "user", "content": prompt]
      ],
      "temperature": 0.7,
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw LLMError.invalidResponse
      }

      if httpResponse.statusCode != 200 {
        let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorMessage = errorResponse?["error"] as? [String: Any]
        throw LLMError.apiError(errorMessage?["message"] as? String ?? "Unknown error")
      }

      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = json["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any],
        let content = message["content"] as? String
      {
        return content
      } else {
        throw LLMError.invalidResponse
      }
    } catch let error as LLMError {
      throw error
    } catch {
      throw LLMError.networkError(error)
    }
  }
}

// DeepSeek Implementation
class DeepSeekService: LLM {
  private let apiKey: String
  private let model: String
  private let endpoint = "https://api.deepseek.com/v1/chat/completions"

  init(apiKey: String, model: String = "deepseek-coder") {
    self.apiKey = apiKey
    self.model = model
  }

  func getModelName() -> String {
    return model
  }

  func generateText(prompt: String) async throws -> String {
    guard let url = URL(string: endpoint) else {
      throw LLMError.apiError("Invalid endpoint URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "user", "content": prompt]
      ],
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw LLMError.invalidResponse
      }

      if httpResponse.statusCode != 200 {
        let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorMessage = errorResponse?["error"] as? [String: Any]
        throw LLMError.apiError(errorMessage?["message"] as? String ?? "Unknown error")
      }

      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = json["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any],
        let content = message["content"] as? String
      {
        return content
      } else {
        throw LLMError.invalidResponse
      }
    } catch let error as LLMError {
      throw error
    } catch {
      throw LLMError.networkError(error)
    }
  }
}

// Claude (Anthropic) Implementation
class ClaudeService: LLM {
  private let apiKey: String
  private let model: String
  private let endpoint = "https://api.anthropic.com/v1/messages"

  init(apiKey: String, model: String = "claude-3-opus-20240229") {
    self.apiKey = apiKey
    self.model = model
  }

  func getModelName() -> String {
    return model
  }
  func generateText(prompt: String) async throws -> String {
    guard let url = URL(string: endpoint) else {
      throw LLMError.apiError("Invalid endpoint URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.addValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        [
          "role": "user",
          "content": [["type": "text", "text": prompt]],
        ]
      ],
      "max_tokens": 1000,
      "stream": false,
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw LLMError.invalidResponse
      }

      if httpResponse.statusCode != 200 {
        let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorMessage = errorResponse?["error"] as? [String: Any]
        throw LLMError.apiError(errorMessage?["message"] as? String ?? "Unknown error")
      }

      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let content = json["content"] as? [[String: Any]],
        let firstContent = content.first,
        let text = firstContent["text"] as? String
      {
        return text
      } else {
        throw LLMError.invalidResponse
      }
    } catch let error as LLMError {
      throw error
    } catch {
      throw LLMError.networkError(error)
    }
  }
}

// LLM Manager to handle different providers
class LLMManager {
  static let shared = LLMManager()

  private var openAIService: OpenAIService?
  private var deepSeekService: DeepSeekService?
  private var claudeService: ClaudeService?

  private init() {}

  func configureOpenAI(apiKey: String, model: String = "gpt-4o") {
    openAIService = OpenAIService(apiKey: apiKey, model: model)
  }

  func configureDeepSeek(apiKey: String, model: String = "deepseek-coder") {
    deepSeekService = DeepSeekService(apiKey: apiKey, model: model)
  }

  func configureClaude(apiKey: String, model: String = "claude-3-opus-20240229") {
    claudeService = ClaudeService(apiKey: apiKey, model: model)
  }

  func generateWithOpenAI(prompt: String) async throws -> String {
    guard let service = openAIService else {
      throw LLMError.apiError("OpenAI service not configured")
    }
    return try await service.generateText(prompt: prompt)
  }

  func generateWithDeepSeek(prompt: String) async throws -> String {
    guard let service = deepSeekService else {
      throw LLMError.apiError("DeepSeek service not configured")
    }
    return try await service.generateText(prompt: prompt)
  }

  func generateWithClaude(prompt: String) async throws -> String {
    guard let service = claudeService else {
      throw LLMError.apiError("Claude service not configured")
    }
    return try await service.generateText(prompt: prompt)
  }
}
