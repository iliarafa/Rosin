import Foundation

struct GeminiStreamingService: LLMStreamingService {
    func streamCompletion(
        model: String,
        systemPrompt: String,
        userContent: String,
        apiKey: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Gemini uses API key as URL parameter and SSE via alt=sse
                    let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
                    guard let url = URL(string: urlString) else {
                        throw LLMError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // Gemini: system prompt concatenated into user message (same as web app)
                    let combinedContent = "\(systemPrompt)\n\n\(userContent)"
                    let body: [String: Any] = [
                        "contents": [
                            [
                                "role": "user",
                                "parts": [["text": combinedContent]]
                            ]
                        ],
                        "generationConfig": [
                            "maxOutputTokens": maxTokens
                        ]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                        }
                        throw LLMError.apiError(
                            provider: "Gemini",
                            statusCode: httpResponse.statusCode,
                            message: errorBody
                        )
                    }

                    let decoder = JSONDecoder()
                    for try await payload in SSELineParser.parse(bytes: bytes) {
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let chunk = try? decoder.decode(GeminiStreamChunk.self, from: data),
                           let text = chunk.candidates?.first?.content?.parts?.first?.text,
                           !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
