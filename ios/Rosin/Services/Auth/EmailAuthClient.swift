import Foundation

enum EmailAuthError: LocalizedError {
    case network(Int)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .network(let c): return "Server error (\(c))"
        case .invalidResponse: return "Unexpected server response"
        }
    }
}

struct EmailAuthClient {
    func requestCode(email: String) async throws {
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/email/request"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw EmailAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmailAuthError.network(http.statusCode) }
    }

    func verifyCode(email: String, code: String) async throws -> SessionResponse {
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/email/verify"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EmailAuthError.network((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(SessionResponse.self, from: data)
    }
}
