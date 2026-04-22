import { describe, it, expect } from "vitest";
import { currentMonthKey, HOSTED_FREE_QUERIES, defaultMonthlyCapUsd } from "./metering";

describe("currentMonthKey", () => {
  it("returns YYYY-MM for a specific date", () => {
    expect(currentMonthKey(new Date("2026-04-09T12:00:00Z"))).toBe("2026-04");
    expect(currentMonthKey(new Date("2026-12-31T23:59:59Z"))).toBe("2026-12");
    expect(currentMonthKey(new Date("2027-01-01T00:00:00Z"))).toBe("2027-01");
  });
});

describe("HOSTED_FREE_QUERIES", () => {
  it("is 3", () => {
    expect(HOSTED_FREE_QUERIES).toBe(3);
  });
});

describe("defaultMonthlyCapUsd", () => {
  it("falls back to 50 when env unset", () => {
    const original = process.env.HOSTED_MONTHLY_CAP_USD;
    delete process.env.HOSTED_MONTHLY_CAP_USD;
    expect(defaultMonthlyCapUsd()).toBe(50);
    if (original !== undefined) process.env.HOSTED_MONTHLY_CAP_USD = original;
  });
});
