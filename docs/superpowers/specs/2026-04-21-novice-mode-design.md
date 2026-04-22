# Novice Mode — Design Spec

**Date:** 2026-04-21
**Status:** Approved for implementation planning
**Author:** Brainstormed with Claude Code

## Goal

Make Rosin reach casual ChatGPT users who don't realize AI hallucinates, while preserving the current terminal UI as a "Pro mode" for existing power users. The novice experience is the new default landing page; the existing terminal UI is hidden behind a toggle.

## Target persona

Anchor persona: **casual ChatGPT user**. Asks AI questions, usually trusts the answers, doesn't understand why LLMs hallucinate. Has likely never touched an API key. Pitch to them: *"You already use AI — don't trust just one."* The differentiator we lead with is a single **trust score** on every answer.

Secondary personas (served by the same design, but not the anchor): (1) someone new to AI entirely, (2) AI-curious users intimidated by pro tools.

## Product decisions (locked during brainstorm)

| Decision | Choice |
|---|---|
| Novice vs. Pro UI | Novice is default; Pro behind toggle (option A) |
| Session shape | One-shot Q&A (no chat, no threading) |
| Mental model for novice | Trust score as primary differentiator |
| Free-tier access | Hosted proxy with 3 lifetime free queries per account |
| Scope cap | No payments / no subscriptions — BYO keys after free tier |
| Platforms | Web and iOS in parallel |
| Auth | Three options: email magic link, Sign in with Google, Sign in with Apple |
| Novice stages | 2 stages + Live Research (Sonnet 4.5 → Grok-3-fast; revised 2026-04-22) |
| Pro stages | Unchanged — 3 stages by default, full power-user surface |
| Visual style | Terminal aesthetic (monospace, CLI vibes) for both modes |

## § 1 — Novice landing & interaction

**Single-screen, single-job layout.** New visitors land on a page with:

- Small Rosin wordmark + `[NOVICE MODE]` badge, top-left.
- `[PRO →]` toggle, top-right. No explanation — experts recognize it.
- Centered tagline: *"Ask a question. We'll verify it across multiple AIs."*
- Large terminal-style input prompt (`> `) with blinking cursor. Same monospace, larger and centered.
- Single `[ VERIFY ]` button below the input.
- Nothing else. No provider picker, stage selector, research toggle, model name, or history rail.

**Under the hood on Verify:**

- 2 stages: Claude Sonnet 4.5 → Grok-3-fast (revised 2026-04-22 from Gemini 2.5 Flash — user preference for provider diversity with Grok over Gemini).
- Live Research always on.
- Judge runs silently, producing structured scoring that gets collapsed to the single trust score.
- No streaming to the user — single compact progress indicator: `[ VERIFYING ... 2 AIs, 5 sources ]`. Result lands all at once.

**Pro toggle** switches routes (`/` → `/pro`), no data loss, no confirmation modal.

## § 2 — Result screen & trust score

**Layout top-to-bottom:**

1. User's original question, quoted and dim at the top.
2. `[VERIFIED]` banner with the trust score as one large number (e.g. `94%`). Color reflects the band. One-line context underneath: *"3 AIs agreed · 5 sources confirmed."*
3. The answer itself, rendered as markdown but in monospace — feels like a receipt from a machine.
4. Collapsed `[ sources ]` disclosure. Click to expand: 5 web sources each tagged `✓ VERIFIED` or `✗ BROKEN` (reusing URL verification shipped in commit `a81ddb4`). First 2 previewed, rest behind the disclosure.
5. `[ ASK ANOTHER ]` primary button (resets to input). Subtle `[ see how it was verified ]` link expands hidden Judge details (per-stage scores, provenance) for the curious.

**Trust-score derivation.** Collapse Judge output into a single 0–100 percentage using:
`trust_score = judge_confidence × url_verification_rate × average_source_credibility`

This is a deterministic calculation, not an additional LLM call. If any stage errors, the result shows `[ COULD NOT VERIFY ]` instead of a fabricated score.

