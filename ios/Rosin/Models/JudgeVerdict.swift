import Foundation

// ── Structured scoring models for the Judge pipeline ──────────────────
// These match the Zod schemas in shared/schema.ts (ProvenanceEntry, Claim,
// HallucinationFlag, StageAnalysis, JudgeVerdict). The Judge produces all
// of these in a single structured JSON call after all verification stages complete.

/// Tracks how a claim was introduced or changed across pipeline stages.
/// Each entry records which model made the change, at which stage, and why.
struct ProvenanceEntry: Codable {
    let model: String
    let stage: Int
    let changeType: ChangeType
    let originalText: String?
    let newText: String
    let reason: String

    enum ChangeType: String, Codable {
        case added, modified, flagged, corrected

        /// Lenient decoding — maps unexpected values to closest match
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
            switch raw {
            case "added", "new", "introduced": self = .added
            case "modified", "updated", "refined", "changed": self = .modified
            case "flagged", "questioned", "suspect": self = .flagged
            case "corrected", "fixed", "revised": self = .corrected
            default: self = .added
            }
        }
    }
}

/// A single factual claim extracted from a stage's output
struct Claim: Codable {
    let text: String
    let confidence: Int
    let sources: [String]?
    /// Provenance trail — tracks which model introduced or changed this claim
    let provenance: [ProvenanceEntry]?

    init(text: String, confidence: Int, sources: [String]? = nil, provenance: [ProvenanceEntry]? = nil) {
        self.text = text
        self.confidence = confidence
        self.sources = sources
        self.provenance = provenance
    }

    /// Lenient decoder — the Judge sometimes returns `sources` as numeric indexes
    /// (e.g. [1, 2, 3]) instead of URL strings. Accept both and stringify.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Int.self, forKey: .confidence)
        provenance = try container.decodeIfPresent([ProvenanceEntry].self, forKey: .provenance)

        if let strs = try? container.decodeIfPresent([String].self, forKey: .sources) {
            sources = strs
        } else if let ints = try? container.decodeIfPresent([Int].self, forKey: .sources) {
            sources = ints.map(String.init)
        } else if let dbls = try? container.decodeIfPresent([Double].self, forKey: .sources) {
            sources = dbls.map { String(Int($0)) }
        } else {
            sources = nil
        }
    }
}

/// A potential hallucination flagged by the Judge
struct HallucinationFlag: Codable {
    let claim: String
    let reason: String
    let severity: HallucinationSeverity

    enum HallucinationSeverity: String, Codable {
        case low, medium, high

        /// Lenient decoding — maps unexpected values like "moderate" to the closest match
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
            switch raw {
            case "low": self = .low
            case "medium", "moderate", "med": self = .medium
            case "high", "critical", "severe": self = .high
            default: self = .medium // safe default for unknown values
            }
        }
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
