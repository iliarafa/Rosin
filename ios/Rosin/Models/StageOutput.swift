import Foundation

enum StageStatus: String {
    case pending
    case streaming
    case complete
    case error
    case skipped
    case retrying
}

struct StageOutput: Identifiable {
    let id: Int // stage number (1-based)
    var model: LLMModel
    var content: String
    var status: StageStatus
    var error: String?

    var stage: Int { id }
}
