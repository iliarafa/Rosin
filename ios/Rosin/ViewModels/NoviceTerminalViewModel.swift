import Foundation
import SwiftUI

@MainActor
final class NoviceTerminalViewModel: ObservableObject {
    enum Phase {
        case idle
        case verifying(status: String)
        case done(Result)
        case failed(String)
    }

    struct Source: Identifiable {
        let id = UUID()
        let title: String
        let url: String
        let status: String
    }

    struct Result {
        let question: String
        let answer: String
        let trustScore: Int?
        let aiCount: Int
        let verifiedSourceCount: Int
        let sources: [Source]
    }

    @Published var query: String = ""
    @Published var phase: Phase = .idle

    private let pipeline: VerificationPipelineManager
    private let chain: [LLMModel] = [
        LLMModel(provider: .anthropic, model: "claude-sonnet-4-5"),
        LLMModel(provider: .gemini, model: "gemini-2.5-flash"),
    ]

    init(apiKeyManager: APIKeyManager) {
        self.pipeline = VerificationPipelineManager(apiKeyManager: apiKeyManager)
    }

    func verify() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        phase = .verifying(status: "[ CONTACTING AIs... ]")
        var stageContents: [Int: String] = [:]
        var sources: [Source] = []

        pipeline.run(
            query: q,
            chain: chain,
            adversarialMode: false,
            liveResearch: true,
            autoTieBreaker: false
        ) { [weak self] event in
            guard let self else { return }
            switch event {
            case .researchStart:
                self.phase = .verifying(status: "[ SEARCHING THE WEB... ]")
            case .researchComplete(let count, _):
                self.phase = .verifying(status: "[ VERIFYING ... 2 AIs, \(count) sources ]")
            case .researchVerifiedSources(let results):
                sources = results.map {
                    Source(title: $0.title, url: $0.url, status: $0.urlStatus.rawValue)
                }
            case .stageStart(let stage, _):
                self.phase = .verifying(status: "[ AI \(stage) THINKING... ]")
            case .content(let stage, let text):
                stageContents[stage, default: ""] += text
            case .stageError(_, let error):
                self.phase = .failed(error)
            case .summary(let summary):
                let answer = stageContents[self.chain.count]
                    ?? Array(stageContents.values).last
                    ?? "No answer produced."
                let verifiedCount = sources.filter { $0.status.hasPrefix("VERIFIED") }.count
                self.phase = .done(
                    Result(
                        question: q,
                        answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
                        trustScore: summary.trustScore,
                        aiCount: self.chain.count,
                        verifiedSourceCount: verifiedCount,
                        sources: sources
                    )
                )
            default:
                break
            }
        }
    }

    func reset() {
        phase = .idle
        query = ""
    }
}
