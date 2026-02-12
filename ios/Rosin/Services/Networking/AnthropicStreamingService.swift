import Foundation

struct AnthropicStreamingService: LLMStreamingService {
    func streamCompletion(
        model: String,
        systemPrompt: String,
        userContent: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = URL(string: "https://api.anthropic.com/v1/messages")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 2048,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": [
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
                            provider: "Anthropic",
                            statusCode: httpResponse.statusCode,
                            message: errorBody
                        )
                    }

                    let decoder = JSONDecoder()
                    for try await payload in SSELineParser.parse(bytes: bytes) {
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let event = try? decoder.decode(AnthropicStreamEvent.self, from: data) {
                            if event.type == "content_block_delta",
                               let text = event.delta?.text, !text.isEmpty {
                                continuation.yield(text)
                            }
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
