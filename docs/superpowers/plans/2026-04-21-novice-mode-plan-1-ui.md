# Novice Mode — Plan 1: UI Pass (BYO keys)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Rosin's default landing page a simplified "novice mode" — one input, one Verify button, a trust-score result screen — while preserving the current terminal UI as "Pro mode" behind a toggle, on both web and iOS. This plan is BYO-keys only; hosted free-tier infrastructure is deferred to Plan 2.

**Architecture:** The existing verification pipeline (`POST /api/verify` on web, `VerificationPipelineManager` on iOS) is reused unchanged. Novice mode is a thin UI layer on top: it calls the same pipeline with a fixed 2-stage chain (Sonnet 4.5 → Gemini 2.5 Flash), Live Research on, Auto Tie-Breaker off, and collapses the Judge's structured verdict into a single 0–100 trust score. A new `/` route on web renders the novice UI; `/pro` renders the existing Terminal. iOS uses a `UserDefaults` flag to switch between a new `NoviceTerminalView` and the existing `TerminalView`.

**Tech Stack:** Web — React 18, TypeScript, wouter, react-query, framer-motion, shadcn/ui, Tailwind, Vite, Express, Drizzle. iOS — SwiftUI, async/await, URLSession.bytes, Keychain.

**Spec:** `docs/superpowers/specs/2026-04-21-novice-mode-design.md`

---

## File Structure

### Web — new files

- `server/trust-score.ts` — pure function computing the 0–100 trust score from Judge verdict + source data
- `server/trust-score.test.ts` — vitest unit tests
- `client/src/hooks/use-rosin-mode.ts` — localStorage-backed `"novice" | "pro"` flag
- `client/src/pages/novice.tsx` — novice landing + result screen
- `client/src/components/novice/trust-score-banner.tsx` — the big score banner
- `client/src/components/novice/novice-input.tsx` — centered input + Verify button
- `client/src/components/novice/verified-answer-card.tsx` — answer + sources disclosure
- `vitest.config.ts` — vitest configuration
- `client/src/pages/welcome.tsx` — relocated copy of the current `landing.tsx` (preserves the marketing page at `/welcome`)

### Web — modified files

- `shared/schema.ts` — add `trustScore` field to `VerificationSummary`
- `server/routes.ts` — compute trust score when building the summary, emit in `summary` event
- `client/src/App.tsx` — rewire routes: `/` → Novice, `/pro` → Terminal, `/welcome` → old Landing
- `package.json` — add vitest and @vitest/ui as devDependencies

### iOS — new files

- `ios/Rosin/Services/TrustScoreCalculator.swift` — Swift port of the calculation
- `ios/Rosin/ViewModels/NoviceTerminalViewModel.swift` — simplified VM mirroring `TerminalViewModel`
- `ios/Rosin/Views/Novice/NoviceTerminalView.swift` — novice landing
- `ios/Rosin/Views/Novice/NoviceResultView.swift` — result screen with trust score banner
- `ios/Rosin/Views/Novice/TrustScoreBannerView.swift` — reusable banner component
- `ios/Rosin/Services/RosinModeManager.swift` — `ObservableObject` wrapping the `UserDefaults` flag

### iOS — modified files

- `ios/Rosin/Models/VerificationSummary.swift` — add `trustScore: Int?` field
- `ios/Rosin/RosinApp.swift` — route to Novice/Pro based on `RosinModeManager`
- `ios/Rosin/Views/Settings/SettingsView.swift` — add Pro Mode toggle
- `ios/Rosin/Views/Terminal/TerminalView.swift` — add back-to-Novice control in nav bar

---

## Phase A — Trust Score (server, foundation)

### Task 1: Add vitest configuration and first passing test

**Files:**
- Create: `vitest.config.ts`
- Modify: `package.json` (add devDependencies + script)
- Create: `server/trust-score.test.ts`

- [ ] **Step 1: Add vitest to package.json**

Modify `package.json`. In the existing `devDependencies` object, add:

```json
"vitest": "^1.6.0",
"@vitest/ui": "^1.6.0"
```

Also add a script to the existing `scripts` object:

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 2: Install the new dev deps**

Run: `npm install`
Expected: vitest and @vitest/ui are installed without errors.

- [ ] **Step 3: Create vitest config**

Create `vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "client/src"),
      "@shared": path.resolve(__dirname, "shared"),
    },
  },
  test: {
    environment: "node",
    include: ["server/**/*.test.ts", "shared/**/*.test.ts"],
  },
});
```

- [ ] **Step 4: Write a smoke test to prove vitest works**

Create `server/trust-score.test.ts`:

```ts
import { describe, it, expect } from "vitest";

describe("vitest smoke", () => {
  it("runs", () => {
    expect(1 + 1).toBe(2);
  });
});
```

- [ ] **Step 5: Run the smoke test**

Run: `npm run test`
Expected: 1 test passes, exit code 0. If it fails, the config is wrong — fix before proceeding.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json vitest.config.ts server/trust-score.test.ts
git commit -m "chore: add vitest test infrastructure"
```

---

### Task 2: Write the trust-score calculation (test-first)

**Files:**
- Modify: `server/trust-score.test.ts` (replace smoke test)
- Create: `server/trust-score.ts`

- [ ] **Step 1: Write the failing tests**

Replace the entire content of `server/trust-score.test.ts` with:

```ts
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
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `npm run test`
Expected: FAIL with errors about `./trust-score` not existing.

- [ ] **Step 3: Implement the calculation**

Create `server/trust-score.ts`:

```ts
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
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `npm run test`
Expected: all tests pass, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add server/trust-score.ts server/trust-score.test.ts
git commit -m "feat: add trust-score calculation for novice mode"
```

---

### Task 3: Add trustScore to VerificationSummary schema and emit from server

**Files:**
- Modify: `shared/schema.ts` (~line 124)
- Modify: `server/routes.ts` (summary builder in the /api/verify handler)

- [ ] **Step 1: Add the field to the schema**

Open `shared/schema.ts`. Find the `verificationSummarySchema` object (around line 119). Add `trustScore` after `confidenceScore`:

