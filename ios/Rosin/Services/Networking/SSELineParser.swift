import Foundation

struct SSELineParser {
    /// Consumes URLSession async bytes and yields SSE "data:" payloads as strings.
    /// Filters out empty lines, comments, and the "data: [DONE]" sentinel.
    /// Uses AsyncBytes.lines for correct UTF-8 decoding (handles multi-byte chars like —).
    static func parse(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let payload = String(line.dropFirst(6))
                            if payload == "[DONE]" {
                                break
                            }
                            continuation.yield(payload)
                        }
                        // Ignore non-data lines (event:, id:, retry:, comments, empty)
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
