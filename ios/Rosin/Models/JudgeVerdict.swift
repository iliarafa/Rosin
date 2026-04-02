import Foundation

// ── Structured scoring models for the Judge pipeline ──────────────────
// These match the Zod schemas in shared/schema.ts (Claim, HallucinationFlag,
// StageAnalysis, JudgeVerdict). The Judge produces all of these in a single
// structured JSON call after all verification stages complete.

/// A single factual claim extracted from a stage's output
struct Claim: Codable {
    let text: String
    let confidence: Int
    let sources: [String]?

    init(text: String, confidence: Int, sources: [String]? = nil) {
        self.text = text
        self.confidence = confidence
        self.sources = sources
    }
}

/// A potential hallucination flagged by the Judge
struct HallucinationFlag: Codable {
    let claim: String
    let reason: String
    let severity: HallucinationSeverity

    enum HallucinationSeverity: String, Codable {
        case low, medium, high
    }
}

/// Per-stage structured analysis produced by the Judge
struct StageAnalysis: Codable {
    let stage: Int
    let agreementScore: Int
    let claims: [Claim]
    let hallucinationFlags: [HallucinationFlag]
    let corrections: [String]
}

/// The Judge's comprehensive verdict across all stages
struct JudgeVerdict: Codable {
    let verdict: String
    let overallScore: Int
    let confidence: String // "high", "moderate", or "low"
    let keyFindings: [String]
    let stageAnalyses: [StageAnalysis]
}
