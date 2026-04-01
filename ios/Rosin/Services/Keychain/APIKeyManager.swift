import Foundation
import SwiftUI

@MainActor
final class APIKeyManager: ObservableObject {
    @Published private(set) var hasKey: [LLMProvider: Bool] = [:]
    @Published private(set) var hasTavilyKey = false

    private static let tavilyKeychainKey = "tavily"

    init() {
        refreshKeyStatus()
    }

    func refreshKeyStatus() {
        for provider in LLMProvider.allCases {
            hasKey[provider] = KeychainService.load(key: provider.rawValue) != nil
        }
        hasTavilyKey = KeychainService.load(key: Self.tavilyKeychainKey) != nil
    }

    func apiKey(for provider: LLMProvider) -> String? {
        KeychainService.load(key: provider.rawValue)
    }

    func saveKey(_ key: String, for provider: LLMProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteKey(for: provider)
            return
        }
        try KeychainService.save(key: provider.rawValue, value: trimmed)
        hasKey[provider] = true
    }

    func deleteKey(for provider: LLMProvider) throws {
        try KeychainService.delete(key: provider.rawValue)
        hasKey[provider] = false
    }

    // MARK: - Tavily

    var tavilyKey: String? {
        KeychainService.load(key: Self.tavilyKeychainKey)
    }

    func saveTavilyKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteTavilyKey()
            return
        }
        try KeychainService.save(key: Self.tavilyKeychainKey, value: trimmed)
        hasTavilyKey = true
    }

    func deleteTavilyKey() throws {
        try KeychainService.delete(key: Self.tavilyKeychainKey)
        hasTavilyKey = false
    }
}