**Trust-score bands:**

| Score | Label | Color |
|---|---|---|
| ≥85 | Highly verified | Green |
| 60–84 | Partially verified | Amber |
| <60 | Low confidence — treat with skepticism | Red |

Low-confidence results still show the answer but wrapped in a caution visual — this is where Rosin most proves its worth vs. single-LLM tools.

## § 3 — Free tier architecture

**Identity required upfront.** No query fires without authentication. Three options, all ending in a server session token:

- Email + magic link (Resend or equivalent).
- Sign in with Google (OAuth).
- Sign in with Apple (OAuth).

**Bot protection.** Cloudflare Turnstile on the email signup path only. OAuth flows are already bot-resistant.

**Metering.**

- **Lifetime 3 free queries per account**, no monthly reset. Burn them → BYO keys or leave.
- Per-account rate limit: 1 query per 15 seconds.
- Hard server-side monthly spend cap of **$50** on the hosted proxy. If free-tier aggregate spend crosses it, the free tier pauses until the calendar month rolls over. Protects the wallet even if abuse slips through.

**Server changes (web).**

- New endpoint `POST /api/verify/hosted` — runs the 2-stage novice pipeline with server-side API keys. Requires a valid session token. Decrements the account's `queries_used` counter.
- Existing `POST /api/verify` unchanged — remains the BYO path for Pro mode and post-free-tier users.
- New Drizzle tables:
  - `accounts` (id, email, auth_provider, queries_used, created_at)
  - `sessions` (standard token table)
- No query content persisted. Stateless verification preserved.

**Cost framing.** 2 stages + Live Research on Sonnet + Grok-3-fast ≈ $0.03/query (Grok-3-fast is ~4× Gemini Flash). 3 lifetime queries × 1,000 signups ≈ $90/month if every account maxes out, which exceeds the $50 cap — hence the cap now caps exposure earlier, meaning the free tier will pause mid-month under heavy sustained signup. Acceptable trade for provider diversity; revisit cap at launch.

**Implementation-scope warning.** §3 is roughly 60% of the total build effort. The UI work in §1 + §2 does not depend on it — novice mode can ship as a BYO-only UX pass first, and §3 can be bolted on later without rework.

## § 4 — iOS parity

iOS inherits both the novice UI and the hosted free-tier flow.

**First-launch flow (novice mode = default):**

1. Sign-in screen with three buttons: `Apple` (top — App Store convention + native one-tap), `Google`, `Email`.
2. After auth, land on the simplified novice input screen (mirror of web).
3. `POST https://rosin.app/api/verify/hosted` carries the session token. Existing `SSELineParser` parses the response stream.

**After 3 free queries:** Gate screen — *"You've used your 3 free queries. Add your own API keys to keep going."* Deep links to Anthropic, Google, and xAI key-generation pages. Once keys are entered, iOS switches to direct-to-LLM calls (existing code path); the backend drops out of the novice flow for that user.

**Pro mode:** Toggled from Settings. Uses the current terminal UI, unchanged. BYO keys only, no backend calls. All 34 existing Swift files preserved.

**New iOS modules:**

- `AuthService` — wraps AuthenticationServices (Apple), Google Sign-In SDK, email magic-link via universal links. Session token persisted in Keychain.
- `HostedVerificationService` — streaming service that POSTs to `/api/verify/hosted` and parses the shared SSE format.
- Two new SwiftUI views: sign-in and post-free-tier gate.
- Novice-mode versions of `TerminalView` and result view (simplified, trust-score banner).

**Untouched on iOS:**

- The three existing streaming services (`AnthropicStreamingService`, `GeminiStreamingService`, `XAIStreamingService`).
- `VerificationPipelineManager` — from its perspective, the hosted path is a fourth "provider."
- Keychain layer — now stores session tokens alongside existing API keys.