```ts
export const verificationSummarySchema = z.object({
  consistency: z.string(),
  hallucinations: z.string(),
  confidence: z.string(),
  contradictions: z.array(contradictionSchema).optional(),
  confidenceScore: z.number().min(0).max(1).optional(),
  trustScore: z.number().min(0).max(100).optional(),
  isAnalyzed: z.boolean().optional(),
  analysisBullets: z.array(z.string()).optional(),
  /** Structured Judge verdict — present when the Judge stage completes */
  judgeVerdict: judgeVerdictSchema.optional(),
});
```

- [ ] **Step 2: Add the trust-score import**

Open `server/routes.ts`. In the existing top-of-file imports (around line 7), add a new import line just below the shared-schema import:

```ts
import { computeTrustScore } from "./trust-score";
```

- [ ] **Step 3: Track verified / broken source counts at the handler scope**

In `server/routes.ts`, find the Live Research block that begins around line 856 with `if (liveResearch) {`. **Just before** that `if (liveResearch)` block, declare two counters:

```ts
let verifiedSourceCount = 0;
let brokenSourceCount = 0;
```

Then inside the block, where `const verified = await verifyURLs(rawResults);` appears (around line 893), insert three lines right after it — before `searchContext = formatSearchContext(verified);`:

```ts
const verified = await verifyURLs(rawResults);
verifiedSourceCount = verified.filter((r) => r.urlStatus.startsWith("VERIFIED")).length;
brokenSourceCount = verified.filter((r) => r.urlStatus.startsWith("BROKEN")).length;
searchContext = formatSearchContext(verified);
```

- [ ] **Step 4: Emit structured sources in the research_complete event**

In the same block, the existing `sendSSE(res, { type: "research_complete", ... })` call (around lines 902–906) emits `sources` as a formatted string. Add a structured array field alongside it — do not change the existing `sources` string (the Pro UI depends on it). The call becomes:

```ts
sendSSE(res, {
  type: "research_complete",
  sourceCount: verified.length,
  sources: sourceSummary,
  verifiedSources: verified.map((r) => ({
    title: r.title,
    url: r.url,
    urlStatus: r.urlStatus,
  })),
});
```

- [ ] **Step 5: Attach trustScore to the summary before emitting**

Find the final summary emission (around line 1129): `sendSSE(res, { type: "summary", summary });`. Immediately before that line, compute and attach the trust score:

```ts
summary.trustScore = computeTrustScore({
  judgeVerdict: summary.judgeVerdict,
  verifiedSources: verifiedSourceCount,
  brokenSources: brokenSourceCount,
}) ?? undefined;

sendSSE(res, { type: "summary", summary });
```

- [ ] **Step 6: Type-check**

Run: `npm run check`
Expected: no TypeScript errors.

- [ ] **Step 7: Run existing tests**

Run: `npm run test`
Expected: all tests still pass.

- [ ] **Step 8: Manual smoke test**

Run: `PORT=8081 npm run dev`
In another terminal, use an HTTP client (curl or the existing `/terminal` page) to fire a verify request with `liveResearch: true` and a real query. Inspect the `summary` SSE event — it must contain a `trustScore` between 0 and 100. Inspect the `research_complete` event — it must contain a `verifiedSources` array with `title`, `url`, and `urlStatus` on each entry.

- [ ] **Step 9: Commit**

```bash
git add shared/schema.ts server/routes.ts
git commit -m "feat: emit trustScore and structured verifiedSources in /api/verify"
```

---

## Phase B — Web Novice UI

### Task 4: Add the mode-persistence hook

**Files:**
- Create: `client/src/hooks/use-rosin-mode.ts`

- [ ] **Step 1: Write the hook**

Create `client/src/hooks/use-rosin-mode.ts`:

```ts
import { useEffect, useState } from "react";

export type RosinMode = "novice" | "pro";

const STORAGE_KEY = "rosin.mode";

export function useRosinMode(): [RosinMode, (mode: RosinMode) => void] {
  const [mode, setMode] = useState<RosinMode>(() => {
    if (typeof window === "undefined") return "novice";
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return stored === "pro" ? "pro" : "novice";
  });

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, mode);
  }, [mode]);

  return [mode, setMode];
}
```

- [ ] **Step 2: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/src/hooks/use-rosin-mode.ts
git commit -m "feat: add useRosinMode hook for mode persistence"
```

---

### Task 5: Create the trust-score banner component

**Files:**
- Create: `client/src/components/novice/trust-score-banner.tsx`

- [ ] **Step 1: Write the component**

Create `client/src/components/novice/trust-score-banner.tsx`:

```tsx
import { motion } from "framer-motion";

type TrustBand = "high" | "partial" | "low";

function band(score: number): TrustBand {
  if (score >= 85) return "high";
  if (score >= 60) return "partial";
  return "low";
}

const LABELS: Record<TrustBand, string> = {
  high: "Highly verified",
  partial: "Partially verified",
  low: "Low confidence — treat with skepticism",
};

const COLORS: Record<TrustBand, string> = {
  high: "text-green-500 border-green-500/40",
  partial: "text-yellow-500 border-yellow-500/40",
  low: "text-red-500 border-red-500/40",
};

interface TrustScoreBannerProps {
  score: number | null;
  aiCount: number;
  sourceCount: number;
}

