import { describe, it, expect } from "vitest";
import { generateEmailCode, hashEmailCode, normalizeEmail } from "./email";

describe("generateEmailCode", () => {
  it("returns a 6-digit zero-padded numeric string", () => {
    for (let i = 0; i < 50; i++) {
      const code = generateEmailCode();
      expect(code).toMatch(/^\d{6}$/);
    }
  });
});

describe("hashEmailCode", () => {
  it("is deterministic and email-scoped (salted by email)", () => {
    const a = hashEmailCode("123456", "user@example.com");
    const b = hashEmailCode("123456", "user@example.com");
    const c = hashEmailCode("123456", "other@example.com");
    expect(a).toEqual(b);
    expect(a).not.toEqual(c);
  });
});

describe("normalizeEmail", () => {
  it("lowercases and trims", () => {
    expect(normalizeEmail(" User@Example.COM ")).toBe("user@example.com");
  });
});
