import Foundation
import SwiftUI

@MainActor
final class APIKeyManager: ObservableObject {
    @Published private(set) var hasKey: [LLMProvider: Bool] = [:]

    init() {
        refreshKeyStatus()
    }

    func refreshKeyStatus() {
        for provider in LLMProvider.allCases {
            hasKey[provider] = KeychainService.load(key: provider.rawValue) != nil
        }
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
}
