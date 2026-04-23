import Foundation

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let appleController = AppleAuthController()
    private let googleController = GoogleAuthController()
    private let emailClient = EmailAuthClient()

    func signInWithApple() async throws -> AccountPublic {
        let result = try await appleController.signIn()
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func signInWithGoogle() async throws -> AccountPublic {
        let result = try await googleController.signIn()
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func requestEmailCode(_ email: String) async throws {
        try await emailClient.requestCode(email: email)
    }

    func verifyEmailCode(email: String, code: String) async throws -> AccountPublic {
        let result = try await emailClient.verifyCode(email: email, code: code)
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func signOut() async throws {
        if let token = SessionStore.shared.token {
            var req = URLRequest(url: RosinEndpoint.url("/api/auth/logout"))
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        try SessionStore.shared.clear()
    }

    func fetchAccount() async throws -> AccountPublic {
        guard let token = SessionStore.shared.token else {
            throw NSError(domain: "Auth", code: 401)
        }
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/me"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Auth", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let wrap = try JSONDecoder().decode([String: AccountPublic].self, from: data)
        guard let account = wrap["account"] else { throw NSError(domain: "Auth", code: -1) }
        return account
    }
}
