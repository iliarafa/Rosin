import Foundation
import SwiftUI

@MainActor
final class APIKeyManager: ObservableObject {
    @Published private(set) var hasKey: [LLMProvider: Bool] = [:]
    @Published private(set) var hasTavilyKey = false
    @Published private(set) var hasExaKey = false

    private static let tavilyKeychainKey = "tavily"
    private static let exaKeychainKey = "exa"

    init() {
        refreshKeyStatus()
    }

    func refreshKeyStatus() {
        for provider in LLMProvider.allCases {
            hasKey[provider] = KeychainService.load(key: provider.rawValue) != nil
        }
        hasTavilyKey = KeychainService.load(key: Self.tavilyKeychainKey) != nil
        hasExaKey = KeychainService.load(key: Self.exaKeychainKey) != nil
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

    // MARK: - Exa

    var exaKey: String? {
        KeychainService.load(key: Self.exaKeychainKey)
    }

    func saveExaKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteExaKey()
            return
        }
        try KeychainService.save(key: Self.exaKeychainKey, value: trimmed)
        hasExaKey = true
    }

    func deleteExaKey() throws {
        try KeychainService.delete(key: Self.exaKeychainKey)
        hasExaKey = false
    }
}
