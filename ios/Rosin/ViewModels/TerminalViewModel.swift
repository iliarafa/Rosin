import Foundation
import SwiftUI

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var query = ""
    @Published var stages: [StageOutput] = []
    @Published var summary: VerificationSummary?
    @Published var isProcessing = false
    @Published var stageCount = 3
    @Published var chain: [LLMModel] = LLMModel.defaultChain3
    @Published var isAdversarialMode = false
    @Published var isLiveResearch = false
    @Published var researchStatus: ResearchStatus?

    private var pipeline: VerificationPipelineManager?

    var activeChain: [LLMModel] {
        Array(chain.prefix(stageCount))
    }

    var allComplete: Bool {
        stages.count == stageCount && stages.allSatisfy { $0.status == .complete || $0.status == .skipped }
    }

    var lastStageContent: String? {
        guard allComplete else { return nil }
        return stages.last?.content
    }

    func setup(apiKeyManager: APIKeyManager) {
        pipeline = VerificationPipelineManager(apiKeyManager: apiKeyManager)
    }

    func updateModel(at index: Int, to model: LLMModel) {
        guard index < chain.count else { return }
        chain[index] = model
    }

    func updateStageCount(_ count: Int) {
        stageCount = count
        // Ensure chain has enough models
        while chain.count < count {
            let nextModel = LLMModel.allModels.first { m in
                !chain.contains(where: { $0.id == m.id })
            } ?? LLMModel.allModels[0]
            chain.append(nextModel)
        }
    }

    func run() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        stages = []
        summary = nil
        researchStatus = nil
        isProcessing = true

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        pipeline?.run(query: trimmed, chain: activeChain, adversarialMode: isAdversarialMode, liveResearch: isLiveResearch) { [weak self] event in
            guard let self else { return }
            self.handleEvent(event)
        }
    }

    func cancel() {
        pipeline?.cancel()
        isProcessing = false
    }

    private func handleEvent(_ event: PipelineEvent) {
        switch event {
        case .researchStart:
            researchStatus = .searching

        case .researchComplete(let sourceCount, let sources):
            researchStatus = .complete(sourceCount: sourceCount, sources: sources)

        case .researchError(let error):
            researchStatus = .error(error)

        case .stageStart(let stage, let model):
            stages.append(StageOutput(
                id: stage,
                model: model,
                content: "",
                status: .streaming
            ))

        case .content(let stage, let text):
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].content += text
            }

        case .stageComplete(let stage):
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].status = .complete
                // Haptic on stage complete
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }

        case .stageRetry(let stage, let model, _):
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].content = ""
                stages[idx].model = model
                stages[idx].status = .retrying
            }

        case .stageSkipped(let stage, let error):
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].status = .skipped
                stages[idx].error = error
            }

        case .stageError(let stage, let error):
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].status = .error
                stages[idx].error = error
            } else {
                stages.append(StageOutput(
                    id: stage,
                    model: activeChain[safe: stage - 1] ?? activeChain[0],
                    content: "",
                    status: .error,
                    error: error
                ))
            }
            isProcessing = false

        case .stageAnalysis(let stage, let analysis):
            // Attach the Judge's per-stage analysis to the matching stage
            if let idx = stages.firstIndex(where: { $0.id == stage }) {
                stages[idx].analysis = analysis
            }

        case .summary(let s):
            summary = s

        case .done:
            isProcessing = false
            if let summary, allComplete {
                let historyItem = VerificationHistoryItem(
                    query: query,
                    chain: activeChain,
                    stages: stages,
                    summary: summary,
                    adversarialMode: isAdversarialMode
                )
                HistoryManager.save(historyItem)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
