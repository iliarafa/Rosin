import Foundation
import AuthenticationServices

@MainActor
final class AppleAuthController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<SessionResponse, Error>?

    func signIn() async throws -> SessionResponse {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: NSError(domain: "Apple", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing identity token"]))
            continuation = nil
            return
        }
        Task { [continuation] in
            do {
                var req = URLRequest(url: RosinEndpoint.url("/api/auth/apple/token"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["identityToken": identityToken])
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw NSError(domain: "Apple", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
                }
                let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
                continuation?.resume(returning: decoded)
            } catch {
                continuation?.resume(throwing: error)
            }
            await MainActor.run { self.continuation = nil }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
