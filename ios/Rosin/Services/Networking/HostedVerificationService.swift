import Foundation

/// Streams the server-side 2-stage novice pipeline from POST /api/verify/hosted.
/// Emits events parsed from the shared SSE format via SSELineParser.
actor HostedVerificationService {
    enum HostedError: LocalizedError {
        case notSignedIn
        case freeTierExhausted
        case rateLimited(retryAfterMs: Int?)
        case network(Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Not signed in"
            case .freeTierExhausted: return "Free tier exhausted"
            case .rateLimited(let ms):
                if let ms { return "Slow down — try again in \(ms/1000)s" }
                return "Rate limited"
            case .network(let c): return "Server error (\(c))"
            }
        }
    }

    /// Returns an AsyncThrowingStream of raw SSE `data:` payloads for the caller to JSON-decode per event.
    func stream(query: String, token: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: RosinEndpoint.url("/api/verify/hosted"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw HostedError.network(-1)
                    }
                    if http.statusCode == 401 { throw HostedError.notSignedIn }
                    if http.statusCode == 402 { throw HostedError.freeTierExhausted }
                    if http.statusCode == 429 {
                        throw HostedError.rateLimited(retryAfterMs: nil)
                    }
                    if !(200..<300).contains(http.statusCode) {
                        throw HostedError.network(http.statusCode)
                    }

                    for try await payload in SSELineParser.parse(bytes: bytes) {
                        continuation.yield(payload)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
