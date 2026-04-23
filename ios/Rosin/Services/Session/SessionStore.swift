import Foundation

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()
    @Published private(set) var token: String?

    private static let keychainKey = "rosin_session_token"

    init() {
        self.token = KeychainService.load(key: Self.keychainKey)
    }

    func set(_ newToken: String) throws {
        try KeychainService.save(key: Self.keychainKey, value: newToken)
        self.token = newToken
    }

    func clear() throws {
        try KeychainService.delete(key: Self.keychainKey)
        self.token = nil
    }

    var isSignedIn: Bool { token != nil }
}
