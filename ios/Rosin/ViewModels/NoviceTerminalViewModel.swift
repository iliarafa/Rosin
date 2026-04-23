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
    @Published var freeTierExhausted: Bool = false

    private let pipeline: VerificationPipelineManager
    private let hostedService = HostedVerificationService()
    private let chain: [LLMModel] = [
        LLMModel(provider: .anthropic, model: "claude-sonnet-4-5"),
        LLMModel(provider: .gemini, model: "gemini-2.5-flash"),
    ]

    // Per-run state (used by both BYO and hosted paths via `handle(event:)`).
    private var currentQuestion: String = ""
    private var currentStageContents: [Int: String] = [:]
    private var currentSources: [Source] = []

    init(apiKeyManager: APIKeyManager) {
        self.pipeline = VerificationPipelineManager(apiKeyManager: apiKeyManager)
    }

    func verify() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        currentQuestion = q
        currentStageContents = [:]
        currentSources = []
        phase = .verifying(status: "[ CONTACTING AIs... ]")

        pipeline.run(
            query: q,
            chain: chain,
            adversarialMode: false,
            liveResearch: true,
            autoTieBreaker: false
        ) { [weak self] event in
            self?.handle(event: event)
        }
    }

    func runHostedVerification(query q: String, token: String) async {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        currentQuestion = trimmed
        currentStageContents = [:]
        currentSources = []
        freeTierExhausted = false
        phase = .verifying(status: "[ CONTACTING AIs... ]")

        do {
            for try await payload in hostedService.stream(query: trimmed, token: token) {
                if let event = decodeHostedEvent(payload) {
                    handle(event: event)
                }
            }
        } catch let e as HostedVerificationService.HostedError {
            switch e {
            case .freeTierExhausted:
                freeTierExhausted = true
                phase = .idle
            case .notSignedIn:
                phase = .idle
            default:
                phase = .failed(e.errorDescription ?? "Verification failed")
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
        query = ""
    }

    // MARK: - Event handling

    private func handle(event: PipelineEvent) {
        switch event {
        case .researchStart:
            self.phase = .verifying(status: "[ SEARCHING THE WEB... ]")
        case .researchComplete(let count, _):
            self.phase = .verifying(status: "[ VERIFYING ... 2 AIs, \(count) sources ]")
        case .researchVerifiedSources(let results):
            self.currentSources = results.map {
                Source(title: $0.title, url: $0.url, status: $0.urlStatus.rawValue)
            }
        case .stageStart(let stage, _):
            self.phase = .verifying(status: "[ AI \(stage) THINKING... ]")
        case .content(let stage, let text):
            self.currentStageContents[stage, default: ""] += text
        case .stageError(_, let error):
            self.phase = .failed(error)
        case .summary(let summary):
            let answer = self.currentStageContents[self.chain.count]
                ?? Array(self.currentStageContents.values).last
                ?? "No answer produced."
            let verifiedCount = self.currentSources.filter { $0.status.hasPrefix("VERIFIED") }.count
            self.phase = .done(
                Result(
                    question: self.currentQuestion,
                    answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
                    trustScore: summary.trustScore,
                    aiCount: self.chain.count,
                    verifiedSourceCount: verifiedCount,
                    sources: self.currentSources
                )
            )
        default:
            break
        }
    }

    // MARK: - Hosted SSE decoding

    private func decodeHostedEvent(_ payload: String) -> PipelineEvent? {
        guard let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return nil
        }
        switch type {
        case "research_start":
            return .researchStart
        case "research_complete":
            let count = (obj["sourceCount"] as? Int) ?? 0
            let sourcesSummary = (obj["sources"] as? String) ?? ""
            // Server packs verifiedSources + summary into one `research_complete` payload.
            // Since we can only return ONE PipelineEvent, fold verifiedSources directly
            // into `currentSources` here (inlining the effect of .researchVerifiedSources).
            if let raw = obj["verifiedSources"] as? [[String: Any]] {
                self.currentSources = raw.compactMap { d in
                    guard let title = d["title"] as? String,
                          let url = d["url"] as? String else { return nil }
                    let statusStr = (d["urlStatus"] as? String) ?? URLVerificationStatus.unchecked.rawValue
                    return Source(title: title, url: url, status: statusStr)
                }
            }
            return .researchComplete(sourceCount: count, sources: sourcesSummary)
        case "research_error":
            return .researchError(error: (obj["error"] as? String) ?? "")
        case "stage_start":
            let stage = (obj["stage"] as? Int) ?? 0
            if let modelDict = obj["model"] as? [String: Any],
               let providerStr = modelDict["provider"] as? String,
               let provider = LLMProvider(rawValue: providerStr),
               let modelName = modelDict["model"] as? String {
                return .stageStart(stage: stage, model: LLMModel(provider: provider, model: modelName))
            }
            return nil
        case "stage_content":
            let stage = (obj["stage"] as? Int) ?? 0
            let content = (obj["content"] as? String) ?? ""
            return .content(stage: stage, text: content)
        case "stage_complete":
            return .stageComplete(stage: (obj["stage"] as? Int) ?? 0)
        case "stage_error":
            return .stageError(
                stage: (obj["stage"] as? Int) ?? 0,
                error: (obj["error"] as? String) ?? ""
            )
        case "summary":
            if let summaryDict = obj["summary"] as? [String: Any],
               let summaryData = try? JSONSerialization.data(withJSONObject: summaryDict),
               let summary = try? JSONDecoder().decode(VerificationSummary.self, from: summaryData) {
                return .summary(summary)
            }
            return nil
        case "done":
            return .done
        case "error":
            return .stageError(stage: 0, error: (obj["error"] as? String) ?? "Verification failed")
        default:
            // Ignore unknown types (tie_breaker_triggered, stage_analysis, verification_id).
            return nil
        }
    }
}
