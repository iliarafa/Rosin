import Foundation

protocol LLMStreamingService {
    func streamCompletion(
        model: String,
        systemPrompt: String,
        userContent: String,
        apiKey: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}