**Persona-B reach caveat.** A casual iOS user still won't paste API keys after burning their 3 free queries. iOS's primary audience after the free tier is users who already have keys. Casual-user reach is concentrated on web, where signup → 3 free queries → soft churn is an acceptable funnel.

## § 5 — Pro toggle mechanics

**Placement:**

- Web: small `[ PRO → ]` link in top-right in novice mode; `[ ← NOVICE ]` link in pro mode. No modal, no confirmation — it's a route switch.
- iOS: toggle in Settings. Switching rebuilds the scene into the opposite mode's root view.

**Web routes:**

- `/` → novice mode (public landing).
- `/pro` → existing terminal UI, unchanged. Indexable, shareable.

**State persistence:**

- Web: `localStorage.rosin.mode = "novice" | "pro"`. First visit defaults to novice. Toggling is sticky. Direct URL access always wins over the flag.
- iOS: same concept via `UserDefaults`.

**What Pro mode does NOT get:**

- The hosted free tier — Pro is BYO-only, always. Rationale: the free tier exists to convert casual users into BYO or churned users, not to subsidize power users.
- The single-number trust score banner — Pro continues to show the full per-stage scoring, Judge structured output, provenance tracking, and export tooling already in place.

**What Pro mode shares with Novice mode (no duplication):**

- The server verification pipeline logic.
- iOS `VerificationPipelineManager`.
- URL verification + credibility scoring (commit `a81ddb4`).
- The Judge — runs in both modes. Novice collapses to a trust score; Pro shows everything.
- All LLM provider streaming services.

## Architecture summary

**Web:**

```
/                        → NoviceLanding (React)
  ↓ Verify
POST /api/verify/hosted  → Auth check, meter check, 2-stage pipeline with server keys
  ↓ SSE stream
NoviceResult (React)     → Trust score banner + answer + sources

/pro                     → Existing TerminalPage (unchanged)
  ↓ Verify
POST /api/verify         → BYO keys, existing multi-stage pipeline
```

**iOS:**

```
App launch
  ↓
AuthGate (novice only) → Apple / Google / Email
  ↓ session token
NoviceTerminalView
  ↓ Verify
HostedVerificationService → POST /api/verify/hosted
  ↓ SSE via SSELineParser
NoviceResultView (trust score + answer)

After 3 queries → FreeGateView → deep link to BYO key setup → existing direct-to-LLM path

Settings → Pro toggle → existing TerminalView (BYO keys, unchanged)
```

**Shared pipeline:** verification logic, Judge, URL verification, credibility scoring — all unchanged, reused in both modes.

## Scope boundary

In scope for this spec:

- Novice UI (web + iOS)
- Trust score calculation & banner
- Hosted `/api/verify/hosted` endpoint
- Auth (three providers) + accounts + sessions
- Metering + monthly spend cap
- Pro toggle + route split
- iOS auth flows + hosted streaming service

Out of scope (deliberately deferred):

- Payments / subscriptions. If free-tier conversion proves desirable, design as a follow-up spec.
- Saved history / shareable answers. Rosin stays stateless.
- iOS-specific casual-user funnel. Web is the casual-user front door; iOS novice mode primarily helps existing-key users.
- Classifier-based adaptive stage routing. Deferred; fixed 2 stages for novice is the v1.
- Additional auth providers (GitHub, Microsoft, etc.). Three is enough.

## Open questions to resolve during planning

These don't block the design; they'll be answered during implementation planning:

1. Exact Judge-output-to-percentage formula: need to tune weights so the bands feel right on real queries.
2. Email provider choice (Resend vs. Postmark vs. Amazon SES).
3. Session token lifetime and refresh strategy.
4. Monthly spend cap enforcement point — check before every hosted query, or async sweep?
5. Novice-mode copy in detail — labels, error states, empty state, free-tier-exhausted messaging.
6. Google Sign-In iOS SDK vs. raw OAuth flow.
7. Analytics: do we track *any* events in novice mode, even anonymized (query count, trust-score distribution, conversion-to-BYO rate)? If yes, privacy-respecting only.
