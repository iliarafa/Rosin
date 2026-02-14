import Foundation

enum LLMError: LocalizedError {
    case missingAPIKey(provider: String)
    case apiError(provider: String, statusCode: Int, message: String)
    case invalidURL
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Add it in Settings."
        case .apiError(let provider, let statusCode, let message):
            let truncated = message.prefix(200)
            return "\(provider) API error (\(statusCode)): \(truncated)"
        case .invalidURL:
            return "Invalid API URL"
        case .cancelled:
            return "Request cancelled"
        }
    }
}

enum LLMServiceFactory {
    static func service(for provider: LLMProvider) -> any LLMStreamingService {
        switch provider {
        case .anthropic: return AnthropicStreamingService()
        case .gemini: return GeminiStreamingService()
        case .xai: return XAIStreamingService()
        }
    }

    /// Returns a cheap/fast fallback model from a provider other than `excluding`,
    /// only if the user has an API key for that provider.
    @MainActor
    static func fallbackModel(excluding: LLMProvider, apiKeyManager: APIKeyManager) -> LLMModel? {
        // Ordered by cost/speed — cheapest first
        let candidates: [(provider: LLMProvider, model: String)] = [
            (.gemini, "gemini-2.5-flash"),
            (.xai, "grok-3-fast"),
            (.anthropic, "claude-haiku-4-5"),
        ]

        for candidate in candidates {
            if candidate.provider != excluding,
               apiKeyManager.hasKey[candidate.provider] == true {
                return LLMModel(provider: candidate.provider, model: candidate.model)
            }
        }
        return nil
    }
}
