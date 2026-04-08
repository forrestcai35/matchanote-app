import Foundation

/// Errors that can occur when interacting with LLM APIs
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
      return "Invalid URL configuration. Please check your backend URL."
    case .requestFailed(let error):
      return "Request failed: \(error.localizedDescription)"
    case .invalidResponse:
      return "Invalid response from server. Please try again."
    case .decodingFailed(let error):
      return "Failed to decode response: \(error.localizedDescription)"
    case .missingAPIKey:
      return "Authentication failed. Please sign in again."
    case .rateLimitExceeded:
      return "You've reached your daily request limit. Please upgrade to Premium or try again tomorrow."
    }
  }
}


