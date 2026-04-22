import { describe, it, expect } from "vitest";
import { generateSessionToken, hashToken, SESSION_TTL_MS, SESSION_SLIDING_WINDOW_MS } from "./session";

describe("generateSessionToken", () => {
  it("returns a 43+ character URL-safe string", () => {
    const token = generateSessionToken();
    expect(token.length).toBeGreaterThanOrEqual(43);
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
  });

  it("is unique across calls", () => {
    const a = generateSessionToken();
    const b = generateSessionToken();
    expect(a).not.toEqual(b);
  });
});

describe("hashToken", () => {
  it("returns a 64-char hex string", () => {
    const h = hashToken("abc123");
    expect(h).toMatch(/^[a-f0-9]{64}$/);
  });

  it("is deterministic", () => {
    expect(hashToken("abc")).toEqual(hashToken("abc"));
  });
});

describe("TTL constants", () => {
  it("TTL is 30 days", () => {
    expect(SESSION_TTL_MS).toBe(30 * 24 * 60 * 60 * 1000);
  });
  it("sliding window is 7 days", () => {
    expect(SESSION_SLIDING_WINDOW_MS).toBe(7 * 24 * 60 * 60 * 1000);
  });
});
