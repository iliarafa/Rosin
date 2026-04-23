import Foundation

struct AccountPublic: Codable {
    let id: String
    let email: String
    let authProvider: String
    let queriesUsed: Int
    let queriesRemaining: Int
}

struct SessionResponse: Codable {
    let token: String
    let account: AccountPublic
}

enum AuthMethod {
    case apple, google, email
}

struct RosinEndpoint {
    static let baseURL = URL(string: ProcessInfo.processInfo.environment["ROSIN_API_BASE"] ?? "https://llmrosin.replit.app")!
    static func url(_ path: String) -> URL { baseURL.appendingPathComponent(path) }
}
