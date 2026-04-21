import { describe, it, expect } from "vitest";
import { computeTrustScore, trustScoreBand } from "./trust-score";
import type { JudgeVerdict } from "@shared/schema";

const baseVerdict: JudgeVerdict = {
  verdict: "The answer is well supported.",
  overallScore: 90,
  confidence: "high",
  keyFindings: [],
  stageAnalyses: [],
};

describe("computeTrustScore", () => {
  it("returns the Judge score when confidence is high and all URLs verified", () => {
    const score = computeTrustScore({
      judgeVerdict: baseVerdict,
      verifiedSources: 5,
      brokenSources: 0,
    });
    expect(score).toBe(90);
  });

  it("drops 10% when confidence is moderate", () => {
    const score = computeTrustScore({
      judgeVerdict: { ...baseVerdict, confidence: "moderate" },
      verifiedSources: 5,
      brokenSources: 0,
    });
    expect(score).toBe(81);
  });

  it("drops 30% when confidence is low", () => {
    const score = computeTrustScore({
      judgeVerdict: { ...baseVerdict, confidence: "low" },
      verifiedSources: 5,
      brokenSources: 0,
    });
    expect(score).toBe(63);
  });

  it("applies a 20% URL penalty when any sources are broken", () => {
    const score = computeTrustScore({
      judgeVerdict: baseVerdict,
      verifiedSources: 3,
      brokenSources: 2,
    });
    expect(score).toBe(72);
  });

  it("combines confidence and URL penalties", () => {
    const score = computeTrustScore({
      judgeVerdict: { ...baseVerdict, confidence: "moderate" },
      verifiedSources: 3,
      brokenSources: 1,
    });
    // 90 * 0.9 * 0.8 = 64.8 → 65
    expect(score).toBe(65);
  });

  it("clamps to 0–100", () => {
    const over = computeTrustScore({
      judgeVerdict: { ...baseVerdict, overallScore: 100 },
      verifiedSources: 10,
      brokenSources: 0,
    });
    expect(over).toBe(100);

    const under = computeTrustScore({
      judgeVerdict: { ...baseVerdict, overallScore: 0, confidence: "low" },
      verifiedSources: 0,
      brokenSources: 5,
    });
    expect(under).toBe(0);
  });

  it("returns null when no judge verdict is present", () => {
    const score = computeTrustScore({
      judgeVerdict: undefined,
      verifiedSources: 5,
      brokenSources: 0,
    });
    expect(score).toBeNull();
  });
});

describe("trustScoreBand", () => {
  it("returns 'high' for >= 85", () => {
    expect(trustScoreBand(85)).toBe("high");
    expect(trustScoreBand(100)).toBe("high");
  });

  it("returns 'partial' for 60–84", () => {
    expect(trustScoreBand(84)).toBe("partial");
    expect(trustScoreBand(60)).toBe("partial");
  });

  it("returns 'low' for < 60", () => {
    expect(trustScoreBand(59)).toBe("low");
    expect(trustScoreBand(0)).toBe("low");
  });
});
