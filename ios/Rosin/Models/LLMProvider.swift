import Foundation

enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case anthropic
    case gemini
    case xai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .xai: return "xAI/Grok"
        }
    }

    var shortName: String {
        switch self {
        case .anthropic: return "Claude"
        case .gemini: return "Gemini"
        case .xai: return "Grok"
        }
    }

    var models: [String] {
        switch self {
        case .anthropic: return ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-opus-4-5"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .xai: return ["grok-3", "grok-3-fast"]
        }
    }

    var apiKeyURL: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        case .xai: return URL(string: "https://console.x.ai/team/default/api-keys")!
        }
    }
}

struct LLMModel: Equatable, Codable, Identifiable {
    let provider: LLMProvider
    let model: String

    var id: String { "\(provider.rawValue):\(model)" }

    var displayLabel: String {
        "\(provider.displayName) - \(model)"
    }
}

extension LLMModel {
    static let allModels: [LLMModel] = LLMProvider.allCases.flatMap { provider in
        provider.models.map { LLMModel(provider: provider, model: $0) }
    }

    static let defaultChain3: [LLMModel] = [
        LLMModel(provider: .anthropic, model: "claude-sonnet-4-5"),
        LLMModel(provider: .gemini, model: "gemini-2.5-pro"),
        LLMModel(provider: .xai, model: "grok-3"),
    ]

    static let defaultChain2: [LLMModel] = [
        LLMModel(provider: .anthropic, model: "claude-sonnet-4-5"),
        LLMModel(provider: .gemini, model: "gemini-2.5-pro"),
    ]
}
