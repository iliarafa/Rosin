import Foundation

struct SSELineParser {
    /// Consumes URLSession async bytes and yields SSE "data:" payloads as strings.
    /// Filters out empty lines, comments, and the "data: [DONE]" sentinel.
    static func parse(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = ""
                do {
                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        if char == "\n" {
                            let line = buffer
                            buffer = ""
                            if line.hasPrefix("data: ") {
                                let payload = String(line.dropFirst(6))
                                if payload == "[DONE]" {
                                    break
                                }
                                continuation.yield(payload)
                            }
                            // Ignore non-data lines (event:, id:, retry:, comments, empty)
                        } else {
                            buffer.append(char)
                        }
                    }
                    // Handle any remaining data in buffer
                    if !buffer.isEmpty && buffer.hasPrefix("data: ") {
                        let payload = String(buffer.dropFirst(6))
                        if payload != "[DONE]" {
                            continuation.yield(payload)
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
