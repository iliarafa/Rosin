import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var account: AccountPublic?
    @Published var isSigningIn = false
    @Published var error: String?

    var isSignedIn: Bool { account != nil }
    var queriesRemaining: Int { account?.queriesRemaining ?? 0 }

    func hydrate() async {
        guard SessionStore.shared.isSignedIn else { account = nil; return }
        do {
            account = try await AuthService.shared.fetchAccount()
        } catch {
            account = nil
            try? SessionStore.shared.clear()
        }
    }

    func signInWithApple() async {
        await perform { try await AuthService.shared.signInWithApple() }
    }

    func signInWithGoogle() async {
        await perform { try await AuthService.shared.signInWithGoogle() }
    }

    func requestEmailCode(_ email: String) async throws {
        try await AuthService.shared.requestEmailCode(email)
    }

    func verifyEmailCode(email: String, code: String) async {
        await perform { try await AuthService.shared.verifyEmailCode(email: email, code: code) }
    }

    func signOut() async {
        try? await AuthService.shared.signOut()
        account = nil
    }

    private func perform(_ op: @Sendable () async throws -> AccountPublic) async {
        isSigningIn = true
        error = nil
        defer { isSigningIn = false }
        do {
            account = try await op()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed"
        }
    }
}
