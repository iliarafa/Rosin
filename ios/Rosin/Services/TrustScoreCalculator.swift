import Foundation

enum TrustBand {
    case high
    case partial
    case low
}

enum TrustScoreCalculator {

    /// Mirrors server/trust-score.ts. Returns nil when no Judge verdict is available.
    static func compute(
        judgeVerdict: JudgeVerdict?,
        verifiedSources: Int,
        brokenSources: Int
    ) -> Int? {
        guard let judge = judgeVerdict else { return nil }

        let confidenceFactor: Double
        switch judge.confidence {
        case "high": confidenceFactor = 1.0
        case "moderate": confidenceFactor = 0.9
        default: confidenceFactor = 0.7
        }

        let urlPenalty: Double = brokenSources > 0 ? 0.8 : 1.0
        let raw = Double(judge.overallScore) * confidenceFactor * urlPenalty
        return max(0, min(100, Int(raw.rounded())))
    }

    static func band(_ score: Int) -> TrustBand {
        if score >= 85 { return .high }
        if score >= 60 { return .partial }
        return .low
    }
}
