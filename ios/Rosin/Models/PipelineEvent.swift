import Foundation

enum PipelineEvent {
    case researchStart
    case researchComplete(sourceCount: Int, sources: String)
    case researchError(error: String)
    case stageStart(stage: Int, model: LLMModel)
    case content(stage: Int, text: String)
    case stageComplete(stage: Int)
    case stageRetry(stage: Int, model: LLMModel, attempt: Int)
    case stageSkipped(stage: Int, error: String)
    case stageError(stage: Int, error: String)
    /// Per-stage analysis from the Judge — contains agreement score, claims, flags
    case stageAnalysis(stage: Int, analysis: StageAnalysis)
    /// Auto tie-breaker triggered due to strong disagreement between stages
    case tieBreaker(reason: String)
    case summary(VerificationSummary)
    case done
}
