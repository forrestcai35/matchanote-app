// MARK: - Perplexity Response
struct PerplexityResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [PerplexityChoice]

  struct PerplexityChoice: Decodable {
    let index: Int
    let message: PerplexityMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct PerplexityMessage: Decodable {
    let role: String
    let content: String
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

// MARK: - Mistral Response
struct MistralResponse: Decodable {
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [MistralChoice]

  struct MistralChoice: Decodable {
    let index: Int
    let message: MistralMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct MistralMessage: Decodable {
    let role: String
    let content: String
  }
}