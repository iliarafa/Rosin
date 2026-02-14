import Foundation

struct VerificationHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String
    let chain: [LLMModel]
    let stages: [StageOutput]
    let summary: VerificationSummary?
    let adversarialMode: Bool
    let createdAt: Date

    init(
        query: String,
        chain: [LLMModel],
        stages: [StageOutput],
        summary: VerificationSummary?,
        adversarialMode: Bool
    ) {
        self.id = UUID()
        self.query = query
        self.chain = chain
        self.stages = stages
        self.summary = summary
        self.adversarialMode = adversarialMode
        self.createdAt = Date()
    }

    var chainSummary: String {
        chain.map { $0.model }.joined(separator: " → ")
    }

    var confidenceScore: Double? {
        summary?.confidenceScore
    }

    var contradictionCount: Int {
        summary?.contradictions.count ?? 0
    }
}
