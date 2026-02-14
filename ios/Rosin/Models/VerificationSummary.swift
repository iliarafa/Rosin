import Foundation

struct Contradiction: Identifiable {
    let id = UUID()
    let topic: String
    let stageA: Int
    let stageB: Int
    let description: String
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

struct VerificationSummary {
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
