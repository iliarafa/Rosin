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
}
