import type { JudgeVerdict } from "@shared/schema";

export type TrustBand = "high" | "partial" | "low";

export interface TrustScoreInput {
  judgeVerdict: JudgeVerdict | undefined;
  verifiedSources: number;
  brokenSources: number;
}

/**
 * Collapses the Judge's structured verdict plus URL verification results
 * into a single 0–100 trust score for the novice-mode banner.
 * Returns null when no Judge verdict is available (e.g. pipeline errored).
 * Formula is intentionally simple and tunable — see spec open questions.
 */
export function computeTrustScore(input: TrustScoreInput): number | null {
  const { judgeVerdict, brokenSources } = input;
  if (!judgeVerdict) return null;

  const confidenceFactor =
    judgeVerdict.confidence === "high"
      ? 1.0
      : judgeVerdict.confidence === "moderate"
      ? 0.9
      : 0.7;

  const urlPenalty = brokenSources > 0 ? 0.8 : 1.0;

  const raw = judgeVerdict.overallScore * confidenceFactor * urlPenalty;
  const rounded = Math.round(raw);
  return Math.max(0, Math.min(100, rounded));
}

export function trustScoreBand(score: number): TrustBand {
  if (score >= 85) return "high";
  if (score >= 60) return "partial";
  return "low";
}
