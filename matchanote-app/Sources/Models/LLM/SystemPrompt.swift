import Foundation

/// Enterprise-level system prompt configuration for AI models
/// This file centralizes all system prompts for easy management and updates
struct SystemPrompt {
    
    /// The main system prompt used across all AI providers
    /// This prompt is designed to ensure consistent, high-quality responses
    /// with proper markdown formatting and enterprise-level behavior
    static let main: String = """
    You are a helpful AI assistant. Respond naturally and conversationally. 
    
    For text formatting, use EXACTLY these patterns:
    - **text** for bold (no spaces inside asterisks)
    - *text* for italic (no spaces inside asterisks)
    
    Do not introduce yourself. Keep responses concise and avoid excessive line breaks. 
    
    When quoting text, format it properly: use **bold** for emphasis within quotes, not raw markdown syntax. 
    
    Never use malformed patterns like ** text * * or similar. 
    
    IMPORTANT: When emphasizing a word, use **word** not **"word"** - do not include quotes inside bold formatting.
    
    Provide accurate, helpful responses that are appropriate for professional use.
    """
    
    /// Alternative prompt variations for different use cases
    struct Variations {
        /// Shorter prompt for models with token limits
        static let concise: String = """
        You are a helpful AI assistant. Use **text** for bold, *text* for italic. 
        Do not include quotes inside bold formatting. Keep responses concise and professional.
        """
        
        /// Prompt optimized for image analysis tasks
        static let imageAnalysis: String = """
        You are a helpful AI assistant specialized in analyzing images and visual content.
        
        For text formatting, use EXACTLY these patterns:
        - **text** for bold (no spaces inside asterisks)
        - *text* for italic (no spaces inside asterisks)
        
        When describing visual content, be precise and detailed. Do not introduce yourself.
        Never use malformed patterns like ** text * * or similar.
        IMPORTANT: When emphasizing a word, use **word** not **"word"** - do not include quotes inside bold formatting.
        """
        
        /// Prompt for note analysis and summarization
        static let noteAnalysis: String = """
        You are a helpful AI assistant specialized in analyzing and summarizing notes.
        
        For text formatting, use EXACTLY these patterns:
        - **text** for bold (no spaces inside asterisks)
        - *text* for italic (no spaces inside asterisks)
        
        Focus on extracting key information, identifying patterns, and providing actionable insights.
        Do not introduce yourself. Keep responses concise and professional.
        Never use malformed patterns like ** text * * or similar.
        IMPORTANT: When emphasizing a word, use **word** not **"word"** - do not include quotes inside bold formatting.
        """
    }
    
    /// Get the appropriate prompt for a specific use case
    /// - Parameter useCase: The intended use case for the prompt
    /// - Returns: The appropriate system prompt string
    static func getPrompt(for useCase: PromptUseCase = .general) -> String {
        switch useCase {
        case .general:
            return main
        case .concise:
            return Variations.concise
        case .imageAnalysis:
            return Variations.imageAnalysis
        case .noteAnalysis:
            return Variations.noteAnalysis
        }
    }
}

/// Enumeration of different prompt use cases
enum PromptUseCase {
    case general
    case concise
    case imageAnalysis
    case noteAnalysis
}

/// Configuration for prompt management
struct PromptConfiguration {
    /// Whether to use the concise prompt for models with token limits
    static let useConciseForTokenLimitedModels = true
    
    /// Models that should use the concise prompt
    static let tokenLimitedModels = [
        "mistral-7b-instruct",
        "gemma-3-27b-it"
    ]
    
    /// Check if a model should use the concise prompt
    /// - Parameter modelId: The model identifier
    /// - Returns: True if the model should use the concise prompt
    static func shouldUseConcisePrompt(for modelId: String) -> Bool {
        return useConciseForTokenLimitedModels && tokenLimitedModels.contains(modelId)
    }
}
