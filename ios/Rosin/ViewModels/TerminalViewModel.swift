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

    private var pipeline: VerificationPipelineManager?

    var activeChain: [LLMModel] {
        Array(chain.prefix(stageCount))
    }

    var allComplete: Bool {
        stages.count == stageCount && stages.allSatisfy { $0.status == .complete }
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
        isProcessing = true

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        pipeline?.run(query: trimmed, chain: activeChain) { [weak self] event in
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

        case .summary(let s):
            summary = s

        case .done:
            isProcessing = false
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
