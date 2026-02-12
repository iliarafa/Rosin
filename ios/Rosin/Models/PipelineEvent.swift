import Foundation

enum PipelineEvent {
    case stageStart(stage: Int, model: LLMModel)
    case content(stage: Int, text: String)
    case stageComplete(stage: Int)
    case stageError(stage: Int, error: String)
    case summary(VerificationSummary)
    case done
}
