import Foundation

struct Contradiction: Identifiable, Codable {
    let id: UUID
    let topic: String
    let stageA: Int
    let stageB: Int
    let description: String

    init(topic: String, stageA: Int, stageB: Int, description: String) {
        self.id = UUID()
        self.topic = topic
        self.stageA = stageA
        self.stageB = stageB
        self.description = description
    }
}

struct AnalysisResponse: Decodable {
    let consistencySummary: String
    let hallucinationRisk: String
    let confidenceLevel: String
    let confidenceScore: Double?
    let contradictions: [AnalysisContradiction]

    struct AnalysisContradiction: Decodable {
        let topic: String
        let stageA: Int
        let stageB: Int
        let description: String
    }
}

struct VerificationSummary: Codable {
    let consistency: String
    let hallucinations: String
    let confidence: String
    let contradictions: [Contradiction]
    let confidenceScore: Double?
    let isAnalyzed: Bool

    init(
        consistency: String,
        hallucinations: String,
        confidence: String,
        contradictions: [Contradiction] = [],
        confidenceScore: Double? = nil,
        isAnalyzed: Bool = false
    ) {
        self.consistency = consistency
        self.hallucinations = hallucinations
        self.confidence = confidence
        self.contradictions = contradictions
        self.confidenceScore = confidenceScore
        self.isAnalyzed = isAnalyzed
    }
}
