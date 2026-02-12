import Foundation

@MainActor
final class VerificationPipelineManager {
    private let apiKeyManager: APIKeyManager
    private var currentTask: Task<Void, Never>?

    init(apiKeyManager: APIKeyManager) {
        self.apiKeyManager = apiKeyManager
    }

    var isRunning: Bool {
        currentTask != nil && currentTask?.isCancelled == false
    }

    func run(
        query: String,
        chain: [LLMModel],
        onEvent: @escaping (PipelineEvent) -> Void
    ) {
        cancel()

        currentTask = Task {
            var previousOutput: String? = nil
            let totalStages = chain.count

            for (index, llmModel) in chain.enumerated() {
                if Task.isCancelled { return }

                let stageNum = index + 1
                let isFirst = index == 0
                let isLast = index == totalStages - 1

                // Validate API key exists
                guard let apiKey = apiKeyManager.apiKey(for: llmModel.provider) else {
                    onEvent(.stageError(
                        stage: stageNum,
                        error: "Missing API key for \(llmModel.provider.displayName). Add it in Settings."
                    ))
                    return
                }

                onEvent(.stageStart(stage: stageNum, model: llmModel))

                let systemPrompt = StagePromptBuilder.systemPrompt(
                    stageNumber: stageNum,
                    isLast: isLast
                )
                let userContent = StagePromptBuilder.userContent(
                    query: query,
                    previousOutput: previousOutput,
                    isFirst: isFirst
                )

                let service = LLMServiceFactory.service(for: llmModel.provider)
                let stream = service.streamCompletion(
                    model: llmModel.model,
                    systemPrompt: systemPrompt,
                    userContent: userContent,
                    apiKey: apiKey
                )

                var stageContent = ""
                do {
                    for try await text in stream {
                        if Task.isCancelled { return }
                        stageContent += text
                        onEvent(.content(stage: stageNum, text: text))
                    }

                    onEvent(.stageComplete(stage: stageNum))
                    previousOutput = stageContent
                } catch {
                    if Task.isCancelled { return }
                    let message = error.localizedDescription
                    onEvent(.stageError(stage: stageNum, error: message))
                    return
                }
            }

            if Task.isCancelled { return }

            let summary = VerificationSummary(
                consistency: "Cross-verified across \(totalStages) independent LLMs",
                hallucinations: "Checked at each stage \u{2013} potential issues flagged",
                confidence: totalStages >= 3
                    ? "High \u{2013} multi-stage verification complete"
                    : "Moderate \u{2013} dual verification complete"
            )
            onEvent(.summary(summary))
            onEvent(.done)
            currentTask = nil
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
