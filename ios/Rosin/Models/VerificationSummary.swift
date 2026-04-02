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

/// Raw JSON response from the old analysis LLM (kept for backward compat)
struct AnalysisResponse: Decodable {
    let consistencySummary: String
    let hallucinationRisk: String
    let confidenceLevel: String
    let confidenceScore: Double?
    let contradictions: [AnalysisContradiction]
    let analysisBullets: [String]?

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
    /// Dynamic analyst-style bullet points (now sourced from judgeVerdict.keyFindings)
    let analysisBullets: [String]
    /// Structured Judge verdict — present when the Judge stage completes successfully
    let judgeVerdict: JudgeVerdict?

    init(
        consistency: String,
        hallucinations: String,
        confidence: String,
        contradictions: [Contradiction] = [],
        confidenceScore: Double? = nil,
        isAnalyzed: Bool = false,
        analysisBullets: [String] = [],
        judgeVerdict: JudgeVerdict? = nil
    ) {
        self.consistency = consistency
        self.hallucinations = hallucinations
        self.confidence = confidence
        self.contradictions = contradictions
        self.confidenceScore = confidenceScore
        self.isAnalyzed = isAnalyzed
        self.analysisBullets = analysisBullets
        self.judgeVerdict = judgeVerdict
    }

    /// Custom decoder to handle history items saved before new fields were added
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consistency = try container.decode(String.self, forKey: .consistency)
        hallucinations = try container.decode(String.self, forKey: .hallucinations)
        confidence = try container.decode(String.self, forKey: .confidence)
        contradictions = try container.decode([Contradiction].self, forKey: .contradictions)
        confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore)
        isAnalyzed = try container.decode(Bool.self, forKey: .isAnalyzed)
        analysisBullets = try container.decodeIfPresent([String].self, forKey: .analysisBullets) ?? []
        judgeVerdict = try container.decodeIfPresent(JudgeVerdict.self, forKey: .judgeVerdict)
    }
}