export function TrustScoreBanner({ score, aiCount, sourceCount }: TrustScoreBannerProps) {
  if (score === null) {
    return (
      <div className="font-mono text-red-500 border border-red-500/40 px-4 py-3 rounded">
        [ COULD NOT VERIFY ]
      </div>
    );
  }

  const b = band(score);

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={`font-mono border rounded px-5 py-4 ${COLORS[b]}`}
      data-testid="trust-score-banner"
    >
      <div className="text-xs uppercase tracking-widest opacity-70">[ VERIFIED ]</div>
      <div className="flex items-baseline gap-3 mt-1">
        <span className="text-5xl font-semibold tabular-nums">{score}%</span>
        <span className="text-sm uppercase tracking-wide">{LABELS[b]}</span>
      </div>
      <div className="text-xs opacity-70 mt-2">
        {aiCount} AIs agreed · {sourceCount} sources confirmed
      </div>
    </motion.div>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/src/components/novice/trust-score-banner.tsx
git commit -m "feat: add TrustScoreBanner component"
```

---

### Task 6: Create the novice input component

**Files:**
- Create: `client/src/components/novice/novice-input.tsx`

- [ ] **Step 1: Write the component**

Create `client/src/components/novice/novice-input.tsx`:

```tsx
import { useState, useRef, KeyboardEvent } from "react";

interface NoviceInputProps {
  onSubmit: (query: string) => void;
  disabled?: boolean;
}

export function NoviceInput({ onSubmit, disabled }: NoviceInputProps) {
  const [value, setValue] = useState("");
  const inputRef = useRef<HTMLTextAreaElement>(null);

  function handleKey(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }

  function submit() {
    const trimmed = value.trim();
    if (!trimmed || disabled) return;
    onSubmit(trimmed);
  }

  return (
    <div className="w-full max-w-2xl mx-auto font-mono">
      <div className="text-center text-sm text-zinc-400 mb-3">
        Ask a question. We'll verify it across multiple AIs.
      </div>
      <div className="border border-zinc-800 rounded bg-black px-4 py-3 flex items-start gap-2 focus-within:border-green-500/60 transition-colors">
        <span className="text-green-500 shrink-0 mt-0.5">&gt;</span>
        <textarea
          ref={inputRef}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={handleKey}
          disabled={disabled}
          autoFocus
          rows={2}
          className="flex-1 bg-transparent outline-none resize-none text-zinc-100 placeholder:text-zinc-600"
          placeholder="e.g. Is creatine safe for teenagers?"
          data-testid="novice-input"
        />
      </div>
      <div className="flex justify-center mt-4">
        <button
          onClick={submit}
          disabled={disabled || !value.trim()}
          className="border border-green-500 text-green-500 px-6 py-2 text-sm tracking-widest disabled:opacity-40 hover:bg-green-500/10 transition-colors"
          data-testid="novice-verify"
        >
          [ VERIFY ]
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/src/components/novice/novice-input.tsx
git commit -m "feat: add NoviceInput component"
```

---

### Task 7: Create the verified-answer card

**Files:**
- Create: `client/src/components/novice/verified-answer-card.tsx`

- [ ] **Step 1: Write the component**

Create `client/src/components/novice/verified-answer-card.tsx`:

```tsx
import { useState } from "react";

export interface VerifiedSource {
  title: string;
  url: string;
  status: "VERIFIED" | "BROKEN" | "TIMEOUT" | "UNCHECKED";
}

interface VerifiedAnswerCardProps {
  question: string;
  answer: string;
  sources: VerifiedSource[];
  onAskAnother: () => void;
  onShowVerification: () => void;
}

export function VerifiedAnswerCard({
  question,
  answer,
  sources,
  onAskAnother,
  onShowVerification,
}: VerifiedAnswerCardProps) {
  const [showAllSources, setShowAllSources] = useState(false);
  const previewSources = sources.slice(0, 2);
  const restSources = sources.slice(2);

  return (
    <div className="w-full max-w-2xl mx-auto font-mono text-zinc-200" data-testid="verified-answer-card">
      <div className="text-xs text-zinc-500 mb-1 uppercase tracking-wide">You asked</div>
      <div className="text-sm text-zinc-400 mb-6 italic">"{question}"</div>

      <div className="text-sm leading-relaxed whitespace-pre-wrap border-l-2 border-green-500/40 pl-4 py-1">
        {answer}
      </div>

      <div className="mt-6">
        <button
          onClick={() => setShowAllSources((v) => !v)}
          className="text-xs text-zinc-400 hover:text-zinc-200 uppercase tracking-wide"
          data-testid="novice-sources-toggle"
        >
          [ sources {showAllSources ? "▲" : "▼"} ]
        </button>
        <ul className="mt-2 space-y-1 text-xs">
          {previewSources.map((s, i) => (
            <li key={i}>
              <span className={s.status === "VERIFIED" ? "text-green-500" : "text-red-500"}>
                {s.status === "VERIFIED" ? "✓" : "✗"}
              </span>
              <a href={s.url} target="_blank" rel="noreferrer" className="ml-2 text-zinc-300 hover:underline">
                {s.title}
              </a>
            </li>
          ))}
          {showAllSources &&
            restSources.map((s, i) => (
              <li key={i + 2}>
                <span className={s.status === "VERIFIED" ? "text-green-500" : "text-red-500"}>
                  {s.status === "VERIFIED" ? "✓" : "✗"}
                </span>
                <a href={s.url} target="_blank" rel="noreferrer" className="ml-2 text-zinc-300 hover:underline">
                  {s.title}
                </a>
              </li>
            ))}
        </ul>
      </div>

      <div className="flex items-center gap-4 mt-8">
        <button
          onClick={onAskAnother}
          className="border border-zinc-500 text-zinc-300 px-5 py-2 text-sm tracking-widest hover:bg-zinc-500/10"
          data-testid="novice-ask-another"
        >
          [ ASK ANOTHER ]
        </button>
        <button
          onClick={onShowVerification}
          className="text-xs text-zinc-500 hover:text-zinc-300 underline underline-offset-4"
          data-testid="novice-show-verification"
        >
          see how it was verified
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/src/components/novice/verified-answer-card.tsx
git commit -m "feat: add VerifiedAnswerCard component"
```

---

### Task 8: Create the novice page + wire to /api/verify

**Files:**
- Create: `client/src/pages/novice.tsx`

- [ ] **Step 1: Write the page**

Create `client/src/pages/novice.tsx`:

```tsx
import { useState } from "react";
import { Link } from "wouter";
import { NoviceInput } from "@/components/novice/novice-input";
import { TrustScoreBanner } from "@/components/novice/trust-score-banner";
import { VerifiedAnswerCard, type VerifiedSource } from "@/components/novice/verified-answer-card";
import type { LLMModel, VerificationSummary, StageOutput } from "@shared/schema";
import { useRosinMode } from "@/hooks/use-rosin-mode";

const NOVICE_CHAIN: LLMModel[] = [
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
];

type Phase = "idle" | "verifying" | "done" | "error";

interface ResultState {
  question: string;
  answer: string;
  summary: VerificationSummary | null;
  sources: VerifiedSource[];
}

export default function NovicePage() {
  const [, setMode] = useRosinMode();
  const [phase, setPhase] = useState<Phase>("idle");
  const [statusLine, setStatusLine] = useState<string>("");
  const [result, setResult] = useState<ResultState | null>(null);
  const [showPro, setShowPro] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function runVerification(query: string) {
    setPhase("verifying");
    setResult(null);
    setError(null);
    setStatusLine("[ CONTACTING AIs... ]");

    const stages: StageOutput[] = [];
    const sources: VerifiedSource[] = [];
    let summary: VerificationSummary | null = null;

    try {
      const response = await fetch("/api/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          query,
          chain: NOVICE_CHAIN,
          adversarialMode: false,
          liveResearch: true,
          autoTieBreaker: false,
        }),
      });
      if (!response.ok || !response.body) throw new Error(`HTTP ${response.status}`);

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const event = JSON.parse(line.slice(6));
          switch (event.type) {
            case "research_start":
              setStatusLine("[ SEARCHING THE WEB... ]");
              break;
            case "research_complete":
              setStatusLine(`[ VERIFYING ... 2 AIs, ${event.sourceCount} sources ]`);
              if (Array.isArray(event.verifiedSources)) {
                for (const s of event.verifiedSources) {
                  sources.push({
                    title: s.title,
                    url: s.url,
                    status: (s.urlStatus?.split(":")[0]?.trim() ?? "UNCHECKED") as VerifiedSource["status"],
                  });
                }
              }
              break;
            case "stage_start":
              setStatusLine(`[ AI ${event.stage} THINKING... ]`);
              break;
            case "stage_content":
              stages[event.stage] = stages[event.stage] ?? { stage: event.stage, model: NOVICE_CHAIN[event.stage - 1], content: "", status: "streaming" };
              stages[event.stage].content += event.content;
              break;
            case "stage_complete":
              if (stages[event.stage]) stages[event.stage].status = "complete";
              break;
            case "summary":
              summary = event.summary;
              break;
            case "stage_error":
              throw new Error(event.error || "Stage failed");
          }
        }
      }

      const finalStage = stages.filter((s) => s && s.status === "complete").pop();
      const answer = finalStage?.content.trim() ?? "No answer produced.";

      setResult({ question: query, answer, summary, sources });
      setPhase("done");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
      setPhase("error");
    }
  }

  function reset() {
    setPhase("idle");
    setResult(null);
    setError(null);
    setStatusLine("");
    setShowPro(false);
  }

  const trustScore = result?.summary?.trustScore ?? null;
  const verifiedCount = result?.sources.filter((s) => s.status === "VERIFIED").length ?? 0;

  return (
    <div className="min-h-screen bg-black text-zinc-100 font-mono">
      <header className="flex items-center justify-between px-6 py-4">
        <div className="flex items-center gap-3 text-xs">
          <span className="text-green-500">● ROSIN</span>
          <span className="text-zinc-500 uppercase tracking-widest">[ NOVICE MODE ]</span>
        </div>
        <Link
          href="/pro"
          onClick={() => setMode("pro")}
          className="text-xs text-zinc-500 hover:text-zinc-200 uppercase tracking-widest"
          data-testid="novice-to-pro"
        >
          [ PRO → ]
        </Link>
      </header>

      <main className="px-6 pt-12 pb-20">
        {phase === "idle" && <NoviceInput onSubmit={runVerification} />}

        {phase === "verifying" && (
          <div className="text-center text-sm text-zinc-400 mt-10">
            <div className="animate-pulse">{statusLine}</div>
          </div>
        )}

        {phase === "done" && result && (
          <div className="space-y-6 max-w-2xl mx-auto">
            <TrustScoreBanner
              score={trustScore}
              aiCount={2}
              sourceCount={verifiedCount}
            />
            <VerifiedAnswerCard
              question={result.question}
              answer={result.answer}
              sources={result.sources}
              onAskAnother={reset}
              onShowVerification={() => setShowPro(true)}
            />
            {showPro && (
              <div className="text-xs text-zinc-400 border border-zinc-800 rounded p-4">
                <p>For the full per-stage scoring, claim provenance, and Judge details, switch to Pro mode.</p>
                <Link
                  href="/pro"
                  onClick={() => setMode("pro")}
                  className="text-green-500 underline underline-offset-4"
                >
                  Open in Pro →
                </Link>
              </div>
            )}
          </div>
        )}

        {phase === "error" && (
          <div className="max-w-2xl mx-auto text-center mt-10">
            <div className="border border-red-500/40 text-red-500 rounded px-4 py-3 inline-block">
              [ VERIFICATION FAILED ] {error}
            </div>
            <div className="mt-4">
              <button onClick={reset} className="text-xs text-zinc-400 underline">
                Try again
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/src/pages/novice.tsx
git commit -m "feat: add NovicePage with /api/verify wiring"
```

---

### Task 9: Rewire routes in App.tsx

**Files:**
- Create: `client/src/pages/welcome.tsx` (copy of current landing.tsx content)
- Modify: `client/src/App.tsx`

- [ ] **Step 1: Copy landing.tsx to welcome.tsx**

Read the existing `client/src/pages/landing.tsx`. Create `client/src/pages/welcome.tsx` with the same content, but rename the default export function from `Landing` to `Welcome`. This preserves the old landing page at a new URL.

- [ ] **Step 2: Update App.tsx**

Replace the contents of `client/src/App.tsx` with:

```tsx
import { Switch, Route, Redirect } from "wouter";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import Novice from "@/pages/novice";
import Terminal from "@/pages/terminal";
import Welcome from "@/pages/welcome";
import ReadmePage from "@/pages/readme";
import RecommendationsPage from "@/pages/recommendations";
import HeatmapPage from "@/pages/heatmap";
import NotFound from "@/pages/not-found";

function Router() {
  return (
    <Switch>
      <Route path="/" component={Novice} />
      <Route path="/pro" component={Terminal} />
      {/* Backward-compat: existing /terminal URLs still land in Terminal */}
      <Route path="/terminal" component={Terminal} />
      <Route path="/welcome" component={Welcome} />
      <Route path="/readme" component={ReadmePage} />
      <Route path="/recommendations" component={RecommendationsPage} />
      {/* History/report drawer routes — keep pointing at Terminal */}
      <Route path="/history" component={Terminal} />
      <Route path="/report/:id" component={Terminal} />
      <Route path="/heatmap" component={HeatmapPage} />
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Router />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
```

- [ ] **Step 3: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 4: Manual smoke test**

Run: `PORT=8081 npm run dev`
In a browser, visit each of: `http://localhost:8081/`, `/pro`, `/terminal`, `/welcome`. Each must render. `/` must show the novice UI; `/pro` and `/terminal` must show the full power-user terminal unchanged; `/welcome` must show the old landing content.

- [ ] **Step 5: Commit**

```bash
git add client/src/App.tsx client/src/pages/welcome.tsx
git commit -m "feat: rewire routes so / is novice and /pro is terminal"
```

---

### Task 10: Add Novice ← link in the Terminal (Pro) header

**Files:**
- Modify: `client/src/pages/terminal.tsx`

- [ ] **Step 1: Locate the Terminal header**

Open `client/src/pages/terminal.tsx`. Find the top of the JSX returned by `Terminal()` — the first element in the page, which typically contains the Rosin wordmark or a header. Look for where other nav-like elements live (search for `Link` imports from wouter at the top of the file).

- [ ] **Step 2: Add a back-to-novice link**

In the Terminal component, import `useRosinMode`:

```ts
import { useRosinMode } from "@/hooks/use-rosin-mode";
```

In the component body, add:

```ts
const [, setMode] = useRosinMode();
```

In the header region of the returned JSX (wherever is most visually appropriate — e.g. top-right), add a `Link` that sets mode to novice:

```tsx
<Link
  href="/"
  onClick={() => setMode("novice")}
  className="text-xs text-zinc-500 hover:text-zinc-200 uppercase tracking-widest"
  data-testid="pro-to-novice"
>
  [ ← NOVICE ]
</Link>
```

- [ ] **Step 3: Type-check**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 4: Manual smoke test**

Run: `PORT=8081 npm run dev`. Visit `/pro`. The `[ ← NOVICE ]` link must appear in the header and must navigate to `/` when clicked.

- [ ] **Step 5: Commit**

```bash
git add client/src/pages/terminal.tsx
git commit -m "feat: add Novice return link to Pro mode header"
```

---

### Task 11: End-to-end web verification

**Files:** none modified — manual test pass.

- [ ] **Step 1: Start the dev server**

Run: `PORT=8081 npm run dev`
Expected: server listens on 8081.

- [ ] **Step 2: Exercise the novice flow**

In a browser, go to `http://localhost:8081/`:
- The page must load with monospace terminal aesthetic, the `[ NOVICE MODE ]` badge, and a centered input.
- Type a real question (e.g. "Is creatine safe for teenagers?") and click `[ VERIFY ]`.
- Watch the status line change through `[ CONTACTING AIs... ]` → `[ SEARCHING THE WEB... ]` → `[ VERIFYING ... 2 AIs, N sources ]` → `[ AI 1 THINKING... ]` → `[ AI 2 THINKING... ]`.
- When complete, the page must show: the trust-score banner (colored by band), the original question quoted, the answer body, a collapsed sources disclosure with first 2 sources visible, and `[ ASK ANOTHER ]` + `see how it was verified` buttons.

- [ ] **Step 3: Exercise the Pro toggle**

- Click `[ PRO → ]` from the novice page. Confirm `/pro` renders the full Terminal UI unchanged.
- Click `[ ← NOVICE ]` from the Terminal. Confirm `/` renders the novice UI.
- Refresh `/pro` directly. Confirm Terminal still renders (direct URL wins).
- Clear localStorage and visit `/`. Novice mode must be the default.

- [ ] **Step 4: Exercise backward-compat**

- Visit `/terminal` directly. Terminal must render.
- Visit `/welcome` directly. The old marketing landing content must render.

- [ ] **Step 5: Exercise failure paths**

- Temporarily break the server (e.g. unset `AI_INTEGRATIONS_ANTHROPIC_API_KEY` and restart). From `/`, submit a query. The UI must land in the red `[ VERIFICATION FAILED ]` state with a Try again button. Restore the key and confirm recovery.

- [ ] **Step 6: Commit any incidental fixes**

If you discovered bugs during the pass, fix them in small commits. Do not bundle unrelated fixes into one commit.

---

## Phase C — iOS Novice UI

### Task 12: Add trustScore field to iOS VerificationSummary

**Files:**
- Modify: `ios/Rosin/Models/VerificationSummary.swift`

- [ ] **Step 1: Add the field**

Open `ios/Rosin/Models/VerificationSummary.swift`. Add an optional `trustScore` property to the struct so it mirrors the web schema:

```swift
var trustScore: Int?
```

Place it near the other score-adjacent fields (e.g. `confidenceScore`). Include it in any JSON decoding init if the struct uses custom decoding.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Models/VerificationSummary.swift
git commit -m "feat(ios): add trustScore to VerificationSummary"
```

---

### Task 13: Port TrustScoreCalculator to Swift

**Files:**
- Create: `ios/Rosin/Services/TrustScoreCalculator.swift`

- [ ] **Step 1: Write the file**

Create `ios/Rosin/Services/TrustScoreCalculator.swift`:

```swift
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
```

Note to implementer: the `JudgeVerdict` Swift struct already exists in `ios/Rosin/Models/JudgeVerdict.swift`. If its property names differ from `overallScore` or `confidence`, adjust the field accesses above to match.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Services/TrustScoreCalculator.swift
git commit -m "feat(ios): add TrustScoreCalculator (Swift port)"
```

---

### Task 14: Add RosinModeManager

**Files:**
- Create: `ios/Rosin/Services/RosinModeManager.swift`

- [ ] **Step 1: Write the file**

Create `ios/Rosin/Services/RosinModeManager.swift`:

```swift
import Foundation
import SwiftUI

enum RosinMode: String {
    case novice
    case pro
}

@MainActor
final class RosinModeManager: ObservableObject {
    private let storageKey = "rosin.mode"

    @Published var mode: RosinMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: storageKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        self.mode = RosinMode(rawValue: stored ?? "") ?? .novice
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Services/RosinModeManager.swift
git commit -m "feat(ios): add RosinModeManager for mode persistence"
```

---

### Task 15: Create TrustScoreBannerView

**Files:**
- Create: `ios/Rosin/Views/Novice/TrustScoreBannerView.swift`

- [ ] **Step 1: Write the view**

Create `ios/Rosin/Views/Novice/TrustScoreBannerView.swift`:

```swift
import SwiftUI

struct TrustScoreBannerView: View {
    let score: Int?
    let aiCount: Int
    let sourceCount: Int

    var body: some View {
        Group {
            if let s = score {
                let b = TrustScoreCalculator.band(s)
                VStack(alignment: .leading, spacing: 6) {
                    Text("[ VERIFIED ]")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(color(b).opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(s)%")
                            .font(.system(size: 44, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color(b))
                        Text(label(b))
                            .font(.system(.footnote, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(color(b))
                    }
                    Text("\(aiCount) AIs agreed · \(sourceCount) sources confirmed")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(color(b).opacity(0.7))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color(b).opacity(0.4), lineWidth: 1)
                )
            } else {
                Text("[ COULD NOT VERIFY ]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.red.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private func label(_ band: TrustBand) -> String {
        switch band {
        case .high: return "Highly verified"
        case .partial: return "Partially verified"
        case .low: return "Low confidence — treat with skepticism"
        }
    }

    private func color(_ band: TrustBand) -> Color {
        switch band {
        case .high: return Color("RosinGreen")
        case .partial: return .yellow
        case .low: return Color("RosinDestructive")
        }
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Views/Novice/TrustScoreBannerView.swift
git commit -m "feat(ios): add TrustScoreBannerView"
```

---

### Task 16: Add verifiedSources event case + create NoviceTerminalViewModel

**Files:**
- Modify: `ios/Rosin/Models/PipelineEvent.swift`
- Create: `ios/Rosin/ViewModels/NoviceTerminalViewModel.swift`

- [ ] **Step 1: Add a structured-sources event case**

Open `ios/Rosin/Models/PipelineEvent.swift` and add a new case just after the existing `researchComplete` case (the whole enum currently ends with `case done`):

```swift
case researchVerifiedSources(results: [TavilySearchResult])
```

The final enum becomes:

```swift
enum PipelineEvent {
    case researchStart
    case researchComplete(sourceCount: Int, sources: String)
    case researchVerifiedSources(results: [TavilySearchResult])
    case researchError(error: String)
    case stageStart(stage: Int, model: LLMModel)
    case content(stage: Int, text: String)
    case stageComplete(stage: Int)
    case stageRetry(stage: Int, model: LLMModel, attempt: Int)
    case stageSkipped(stage: Int, error: String)
    case stageError(stage: Int, error: String)
    case stageAnalysis(stage: Int, analysis: StageAnalysis)
    case tieBreaker(reason: String)
    case summary(VerificationSummary)
    case done
}
```

Nothing else needs to change — existing consumers of `PipelineEvent` use `switch` statements that will simply ignore the new case as long as they have a `default` arm or an explicit list of cases without exhaustiveness warnings. If the compiler complains about non-exhaustive switches in `TerminalViewModel` or elsewhere, add `case .researchVerifiedSources: break` to each affected switch.

- [ ] **Step 2: Write the view model**

Create `ios/Rosin/ViewModels/NoviceTerminalViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
final class NoviceTerminalViewModel: ObservableObject {
    enum Phase {
        case idle
        case verifying(status: String)
        case done(Result)
        case failed(String)
    }

    struct Source: Identifiable {
        let id = UUID()
        let title: String
        let url: String
        let status: String
    }

    struct Result {
        let question: String
        let answer: String
        let trustScore: Int?
        let aiCount: Int
        let verifiedSourceCount: Int
        let sources: [Source]
    }

    @Published var query: String = ""
    @Published var phase: Phase = .idle

    private let pipeline: VerificationPipelineManager
    private let chain: [LLMModel] = [
        LLMModel(provider: .anthropic, model: "claude-sonnet-4-5"),
        LLMModel(provider: .gemini, model: "gemini-2.5-flash"),
    ]

    init(apiKeyManager: APIKeyManager) {
        self.pipeline = VerificationPipelineManager(apiKeyManager: apiKeyManager)
    }

    func verify() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        phase = .verifying(status: "[ CONTACTING AIs... ]")
        var stageContents: [Int: String] = [:]
        var sources: [Source] = []

        pipeline.run(
            query: q,
            chain: chain,
            adversarialMode: false,
            liveResearch: true,
            autoTieBreaker: false
        ) { [weak self] event in
            guard let self else { return }
            switch event {
            case .researchStart:
                self.phase = .verifying(status: "[ SEARCHING THE WEB... ]")
            case .researchComplete(let count, _):
                self.phase = .verifying(status: "[ VERIFYING ... 2 AIs, \(count) sources ]")
            case .researchVerifiedSources(let results):
                sources = results.map {
                    Source(title: $0.title, url: $0.url, status: $0.urlStatus.rawValue)
                }
            case .stageStart(let stage, _):
                self.phase = .verifying(status: "[ AI \(stage) THINKING... ]")
            case .content(let stage, let text):
                stageContents[stage, default: ""] += text
            case .stageError(_, let error):
                self.phase = .failed(error)
            case .summary(let summary):
                let answer = stageContents[self.chain.count]
                    ?? stageContents.values.last
                    ?? "No answer produced."
                let verifiedCount = sources.filter { $0.status.hasPrefix("VERIFIED") }.count
                self.phase = .done(
                    Result(
                        question: q,
                        answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
                        trustScore: summary.trustScore,
                        aiCount: self.chain.count,
                        verifiedSourceCount: verifiedCount,
                        sources: sources
                    )
                )
            default:
                break
            }
        }
    }

    func reset() {
        phase = .idle
        query = ""
    }
}
```

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds. If the compiler reports non-exhaustive switch warnings in `TerminalViewModel` or other consumers of `PipelineEvent`, add `case .researchVerifiedSources: break` to each affected switch.

- [ ] **Step 4: Commit**

```bash
git add ios/Rosin/Models/PipelineEvent.swift ios/Rosin/ViewModels/NoviceTerminalViewModel.swift
git commit -m "feat(ios): add researchVerifiedSources event + NoviceTerminalViewModel"
```

---

### Task 17: Create NoviceTerminalView

**Files:**
- Create: `ios/Rosin/Views/Novice/NoviceTerminalView.swift`

- [ ] **Step 1: Write the view**

Create `ios/Rosin/Views/Novice/NoviceTerminalView.swift`:

```swift
import SwiftUI

struct NoviceTerminalView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @StateObject private var viewModel: NoviceTerminalViewModel
    @State private var showSettings = false

    init(apiKeyManager: APIKeyManager) {
        _viewModel = StateObject(wrappedValue: NoviceTerminalViewModel(apiKeyManager: apiKeyManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.gray.opacity(0.2))
            Group {
                switch viewModel.phase {
                case .idle:
                    inputView
                case .verifying(let status):
                    verifyingView(status: status)
                case .done(let result):
                    NoviceResultView(result: result, onAskAnother: viewModel.reset)
                case .failed(let error):
                    errorView(error: error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        }
        .background(Color("RosinBackground").ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(apiKeyManager)
        }
    }

    private var header: some View {
        HStack {
            Text("● ROSIN")
                .foregroundStyle(Color("RosinGreen"))
            Text("[ NOVICE MODE ]")
                .foregroundStyle(.secondary)
                .tracking(2)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("novice-settings")
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var inputView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Ask a question. We'll verify it across multiple AIs.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 8) {
                Text(">")
                    .foregroundStyle(Color("RosinGreen"))
                TextField(
                    "e.g. Is creatine safe for teenagers?",
                    text: $viewModel.query,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...4)
            }
            .font(.system(.body, design: .monospaced))
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Button {
                viewModel.verify()
            } label: {
                Text("[ VERIFY ]")
                    .tracking(3)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color("RosinGreen"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color("RosinGreen"), lineWidth: 1)
                    )
            }
            .disabled(viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("novice-verify")

            Spacer()
            Spacer()
        }
    }

    private func verifyingView(status: String) -> some View {
        VStack {
            Spacer()
            Text(status)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .opacity(0.6)
            Spacer()
            Spacer()
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text("[ VERIFICATION FAILED ]")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.red)
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Try again") { viewModel.reset() }
                .buttonStyle(.borderless)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Spacer()
        }
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds. `NoviceResultView` is not yet defined — expect one error for that reference; proceed to Task 18.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Views/Novice/NoviceTerminalView.swift
git commit -m "feat(ios): add NoviceTerminalView"
```

---

### Task 18: Create NoviceResultView

**Files:**
- Create: `ios/Rosin/Views/Novice/NoviceResultView.swift`

- [ ] **Step 1: Write the view**

Create `ios/Rosin/Views/Novice/NoviceResultView.swift`:

```swift
import SwiftUI

struct NoviceResultView: View {
    let result: NoviceTerminalViewModel.Result
    let onAskAnother: () -> Void

    @State private var showAllSources = false
    @State private var showVerification = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TrustScoreBannerView(
                    score: result.trustScore,
                    aiCount: result.aiCount,
                    sourceCount: result.verifiedSourceCount
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("YOU ASKED")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("\"\(result.question)\"")
                        .font(.system(.footnote, design: .monospaced))
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Text(result.answer)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color("RosinGreen").opacity(0.4))
                            .frame(width: 2)
                    }

                sourcesSection

                HStack(spacing: 16) {
                    Button {
                        onAskAnother()
                    } label: {
                        Text("[ ASK ANOTHER ]")
                            .tracking(2)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    }
                    .accessibilityIdentifier("novice-ask-another")

                    Button {
                        showVerification.toggle()
                    } label: {
                        Text("see how it was verified")
                            .underline()
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if showVerification {
                    Text("For the full per-stage scoring, claim provenance, and Judge details, switch to Pro mode from Settings.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var sourcesSection: some View {
        let previewCount = min(2, result.sources.count)
        let previews = Array(result.sources.prefix(previewCount))
        let rest = Array(result.sources.dropFirst(previewCount))

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                showAllSources.toggle()
            } label: {
                Text("[ sources \(showAllSources ? "▲" : "▼") ]")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            ForEach(previews) { sourceRow($0) }
            if showAllSources {
                ForEach(rest) { sourceRow($0) }
            }
        }
    }

    private func sourceRow(_ source: NoviceTerminalViewModel.Source) -> some View {
        HStack(spacing: 8) {
            Text(source.status.hasPrefix("VERIFIED") ? "✓" : "✗")
                .foregroundStyle(source.status.hasPrefix("VERIFIED") ? Color("RosinGreen") : .red)
            if let url = URL(string: source.url) {
                Link(source.title, destination: url)
                    .foregroundStyle(.primary)
            } else {
                Text(source.title)
            }
        }
        .font(.system(.caption2, design: .monospaced))
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Views/Novice/NoviceResultView.swift
git commit -m "feat(ios): add NoviceResultView"
```

---

### Task 19: Wire RosinApp to route between Novice and Pro

**Files:**
- Modify: `ios/Rosin/RosinApp.swift`

- [ ] **Step 1: Update the App entry point**

Replace the contents of `ios/Rosin/RosinApp.swift` with:

```swift
import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var fontSizeManager = FontSizeManager()
    @StateObject private var modeManager = RosinModeManager()
    @State private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingComplete {
                    LandingView(showTerminal: $onboardingComplete)
                } else {
                    switch modeManager.mode {
                    case .novice:
                        NoviceTerminalView(apiKeyManager: apiKeyManager)
                    case .pro:
                        TerminalView()
                    }
                }
            }
            .environmentObject(apiKeyManager)
            .environmentObject(appearanceManager)
            .environmentObject(fontSizeManager)
            .environmentObject(modeManager)
            .preferredColorScheme(appearanceManager.colorScheme)
            .animation(.default, value: modeManager.mode)
        }
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Install and launch on simulator**

Run:
```bash
xcrun simctl install booted ios/Rosin.app
xcrun simctl launch booted com.rosin.app
```
Expected: app launches; after onboarding, Novice mode is the default landing.

- [ ] **Step 4: Commit**

```bash
git add ios/Rosin/RosinApp.swift
git commit -m "feat(ios): route between Novice and Pro via RosinModeManager"
```

---

### Task 20: Add Pro Mode toggle to SettingsView

**Files:**
- Modify: `ios/Rosin/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add the toggle**

Open `ios/Rosin/Views/Settings/SettingsView.swift`. Inject the mode manager and add a toggle section:

```swift
@EnvironmentObject private var modeManager: RosinModeManager

// ... inside the existing Form / List / VStack body:

Section(header: Text("Mode").font(.system(.caption, design: .monospaced))) {
    Toggle(isOn: Binding(
        get: { modeManager.mode == .pro },
        set: { modeManager.mode = $0 ? .pro : .novice }
    )) {
        VStack(alignment: .leading, spacing: 2) {
            Text("Pro Mode")
                .font(.system(.body, design: .monospaced))
            Text("Full multi-stage verification UI with per-stage scoring, provenance, and Judge details.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    .accessibilityIdentifier("pro-mode-toggle")
}
```

Place the `Section` near the top of the Settings body so it's prominent.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 3: Install and launch**

Run:
```bash
xcrun simctl install booted ios/Rosin.app
xcrun simctl launch booted com.rosin.app
```
Expected: Settings shows the Pro Mode toggle. Toggling it switches the root view between Novice and Pro (requires dismissing Settings to see the change — that is fine).

- [ ] **Step 4: Commit**

```bash
git add ios/Rosin/Views/Settings/SettingsView.swift
git commit -m "feat(ios): add Pro Mode toggle to SettingsView"
```

---

### Task 21: Compute and attach trustScore on iOS before summary is published

**Files:**
- Modify: `ios/Rosin/Services/Pipeline/VerificationPipelineManager.swift` (~lines 40–172)

- [ ] **Step 1: Hoist verified / broken source counters to run-scope**

Open `ios/Rosin/Services/Pipeline/VerificationPipelineManager.swift`. In the `run(...)` function body, just before the `if liveResearch { ... }` block (around line 40), declare:

```swift
var verifiedSourceCount = 0
var brokenSourceCount = 0
```

- [ ] **Step 2: Populate counters and emit structured sources after URL verification**

Inside the existing `if var response = rawResponse {` block (around line 57), right after `response = await URLVerifier.verify(response: response)` (line 59), add:

```swift
verifiedSourceCount = response.results.filter { $0.urlStatus == .verified }.count
brokenSourceCount = response.results.filter { $0.urlStatus == .broken }.count
onEvent(.researchVerifiedSources(results: response.results))
```

(`URLVerificationStatus` is defined as an enum in `ios/Rosin/Services/Networking/TavilySearchService.swift` and uses `.verified`, `.broken`, `.timeout`, `.unchecked` cases.)

The `.researchVerifiedSources` event is emitted alongside (not instead of) the existing `.researchComplete` event, so Pro mode continues to work unchanged.

- [ ] **Step 3: Attach trust score before emitting summary**

Find the line `onEvent(.summary(summary))` (around line 172). Immediately before it, compute and mutate the summary:

```swift
summary.trustScore = TrustScoreCalculator.compute(
    judgeVerdict: summary.judgeVerdict,
    verifiedSources: verifiedSourceCount,
    brokenSources: brokenSourceCount
)

onEvent(.summary(summary))
```

Note: `summary` is already declared as `var` earlier in the function (it's reassigned when the tie-breaker re-runs the Judge), so mutating it directly is safe. If the build complains about immutability, change the earlier `let summary = ...` / `summary = ...` lines to use `var`.

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add ios/Rosin/Services/Pipeline/VerificationPipelineManager.swift
git commit -m "feat(ios): compute and attach trustScore in pipeline summary"
```

---

### Task 22: End-to-end iOS verification

**Files:** none modified — manual test pass on simulator.

- [ ] **Step 1: Clean build and install**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
xcrun simctl install booted ios/Rosin.app
xcrun simctl launch booted com.rosin.app
```
Expected: app launches on the iPhone 17 simulator.

- [ ] **Step 2: First-launch flow**

- Complete the existing onboarding (LandingView).
- Confirm the app lands in Novice mode (monospace terminal header with `● ROSIN [ NOVICE MODE ]` and a gear icon on the right for Settings).
- Confirm the centered input with `>` prompt and `[ VERIFY ]` button.

- [ ] **Step 3: Happy-path verify**

- If API keys aren't set, open Settings → API Keys and paste test keys for Anthropic + Gemini + Exa (or Tavily).
- Back in Novice mode, type "What is creatine?" and tap `[ VERIFY ]`.
- Observe the verifying status line cycle through research + stage statuses.
- On completion, confirm: trust-score banner with color band, question quote, answer body in monospace, sources disclosure showing 2 previews, `[ ASK ANOTHER ]` and "see how it was verified" buttons.

- [ ] **Step 4: Mode toggle**

- Tap the gear icon in the Novice header. In the Settings sheet, enable the Pro Mode toggle and dismiss. Confirm the root swaps to the full Terminal UI.
- From Pro, open Settings and disable Pro Mode. Confirm the root returns to Novice mode.
- Force-quit and relaunch the app. The mode must persist across launches.

- [ ] **Step 5: Error paths**

- Remove all API keys. Submit a novice query. The result must land in the red `[ VERIFICATION FAILED ]` state, not crash.
- Airplane mode on, submit a query. Same — failed state, not crash.

- [ ] **Step 6: Commit any incidental fixes**

Fix any bugs discovered in small, focused commits.

---

## Phase D — Integration wrap-up

### Task 23: Cross-platform sanity pass

**Files:** none modified — dual-platform review.

- [ ] **Step 1: Run web test suite**

Run: `npm run test`
Expected: all tests pass.

- [ ] **Step 2: Type-check web**

Run: `npm run check`
Expected: no errors.

- [ ] **Step 3: iOS build**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' build
```
Expected: succeeds.

- [ ] **Step 4: Parity spot-check**

With the same query on web (`/`) and iOS (Novice mode), confirm the trust scores are within a reasonable delta (small differences in source ordering are acceptable; a 40-point delta is not). If they diverge materially, investigate — the server and Swift calculators should produce the same number for the same inputs.

- [ ] **Step 5: Final commit**

If any small fixes were made during the pass, commit them. Otherwise, this is the plan-complete marker.

```bash
git commit --allow-empty -m "chore: novice mode Plan 1 complete"
```

---

## Out of scope for this plan (deferred to Plan 2)

- Hosted `/api/verify/hosted` endpoint
- Email / Google / Apple sign-in
- `accounts` and `sessions` Drizzle tables
- 3-lifetime-query meter + $50 monthly spend cap
- Cloudflare Turnstile on signup
- iOS `AuthService`, `HostedVerificationService`, sign-in screen, post-free gate
- Landing-page copy polish (persona-B-specific messaging on `/welcome`)

All of the above are covered by the spec in `docs/superpowers/specs/2026-04-21-novice-mode-design.md` and will be planned separately after Plan 1 ships and gets user exposure.
