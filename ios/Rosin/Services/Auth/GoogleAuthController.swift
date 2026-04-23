import Foundation
import AuthenticationServices
import CryptoKit

enum GoogleAuthError: Error { case userCancelled, invalidCallback, network(Int) }

@MainActor
final class GoogleAuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let callbackScheme = "rosinai"
    private let callbackHost = "auth"

    func signIn() async throws -> SessionResponse {
        // 1. Generate PKCE pair
        let verifier = randomURLSafeString(length: 64)
        let challenge = sha256Base64URL(verifier)

        // 2. Ask the server for the Google auth URL (server injects our client_id + redirect_uri)
        var startReq = URLRequest(url: RosinEndpoint.url("/api/auth/google/mobile/start"))
        startReq.httpMethod = "POST"
        startReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let redirectBack = "\(callbackScheme)://\(callbackHost)/google/callback"
        startReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "redirectBack": redirectBack,
            "codeChallenge": challenge,
        ])
        let (startData, startRes) = try await URLSession.shared.data(for: startReq)
        guard let http = startRes as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.network((startRes as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: startData) as? [String: Any],
            let authURLString = json["url"] as? String,
            let authURL = URL(string: authURLString)
        else { throw GoogleAuthError.invalidCallback }

        // 3. Run ASWebAuthenticationSession to let the user authorise Google
        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError,
                       asError.code == .canceledLogin {
                        cont.resume(throwing: GoogleAuthError.userCancelled)
                    } else {
                        cont.resume(throwing: error)
                    }
                    return
                }
                guard let url else { cont.resume(throwing: GoogleAuthError.invalidCallback); return }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        // 4. Server has already exchanged the code and put token=... on the callback URL
        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { throw GoogleAuthError.invalidCallback }

        // 5. Use the token to fetch /api/auth/me to hydrate the account
        var meReq = URLRequest(url: RosinEndpoint.url("/api/auth/me"))
        meReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (meData, meRes) = try await URLSession.shared.data(for: meReq)
        guard let mh = meRes as? HTTPURLResponse, (200..<300).contains(mh.statusCode) else {
            throw GoogleAuthError.network((meRes as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let accountWrap = try JSONDecoder().decode([String: AccountPublic].self, from: meData)
        guard let account = accountWrap["account"] else { throw GoogleAuthError.invalidCallback }
        return SessionResponse(token: token, account: account)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }

    private func randomURLSafeString(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private func sha256Base64URL(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
