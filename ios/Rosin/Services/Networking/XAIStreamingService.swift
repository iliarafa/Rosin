import Foundation

struct XAIStreamingService: LLMStreamingService {
    func streamCompletion(
        model: String,
        systemPrompt: String,
        userContent: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = URL(string: "https://api.x.ai/v1/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "max_tokens": 2048,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": userContent]
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
                            provider: "xAI",
                            statusCode: httpResponse.statusCode,
                            message: errorBody
                        )
                    }

                    let decoder = JSONDecoder()
                    for try await payload in SSELineParser.parse(bytes: bytes) {
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let chunk = try? decoder.decode(OpenAIStreamChunk.self, from: data),
                           let text = chunk.choices?.first?.delta?.content,
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
