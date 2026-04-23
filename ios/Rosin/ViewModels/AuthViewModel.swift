import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var account: AccountPublic?
    @Published var isSigningIn = false
    @Published var error: String?
    @Published var isHydrating: Bool = false

    var isSignedIn: Bool { account != nil }
    var queriesRemaining: Int { account?.queriesRemaining ?? 0 }

    func hydrate() async {
        error = nil
        guard SessionStore.shared.isSignedIn else { account = nil; return }
        isHydrating = true
        defer { isHydrating = false }
        do {
            account = try await AuthService.shared.fetchAccount()
        } catch {
            account = nil
            try? SessionStore.shared.clear()
        }
    }

    /// Refresh the current account from the server without hydration spinner.
    /// Use after successful hosted verification to update queriesRemaining.
    func refreshAccount() async {
        guard SessionStore.shared.isSignedIn else { return }
        if let fresh = try? await AuthService.shared.fetchAccount() {
            account = fresh
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
        error = nil
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
