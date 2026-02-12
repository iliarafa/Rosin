import Foundation

// MARK: - Anthropic Streaming Types

struct AnthropicStreamEvent: Decodable {
    let type: String
    let delta: AnthropicDelta?
}

struct AnthropicDelta: Decodable {
    let type: String?
    let text: String?
}

// MARK: - Gemini Streaming Types

struct GeminiStreamChunk: Decodable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContent?
}

struct GeminiContent: Decodable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Decodable {
    let text: String?
}

// MARK: - xAI / OpenAI-compatible Streaming Types

struct OpenAIStreamChunk: Decodable {
    let choices: [OpenAIStreamChoice]?
}

struct OpenAIStreamChoice: Decodable {
    let delta: OpenAIStreamDelta?
}

struct OpenAIStreamDelta: Decodable {
    let content: String?
}
