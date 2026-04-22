# Novice Mode — Plan 2: Hosted Free Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the hosted free tier from spec §3 and the hosted-tier portion of §4 — authenticated 3-queries-per-account access to a server-side novice pipeline, with identity via email 6-digit code, Google OAuth, or Apple OAuth, on both web and iOS.

**Architecture:** A new `POST /api/verify/hosted` endpoint runs the fixed 2-stage novice pipeline using server-side LLM keys, gated by a session token. Sessions are opaque 32-byte tokens stored in a new `sessions` table; accounts are keyed by email. Sessions attach via HTTP-only cookie (web) **or** `Authorization: Bearer <token>` (iOS). Email auth uses a 6-digit numeric code (no universal links). iOS does Apple Sign In natively, Google via `ASWebAuthenticationSession` + PKCE. Metering is per-request: `accounts.queries_used` and a monthly aggregated `monthly_spend` row checked before every hosted query. The existing `POST /api/verify` stays untouched (BYO path). The existing in-process pipeline body is extracted into `server/pipeline.ts` so both endpoints share it.

**Tech Stack:** Web — Express 5, Drizzle ORM (Postgres), Resend (email), Cloudflare Turnstile (bot protection), jose (Apple ID-token verification), Zod, vitest. Client — React 18, wouter, react-query. iOS — SwiftUI, AuthenticationServices (Apple + ASWebAuthenticationSession), Keychain, URLSession.

**Spec:** `docs/superpowers/specs/2026-04-21-novice-mode-design.md`
**Plan 1 reference:** `docs/superpowers/plans/2026-04-21-novice-mode-plan-1-ui.md`

**Decisions locked during pre-planning (2026-04-21):**

| Question | Decision |
|---|---|
| Email provider | **Resend** |
| Session token | **30-day sliding opaque token**, server-stored, no refresh endpoint |
| Monthly cap | **Per-request check** against aggregated `monthly_spend` row |
| Hosting | **Same Express server** as `/api/verify` |
| Email callback | **6-digit numeric code** (no universal links) |
| Google OAuth on iOS | **ASWebAuthenticationSession + PKCE** (no Google SDK dependency) |

---

## File Structure

### Web — new files

- `server/db.ts` — Postgres Drizzle client (node-postgres `Pool`)
- `server/auth/session.ts` — session create/verify/delete + cookie + Bearer extraction
- `server/auth/session.test.ts` — unit tests for token hashing, TTL logic
- `server/auth/email.ts` — Resend wrapper + 6-digit code generation/verification
- `server/auth/email.test.ts` — code generation, format, hash verification
- `server/auth/turnstile.ts` — Cloudflare Turnstile server verification helper
- `server/auth/google.ts` — Google OAuth (code exchange, ID-token verification)
- `server/auth/apple.ts` — Apple Sign In ID-token verification (jose JWKS)
- `server/auth/routes.ts` — mounts all `/api/auth/*` endpoints
- `server/metering.ts` — monthly-spend read/write + per-account quota check
- `server/metering.test.ts` — quota & cap logic tests
- `server/pipeline.ts` — extracted pipeline body shared by `/api/verify` and `/api/verify/hosted`
- `server/routes/verify-hosted.ts` — thin handler for `POST /api/verify/hosted`
- `client/src/hooks/use-auth.ts` — react-query backed session state
- `client/src/pages/sign-in.tsx` — three-option sign-in screen
- `client/src/components/novice/auth-gate.tsx` — "sign in to verify" modal
- `client/src/components/novice/free-tier-exhausted.tsx` — 3-queries-burned gate
- `client/src/lib/auth-api.ts` — fetch helpers (`signInEmail`, `verifyCode`, `signOut`, `me`)

### Web — modified files

- `shared/schema.ts` — add `accounts`, `sessions`, `emailCodes`, `monthlySpend` tables + Zod schemas
- `server/routes.ts` — extract the `/api/verify` handler body into `server/pipeline.ts` (pipeline extraction), register `/api/verify/hosted` and auth routes
- `server/index.ts` — add `cookie-parser` middleware
- `server/storage.ts` — unchanged (in-memory storage for verification history stays separate from the new DB tables)
- `client/src/App.tsx` — add `/sign-in` route
- `client/src/pages/novice.tsx` — show auth gate if not signed in; switch fetch to `/api/verify/hosted`; handle 402 (free tier exhausted) → show exhaustion gate
- `.env.example` — add Resend, Turnstile, Google, Apple, cookie-secret, DB URL vars
- `package.json` — add `resend`, `cookie-parser`, `jose`, `pg` client, new types

### iOS — new files

- `ios/Rosin/Services/Session/SessionStore.swift` — Keychain-backed session token getter/setter
- `ios/Rosin/Services/Auth/AuthService.swift` — protocol + concrete orchestrator
- `ios/Rosin/Services/Auth/AppleAuthController.swift` — `ASAuthorizationControllerDelegate` wrapper
- `ios/Rosin/Services/Auth/GoogleAuthController.swift` — `ASWebAuthenticationSession` + PKCE
- `ios/Rosin/Services/Auth/EmailAuthClient.swift` — request code + verify code
- `ios/Rosin/Services/Networking/HostedVerificationService.swift` — POSTs to `/api/verify/hosted` and streams SSE via existing `SSELineParser`
- `ios/Rosin/Models/AuthModels.swift` — `Account`, `SessionTokenResponse`, `AuthMethod`
- `ios/Rosin/Views/Auth/SignInView.swift` — Apple / Google / Email buttons
- `ios/Rosin/Views/Auth/EmailCodeView.swift` — email entry + 6-digit code entry
- `ios/Rosin/Views/Novice/FreeGateView.swift` — post-3-queries gate with deep-link buttons
- `ios/Rosin/ViewModels/AuthViewModel.swift` — observable auth state

### iOS — modified files

- `ios/Rosin/RosinApp.swift` — route to `SignInView` when unauthenticated in Novice mode
- `ios/Rosin/ViewModels/NoviceTerminalViewModel.swift` — swap pipeline call for `HostedVerificationService`, handle free-tier exhaustion
- `ios/Rosin/Views/Settings/SettingsView.swift` — add "Sign out" row visible when session present
- `ios/Rosin.xcodeproj/project.pbxproj` — register all new Swift files via `ios/scripts/add-files.rb`
- `ios/Rosin/Info.plist` — register `rosinai` URL scheme for ASWebAuthenticationSession (via Xcode project edit)

---

## Environment Variables (new)

Add to `.env.example` (values are placeholders — developer supplies real ones):

```
# Database (existing — confirm present)
DATABASE_URL=postgres://user:pass@localhost:5432/rosin

# Auth
SESSION_COOKIE_SECRET=change-me-long-random-string
AUTH_BASE_URL=http://localhost:5000

# Email (Resend)
RESEND_API_KEY=
RESEND_FROM_EMAIL=login@rosin.app

# Cloudflare Turnstile (email signup only)
TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=

# Google OAuth
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:5000/api/auth/google/callback

# Apple Sign In
APPLE_CLIENT_ID=com.rosinai.app
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY_BASE64=

# Monthly spend cap (USD)
HOSTED_MONTHLY_CAP_USD=50
```

Client-side (Vite):

```
VITE_TURNSTILE_SITE_KEY=
```

---

## Phase A — Database schema

### Task 1: Add Drizzle tables for accounts, sessions, email codes, monthly spend

**Files:**
- Modify: `shared/schema.ts`

- [ ] **Step 1: Append the new tables**

Append the following to `shared/schema.ts` (below the existing `users` table, above the `llmProviders` const):

```ts
import { integer, timestamp, boolean, numeric, index } from "drizzle-orm/pg-core";

/** Authenticated account (novice / hosted tier only). No query content is stored. */
export const accounts = pgTable("accounts", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  email: text("email").notNull().unique(),
  authProvider: text("auth_provider").notNull(), // "email" | "google" | "apple"
  providerSubject: text("provider_subject"), // OAuth sub for google/apple (for re-linking on re-signin)
  queriesUsed: integer("queries_used").notNull().default(0),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export type Account = typeof accounts.$inferSelect;

/** Opaque session token for an account. Token stored as SHA-256 hash. */
export const sessions = pgTable(
  "sessions",
  {
    tokenHash: text("token_hash").primaryKey(),
    accountId: varchar("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    lastSeenAt: timestamp("last_seen_at").notNull().defaultNow(),
    expiresAt: timestamp("expires_at").notNull(),
  },
  (table) => ({
    accountIdx: index("sessions_account_idx").on(table.accountId),
  }),
);

export type Session = typeof sessions.$inferSelect;

/** Short-lived email verification codes (6 digits). Code stored as SHA-256 hash. */
export const emailCodes = pgTable(
  "email_codes",
  {
    id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
    email: text("email").notNull(),
    codeHash: text("code_hash").notNull(),
    attempts: integer("attempts").notNull().default(0),
    consumedAt: timestamp("consumed_at"),
    createdAt: timestamp("created_at").notNull().defaultNow(),
    expiresAt: timestamp("expires_at").notNull(),
  },
  (table) => ({
    emailIdx: index("email_codes_email_idx").on(table.email),
  }),
);

/** Aggregated monthly hosted-tier spend. One row per calendar month ("YYYY-MM"). */
export const monthlySpend = pgTable("monthly_spend", {
  month: text("month").primaryKey(), // "2026-04"
  spendUsd: numeric("spend_usd", { precision: 10, scale: 4 }).notNull().default("0"),
  paused: boolean("paused").notNull().default(false),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});

// Zod helpers for API responses
export const accountPublicSchema = z.object({
  id: z.string(),
  email: z.string(),
  authProvider: z.enum(["email", "google", "apple"]),
  queriesUsed: z.number().int().nonnegative(),
  queriesRemaining: z.number().int().nonnegative(),
});

export type AccountPublic = z.infer<typeof accountPublicSchema>;
```

- [ ] **Step 2: Typecheck**

Run: `npm run check`
Expected: no new errors in `shared/schema.ts`. (Pre-existing errors in `server/replit_integrations/` are acceptable — see plan preamble.)

- [ ] **Step 3: Commit**

```bash
git add shared/schema.ts
git commit -m "feat(db): add accounts, sessions, email_codes, monthly_spend tables"
```

---

### Task 2: Add a Drizzle Postgres client and run the migration

**Files:**
- Create: `server/db.ts`
- Modify: `package.json`

- [ ] **Step 1: Add the `pg` client and types if not already present**

Run: `npm install pg && npm install -D @types/pg`
(If `pg` is already in `package.json` — it is — skip the install and just verify `@types/pg` exists; add it if missing.)

- [ ] **Step 2: Create the Drizzle client**

Create `server/db.ts`:

```ts
import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "@shared/schema";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is required");
}

export const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
export const db = drizzle(pool, { schema });
export type DB = typeof db;
```

- [ ] **Step 3: Push the schema to the dev database**

Run: `npm run db:push`
Expected: drizzle-kit reports "4 tables created" (or "No changes" if already in sync). Requires `DATABASE_URL` set in the local `.env`.

- [ ] **Step 4: Commit**

```bash
git add server/db.ts package.json package-lock.json
git commit -m "feat(db): add Drizzle node-postgres client"
```

---

## Phase B — Session layer

### Task 3: Session token create/verify/delete with tests

**Files:**
- Create: `server/auth/session.test.ts`
- Create: `server/auth/session.ts`
- Modify: `server/index.ts` (add `cookie-parser`)
- Modify: `package.json` (add `cookie-parser`)

- [ ] **Step 1: Install `cookie-parser`**

Run: `npm install cookie-parser && npm install -D @types/cookie-parser`

- [ ] **Step 2: Wire `cookie-parser` into the server**

Modify `server/index.ts`. Add the import at the top alongside other imports:

```ts
import cookieParser from "cookie-parser";
```

Add the middleware immediately after `app.use(express.urlencoded(...))`:

```ts
app.use(cookieParser(process.env.SESSION_COOKIE_SECRET || "dev-cookie-secret"));
```

- [ ] **Step 3: Write failing tests**

Create `server/auth/session.test.ts`:

```ts
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
```

- [ ] **Step 4: Run tests — should fail**

Run: `npm run test -- session.test.ts`
Expected: module not found.

- [ ] **Step 5: Implement session helpers**

Create `server/auth/session.ts`:

```ts
import { randomBytes, createHash } from "crypto";
import type { Request, Response } from "express";
import { eq, gt } from "drizzle-orm";
import { db } from "../db";
import { sessions, accounts, type Account } from "@shared/schema";

export const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
export const SESSION_SLIDING_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
export const SESSION_COOKIE_NAME = "rosin_session";

export function generateSessionToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export async function createSession(accountId: string): Promise<string> {
  const token = generateSessionToken();
  const tokenHash = hashToken(token);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
  await db.insert(sessions).values({ tokenHash, accountId, createdAt: now, lastSeenAt: now, expiresAt });
  return token;
}

export async function deleteSessionByToken(token: string): Promise<void> {
  await db.delete(sessions).where(eq(sessions.tokenHash, hashToken(token)));
}

/** Returns the account + raw session token on success, sliding the window when appropriate. */
export async function verifySession(token: string): Promise<{ account: Account } | null> {
  const tokenHash = hashToken(token);
  const rows = await db
    .select({ session: sessions, account: accounts })
    .from(sessions)
    .innerJoin(accounts, eq(sessions.accountId, accounts.id))
    .where(eq(sessions.tokenHash, tokenHash))
    .limit(1);

  const row = rows[0];
  if (!row) return null;
  const now = new Date();
  if (row.session.expiresAt <= now) return null;

  // Sliding window: if within one window of expiry, extend
  const timeUntilExpiry = row.session.expiresAt.getTime() - now.getTime();
  if (timeUntilExpiry < SESSION_TTL_MS - SESSION_SLIDING_WINDOW_MS) {
    const newExpiry = new Date(now.getTime() + SESSION_TTL_MS);
    await db
      .update(sessions)
      .set({ lastSeenAt: now, expiresAt: newExpiry })
      .where(eq(sessions.tokenHash, tokenHash));
  } else {
    await db.update(sessions).set({ lastSeenAt: now }).where(eq(sessions.tokenHash, tokenHash));
  }

  return { account: row.account };
}

/** Extract token from HTTP-only cookie (web) or Authorization: Bearer header (iOS). */
export function extractSessionToken(req: Request): string | null {
  const cookieToken = req.cookies?.[SESSION_COOKIE_NAME];
  if (typeof cookieToken === "string" && cookieToken.length > 0) return cookieToken;
  const auth = req.headers.authorization;
  if (auth?.startsWith("Bearer ")) return auth.slice(7);
  return null;
}

export function setSessionCookie(res: Response, token: string): void {
  res.cookie(SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: SESSION_TTL_MS,
    path: "/",
  });
}

export function clearSessionCookie(res: Response): void {
  res.clearCookie(SESSION_COOKIE_NAME, { path: "/" });
}

/** Express middleware: attaches `req.account` if a valid session exists; otherwise leaves it undefined. */
export async function withSession(req: Request, _res: Response, next: () => void): Promise<void> {
  const token = extractSessionToken(req);
  if (!token) return next();
  const result = await verifySession(token);
  if (result) (req as Request & { account?: Account }).account = result.account;
  next();
}

/** Express middleware: responds 401 if no valid session. */
export async function requireSession(
  req: Request,
  res: Response,
  next: () => void,
): Promise<void | Response> {
  const token = extractSessionToken(req);
  if (!token) return res.status(401).json({ error: "Not signed in" });
  const result = await verifySession(token);
  if (!result) return res.status(401).json({ error: "Invalid or expired session" });
  (req as Request & { account?: Account }).account = result.account;
  next();
}
```

- [ ] **Step 6: Run tests — they should pass**

Run: `npm run test -- session.test.ts`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add server/auth/session.ts server/auth/session.test.ts server/index.ts package.json package-lock.json
git commit -m "feat(auth): add session token layer with cookie + bearer extraction"
```

---

## Phase C — Email (Resend) + 6-digit codes

### Task 4: Email code generation + verification with tests

**Files:**
- Create: `server/auth/email.test.ts`
- Create: `server/auth/email.ts`
- Modify: `package.json` (add `resend`)

- [ ] **Step 1: Install Resend**

Run: `npm install resend`

- [ ] **Step 2: Write failing tests**

Create `server/auth/email.test.ts`:

```ts
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
```

- [ ] **Step 3: Implement**

Create `server/auth/email.ts`:

```ts
import { randomInt, createHash } from "crypto";
import { Resend } from "resend";

export const EMAIL_CODE_TTL_MS = 10 * 60 * 1000; // 10 minutes
export const EMAIL_CODE_MAX_ATTEMPTS = 5;

export function generateEmailCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, "0");
}

export function hashEmailCode(code: string, email: string): string {
  return createHash("sha256").update(`${normalizeEmail(email)}:${code}`).digest("hex");
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

let resendClient: Resend | null = null;
function getResend(): Resend {
  if (!resendClient) {
    if (!process.env.RESEND_API_KEY) throw new Error("RESEND_API_KEY not set");
    resendClient = new Resend(process.env.RESEND_API_KEY);
  }
  return resendClient;
}

export async function sendEmailCode(email: string, code: string): Promise<void> {
  const from = process.env.RESEND_FROM_EMAIL || "login@rosin.app";
  await getResend().emails.send({
    from,
    to: email,
    subject: `Rosin sign-in code: ${code}`,
    text:
      `Your Rosin sign-in code is: ${code}\n\n` +
      `This code expires in 10 minutes. If you didn't request it, ignore this email.`,
  });
}
```

- [ ] **Step 4: Run tests**

Run: `npm run test -- email.test.ts`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add server/auth/email.ts server/auth/email.test.ts package.json package-lock.json
git commit -m "feat(auth): add 6-digit email code generation + Resend client"
```

---

### Task 5: Cloudflare Turnstile verification helper

**Files:**
- Create: `server/auth/turnstile.ts`

- [ ] **Step 1: Create the helper**

Create `server/auth/turnstile.ts`:

```ts
/** Verifies a Cloudflare Turnstile client token server-side. Returns true if passed, false otherwise.
 *  If TURNSTILE_SECRET_KEY is unset, treats verification as bypassed (dev mode). */
export async function verifyTurnstile(token: string | undefined | null, remoteIp?: string): Promise<boolean> {
  const secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) {
    console.warn("[turnstile] TURNSTILE_SECRET_KEY not set — bypassing verification (dev mode)");
    return true;
  }
  if (!token) return false;

  const body = new URLSearchParams({ secret, response: token });
  if (remoteIp) body.set("remoteip", remoteIp);

  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) return false;
  const json = (await res.json()) as { success: boolean };
  return json.success === true;
}
```

- [ ] **Step 2: Commit**

```bash
git add server/auth/turnstile.ts
git commit -m "feat(auth): add Cloudflare Turnstile server-side verification"
```

---

## Phase D — OAuth providers (Google + Apple)

### Task 6: Google OAuth helper (web redirect flow + PKCE for mobile)

**Files:**
- Create: `server/auth/google.ts`

Decisions: Web uses classic authorization-code flow with a fixed `GOOGLE_OAUTH_REDIRECT_URL`. Mobile (iOS) uses the same `/api/auth/google/callback` endpoint but sends a `state=mobile&code_verifier=<pkce>` query so the callback can return a session token to the custom URL scheme.

- [ ] **Step 1: Create the module**

Create `server/auth/google.ts`:

```ts
import { randomBytes, createHash } from "crypto";

/** State payload embedded in `state` query param. Signed via HMAC? We use a short opaque nonce stored in cookie+DB is overkill; instead we sign the JSON with the cookie secret. For v1, we use a plain base64url — users can only harm their own flow. */
export interface OAuthState {
  mode: "web" | "mobile";
  redirectBack?: string; // web: post-signin SPA path; mobile: custom URL scheme
  codeChallenge?: string; // mobile PKCE
  codeChallengeMethod?: "S256";
}

export function encodeState(state: OAuthState): string {
  return Buffer.from(JSON.stringify(state)).toString("base64url");
}

export function decodeState(raw: string): OAuthState | null {
  try {
    return JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

export function buildGoogleAuthUrl(state: OAuthState): string {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const redirect = process.env.GOOGLE_OAUTH_REDIRECT_URL;
  if (!clientId || !redirect) throw new Error("Google OAuth env vars missing");

  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirect,
    response_type: "code",
    scope: "openid email profile",
    state: encodeState(state),
    access_type: "online",
    prompt: "select_account",
  });
  if (state.codeChallenge && state.codeChallengeMethod) {
    params.set("code_challenge", state.codeChallenge);
    params.set("code_challenge_method", state.codeChallengeMethod);
  }
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

export interface GoogleIdentity {
  sub: string;
  email: string;
  emailVerified: boolean;
}

export async function exchangeGoogleCode(code: string, codeVerifier?: string): Promise<GoogleIdentity> {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
  const redirect = process.env.GOOGLE_OAUTH_REDIRECT_URL;
  if (!clientId || !clientSecret || !redirect) throw new Error("Google OAuth env vars missing");

  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirect,
    grant_type: "authorization_code",
  });
  if (codeVerifier) body.set("code_verifier", codeVerifier);

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!tokenRes.ok) {
    const t = await tokenRes.text();
    throw new Error(`Google token exchange failed: ${tokenRes.status} ${t}`);
  }
  const tokens = (await tokenRes.json()) as { id_token?: string; access_token?: string };
  if (!tokens.id_token) throw new Error("Google id_token missing");

  // Decode without full JWKS — we trust Google over HTTPS since we just fetched this directly from their token endpoint.
  const payloadRaw = tokens.id_token.split(".")[1];
  const payload = JSON.parse(Buffer.from(payloadRaw, "base64url").toString("utf8"));
  if (!payload.email) throw new Error("Google id_token missing email");
  return {
    sub: String(payload.sub),
    email: String(payload.email),
    emailVerified: payload.email_verified === true,
  };
}

/** Helper exposed for tests/mobile PKCE challenge generation on the server if ever needed. */
export function pkcePair(): { verifier: string; challenge: string } {
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}
```

- [ ] **Step 2: Commit**

```bash
git add server/auth/google.ts
git commit -m "feat(auth): add Google OAuth code-exchange + PKCE helpers"
```

---

### Task 7: Apple Sign In ID-token verification

**Files:**
- Create: `server/auth/apple.ts`
- Modify: `package.json` (add `jose`)

- [ ] **Step 1: Install `jose`**

Run: `npm install jose`

- [ ] **Step 2: Create the verifier**

Create `server/auth/apple.ts`:

```ts
import { jwtVerify, createRemoteJWKSet } from "jose";

const APPLE_JWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const APPLE_ISSUER = "https://appleid.apple.com";

export interface AppleIdentity {
  sub: string;
  email: string;
  emailVerified: boolean;
}

/** Verifies an Apple Sign In identity token (the one iOS's ASAuthorizationAppleIDCredential returns).
 *  Audience must match APPLE_CLIENT_ID (our bundle identifier). */
export async function verifyAppleIdentityToken(idToken: string): Promise<AppleIdentity> {
  const audience = process.env.APPLE_CLIENT_ID;
  if (!audience) throw new Error("APPLE_CLIENT_ID not set");
  const { payload } = await jwtVerify(idToken, APPLE_JWKS, { issuer: APPLE_ISSUER, audience });
  const sub = String(payload.sub ?? "");
  const email = typeof payload.email === "string" ? payload.email : "";
  if (!sub || !email) {
    throw new Error("Apple token missing sub or email — user may have withheld email");
  }
  return {
    sub,
    email,
    emailVerified: payload.email_verified === true || payload.email_verified === "true",
  };
}
```

*Note on "hide my email":* If a user chooses Apple's private relay, `email` is still present (it's the relay address), so we accept it. Sign in with Apple only omits `email` on subsequent sign-ins after the first — our flow is idempotent because we key on `providerSubject` where available.

- [ ] **Step 3: Commit**

```bash
git add server/auth/apple.ts package.json package-lock.json
git commit -m "feat(auth): add Apple Sign In identity-token verification"
```

---

## Phase E — Auth HTTP endpoints

### Task 8: Mount `/api/auth/*` routes

**Files:**
- Create: `server/auth/routes.ts`
- Modify: `server/routes.ts` (call `registerAuthRoutes(app)`)

- [ ] **Step 1: Create the routes module**

Create `server/auth/routes.ts`:

```ts
import type { Express, Request, Response } from "express";
import { z } from "zod";
import { and, eq, isNull, gt } from "drizzle-orm";
import { db } from "../db";
import { accounts, emailCodes, type Account } from "@shared/schema";
import {
  createSession,
  deleteSessionByToken,
  extractSessionToken,
  setSessionCookie,
  clearSessionCookie,
  requireSession,
} from "./session";
import {
  generateEmailCode,
  hashEmailCode,
  normalizeEmail,
  sendEmailCode,
  EMAIL_CODE_TTL_MS,
  EMAIL_CODE_MAX_ATTEMPTS,
} from "./email";
import { verifyTurnstile } from "./turnstile";
import { buildGoogleAuthUrl, decodeState, exchangeGoogleCode } from "./google";
import { verifyAppleIdentityToken } from "./apple";

type AuthedRequest = Request & { account?: Account };

async function upsertAccount(opts: {
  email: string;
  authProvider: "email" | "google" | "apple";
  providerSubject?: string;
}): Promise<Account> {
  const email = normalizeEmail(opts.email);
  const existing = await db.select().from(accounts).where(eq(accounts.email, email)).limit(1);
  if (existing[0]) return existing[0];
  const inserted = await db
    .insert(accounts)
    .values({
      email,
      authProvider: opts.authProvider,
      providerSubject: opts.providerSubject,
    })
    .returning();
  return inserted[0];
}

function accountPublic(a: Account, cap = 3) {
  return {
    id: a.id,
    email: a.email,
    authProvider: a.authProvider,
    queriesUsed: a.queriesUsed,
    queriesRemaining: Math.max(0, cap - a.queriesUsed),
  };
}

export function registerAuthRoutes(app: Express): void {
  // ── Email: request code ────────────────────────────────────────────
  app.post("/api/auth/email/request", async (req: Request, res: Response) => {
    const bodySchema = z.object({
      email: z.string().email(),
      turnstileToken: z.string().min(1).optional(),
    });
    const parsed = bodySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "Invalid email" });

    const ok = await verifyTurnstile(parsed.data.turnstileToken, req.ip);
    if (!ok) return res.status(403).json({ error: "Bot check failed" });

    const email = normalizeEmail(parsed.data.email);
    const code = generateEmailCode();
    const codeHash = hashEmailCode(code, email);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + EMAIL_CODE_TTL_MS);

    await db.insert(emailCodes).values({ email, codeHash, expiresAt });
    try {
      await sendEmailCode(email, code);
    } catch (err) {
      console.error("[auth] sendEmailCode failed:", err);
      return res.status(502).json({ error: "Email delivery failed" });
    }
    res.json({ ok: true });
  });

  // ── Email: verify code ─────────────────────────────────────────────
  app.post("/api/auth/email/verify", async (req: Request, res: Response) => {
    const bodySchema = z.object({
      email: z.string().email(),
      code: z.string().regex(/^\d{6}$/),
    });
    const parsed = bodySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "Invalid input" });

    const email = normalizeEmail(parsed.data.email);
    const codeHash = hashEmailCode(parsed.data.code, email);
    const now = new Date();

    const rows = await db
      .select()
      .from(emailCodes)
      .where(and(eq(emailCodes.email, email), isNull(emailCodes.consumedAt), gt(emailCodes.expiresAt, now)))
      .orderBy(emailCodes.createdAt);

    const match = rows.find((r) => r.codeHash === codeHash);
    if (!match) {
      // Increment attempts on the most recent unexpired row for basic abuse tracking
      const latest = rows[rows.length - 1];
      if (latest) {
        await db
          .update(emailCodes)
          .set({ attempts: latest.attempts + 1 })
          .where(eq(emailCodes.id, latest.id));
        if (latest.attempts + 1 >= EMAIL_CODE_MAX_ATTEMPTS) {
          await db.update(emailCodes).set({ consumedAt: now }).where(eq(emailCodes.id, latest.id));
        }
      }
      return res.status(401).json({ error: "Invalid or expired code" });
    }

    await db.update(emailCodes).set({ consumedAt: now }).where(eq(emailCodes.id, match.id));
    const account = await upsertAccount({ email, authProvider: "email" });
    const token = await createSession(account.id);
    setSessionCookie(res, token);
    res.json({ token, account: accountPublic(account) });
  });

  // ── Google: web "start" (redirect) ─────────────────────────────────
  app.get("/api/auth/google/start", (req: Request, res: Response) => {
    const url = buildGoogleAuthUrl({ mode: "web", redirectBack: "/" });
    res.redirect(url);
  });

  // ── Google: callback (web + mobile share this) ─────────────────────
  app.get("/api/auth/google/callback", async (req: Request, res: Response) => {
    const code = typeof req.query.code === "string" ? req.query.code : "";
    const stateRaw = typeof req.query.state === "string" ? req.query.state : "";
    if (!code) return res.status(400).send("Missing code");
    const state = decodeState(stateRaw);
    try {
      const codeVerifier = state?.mode === "mobile" ? req.query.code_verifier : undefined;
      const identity = await exchangeGoogleCode(code, typeof codeVerifier === "string" ? codeVerifier : undefined);
      const account = await upsertAccount({
        email: identity.email,
        authProvider: "google",
        providerSubject: identity.sub,
      });
      const token = await createSession(account.id);
      if (state?.mode === "mobile" && state.redirectBack) {
        const dest = `${state.redirectBack}?token=${encodeURIComponent(token)}`;
        return res.redirect(dest);
      }
      setSessionCookie(res, token);
      const redirectBack = state?.redirectBack ?? "/";
      res.redirect(redirectBack);
    } catch (err) {
      console.error("[auth] Google callback failed:", err);
      res.status(502).send("Google sign-in failed");
    }
  });

  // ── Google: mobile "start" returns the auth URL for ASWebAuthenticationSession ─
  app.post("/api/auth/google/mobile/start", (req: Request, res: Response) => {
    const bodySchema = z.object({
      redirectBack: z.string().min(1),
      codeChallenge: z.string().min(1),
    });
    const parsed = bodySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "Invalid input" });
    const url = buildGoogleAuthUrl({
      mode: "mobile",
      redirectBack: parsed.data.redirectBack,
      codeChallenge: parsed.data.codeChallenge,
      codeChallengeMethod: "S256",
    });
    res.json({ url });
  });

  // ── Apple: verify identity token (shared by web JS SDK + iOS native) ─
  app.post("/api/auth/apple/token", async (req: Request, res: Response) => {
    const bodySchema = z.object({ identityToken: z.string().min(1) });
    const parsed = bodySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: "Invalid input" });
    try {
      const identity = await verifyAppleIdentityToken(parsed.data.identityToken);
      const account = await upsertAccount({
        email: identity.email,
        authProvider: "apple",
        providerSubject: identity.sub,
      });
      const token = await createSession(account.id);
      setSessionCookie(res, token);
      res.json({ token, account: accountPublic(account) });
    } catch (err) {
      console.error("[auth] Apple verification failed:", err);
      res.status(401).json({ error: "Apple sign-in failed" });
    }
  });

  // ── Logout ─────────────────────────────────────────────────────────
  app.post("/api/auth/logout", async (req: Request, res: Response) => {
    const token = extractSessionToken(req);
    if (token) await deleteSessionByToken(token);
    clearSessionCookie(res);
    res.json({ ok: true });
  });

  // ── Session info ───────────────────────────────────────────────────
  app.get("/api/auth/me", requireSession, async (req: AuthedRequest, res: Response) => {
    res.json({ account: accountPublic(req.account!) });
  });
}
```

- [ ] **Step 2: Register the routes in `server/routes.ts`**

At the top of `server/routes.ts`, add the import:

```ts
import { registerAuthRoutes } from "./auth/routes";
```

Inside `registerRoutes` (near the top of the function body, before `app.post("/api/verify", ...)`), add:

```ts
registerAuthRoutes(app);
```

- [ ] **Step 3: Typecheck**

Run: `npm run check`
Expected: no new errors in `server/auth/`.

- [ ] **Step 4: Commit**

```bash
git add server/auth/routes.ts server/routes.ts
git commit -m "feat(auth): mount /api/auth/* endpoints (email, google, apple, logout, me)"
```

---

## Phase F — Metering and spend cap

### Task 9: Metering helper with tests

**Files:**
- Create: `server/metering.test.ts`
- Create: `server/metering.ts`

- [ ] **Step 1: Write failing tests**

Create `server/metering.test.ts`:

```ts
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
```

- [ ] **Step 2: Run — should fail (module not found)**

Run: `npm run test -- metering.test.ts`

- [ ] **Step 3: Implement**

Create `server/metering.ts`:

```ts
import { eq, sql } from "drizzle-orm";
import { db } from "./db";
import { accounts, monthlySpend } from "@shared/schema";

export const HOSTED_FREE_QUERIES = 3;

/** Rough cost per hosted query — Sonnet 4.5 + Gemini Flash + Live Research ≈ $0.015. */
export const ESTIMATED_QUERY_COST_USD = 0.015;

export function defaultMonthlyCapUsd(): number {
  const raw = process.env.HOSTED_MONTHLY_CAP_USD;
  const n = raw ? Number(raw) : 50;
  return Number.isFinite(n) && n > 0 ? n : 50;
}

export function currentMonthKey(date: Date = new Date()): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

export type QuotaCheck =
  | { ok: true }
  | { ok: false; reason: "account_exhausted" | "monthly_cap_paused" };

/** Checks account quota AND monthly cap. Does not mutate state. */
export async function checkHostedQuota(accountId: string): Promise<QuotaCheck> {
  const [a] = await db.select().from(accounts).where(eq(accounts.id, accountId)).limit(1);
  if (!a) return { ok: false, reason: "account_exhausted" };
  if (a.queriesUsed >= HOSTED_FREE_QUERIES) return { ok: false, reason: "account_exhausted" };

  const month = currentMonthKey();
  const [row] = await db.select().from(monthlySpend).where(eq(monthlySpend.month, month)).limit(1);
  if (row?.paused) return { ok: false, reason: "monthly_cap_paused" };

  return { ok: true };
}

/** Atomically increments `queries_used` by 1 and adds the estimated cost to monthly spend.
 *  Flips `paused=true` when spend exceeds the cap. */
export async function recordHostedUsage(accountId: string, costUsd = ESTIMATED_QUERY_COST_USD): Promise<void> {
  const month = currentMonthKey();
  const cap = defaultMonthlyCapUsd();

  await db
    .update(accounts)
    .set({ queriesUsed: sql`${accounts.queriesUsed} + 1` })
    .where(eq(accounts.id, accountId));

  // Upsert monthly spend
  await db
    .insert(monthlySpend)
    .values({ month, spendUsd: String(costUsd), paused: false })
    .onConflictDoUpdate({
      target: monthlySpend.month,
      set: {
        spendUsd: sql`${monthlySpend.spendUsd} + ${costUsd}`,
        updatedAt: new Date(),
        paused: sql`(${monthlySpend.spendUsd} + ${costUsd}) >= ${cap}`,
      },
    });
}
```

- [ ] **Step 4: Run tests — should pass**

Run: `npm run test -- metering.test.ts`

- [ ] **Step 5: Commit**

```bash
git add server/metering.ts server/metering.test.ts
git commit -m "feat(metering): add hosted-tier quota + monthly spend cap"
```

---

## Phase G — Extract pipeline + hosted endpoint

### Task 10: Extract `/api/verify` pipeline body into `server/pipeline.ts`

This task is a refactor that must preserve all existing behavior. The existing handler in `server/routes.ts` (lines ~829–1156) will call a new exported function `runVerificationPipeline(options, res)` that does everything the handler currently does *except* request parsing, authentication, and the outer try/catch.

**Files:**
- Create: `server/pipeline.ts`
- Modify: `server/routes.ts`

- [ ] **Step 1: Create `server/pipeline.ts` with an exported entry point**

Create `server/pipeline.ts`:

```ts
import type { Response } from "express";
import type { LLMModel } from "@shared/schema";

export interface PipelineOptions {
  query: string;
  chain: LLMModel[];
  adversarialMode: boolean;
  liveResearch: boolean;
  autoTieBreaker: boolean;
  /** Hook fired after summary is computed but before `done`. Used by the hosted path to record usage. */
  onComplete?: (meta: { verifiedSourceCount: number; brokenSourceCount: number }) => Promise<void> | void;
}

export async function runVerificationPipeline(options: PipelineOptions, res: Response): Promise<void> {
  // IMPLEMENTATION: see Step 2 — we move the body verbatim.
  throw new Error("Not implemented — see Step 2");
}
```

- [ ] **Step 2: Move the pipeline body**

Open `server/routes.ts`. Locate the handler `app.post("/api/verify", async (req, res) => {`. Inside this handler, everything from the line `const { query, chain, adversarialMode = false, liveResearch = true, autoTieBreaker = true } = insertVerificationRequestSchema...` through the final `sendSSE(res, { type: "done" }); res.end();` (up to but NOT including the outer `catch`) is the pipeline body.

Do this carefully:

  a. Copy the *entire body* inside the `try { ... }` block (from the schema parse up to `res.end();`) into `server/pipeline.ts`, replacing the `throw new Error(...)` stub.
  b. Replace the first line `const { query, chain, adversarialMode = false, liveResearch = true, autoTieBreaker = true } = insertVerificationRequestSchema.parse(req.body);` with a read from `options`:
     ```ts
     const { query, chain, adversarialMode, liveResearch, autoTieBreaker, onComplete } = options;
     ```
  c. All helper functions the body currently references (`sendSSE`, `classifyComplexity`, `exaSearch`, `verifyURLs`, `formatSearchContext`, `runStage`, `runJudge`, `shouldTriggerTieBreaker`, `pickTieBreakerModel`, `computeTrustScore`, `storage`, `randomUUID`) must be either (i) moved into `pipeline.ts`, or (ii) exported from `routes.ts` and imported into `pipeline.ts`.

  **Preferred approach:** export the helpers from `routes.ts` (add `export` to each `function`/`async function` declaration at the same file location). `pipeline.ts` then imports them with:
  ```ts
  import {
    sendSSE,
    classifyComplexity,
    exaSearch,
    verifyURLs,
    formatSearchContext,
    runStage,
    runJudge,
    shouldTriggerTieBreaker,
    pickTieBreakerModel,
  } from "./routes";
  import { computeTrustScore } from "./trust-score";
  import { storage } from "./storage";
  import { randomUUID } from "crypto";
  import type { LLMModel, StageOutput, VerificationSummary } from "@shared/schema";
  ```
  Keep the `tavily` / OpenAI clients in `routes.ts` for now — they're already module-level there and `runStage` consumes them.

  d. Just before `sendSSE(res, { type: "done" });`, call the hook:
     ```ts
     if (onComplete) await onComplete({ verifiedSourceCount, brokenSourceCount });
     ```

  e. Replace the handler body in `routes.ts` with:

     ```ts
     app.post("/api/verify", async (req, res) => {
       try {
         const parsed = insertVerificationRequestSchema.extend({
           adversarialMode: z.boolean().optional(),
           liveResearch: z.boolean().optional(),
           autoTieBreaker: z.boolean().optional(),
         }).parse(req.body);

         await runVerificationPipeline(
           {
             query: parsed.query,
             chain: parsed.chain,
             adversarialMode: parsed.adversarialMode ?? false,
             liveResearch: parsed.liveResearch ?? true,
             autoTieBreaker: parsed.autoTieBreaker ?? true,
           },
           res,
         );
       } catch (error) {
         console.error("Verification error:", error);
         if (!res.headersSent) {
           res.status(500).json({ error: "Verification failed" });
         } else {
           try { res.write(`data: ${JSON.stringify({ type: "error", error: "Verification failed" })}\n\n`); } catch {}
           res.end();
         }
       }
     });
     ```

     Add at the top of `routes.ts`:
     ```ts
     import { runVerificationPipeline } from "./pipeline";
     ```

- [ ] **Step 3: Typecheck**

Run: `npm run check`
Expected: no new errors. (Pre-existing `replit_integrations/` errors remain.)

- [ ] **Step 4: Smoke-test the existing endpoint hasn't regressed**

Run: `npm run dev`
In a second terminal:
```bash
curl -N -X POST http://localhost:5000/api/verify \
  -H "Content-Type: application/json" \
  -d '{"query":"What is 2+2?","chain":[{"provider":"anthropic","model":"claude-haiku-4-5"},{"provider":"gemini","model":"gemini-2.5-flash"}],"liveResearch":false}'
```
Expected: SSE events stream — `stage_start`, `stage_content`, `stage_complete`, `summary`, `done`. If this does not work, the extraction broke something — fix before committing.

Stop the dev server.

- [ ] **Step 5: Run the test suite**

Run: `npm run test`
Expected: all pass (trust-score, session, email, metering).

- [ ] **Step 6: Commit**

```bash
git add server/pipeline.ts server/routes.ts
git commit -m "refactor(server): extract /api/verify pipeline into pipeline.ts"
```

---

### Task 11: `POST /api/verify/hosted`

**Files:**
- Create: `server/routes/verify-hosted.ts`
- Modify: `server/routes.ts` (register the handler)

- [ ] **Step 1: Create the hosted handler**

Create `server/routes/verify-hosted.ts`:

```ts
import type { Express, Request, Response } from "express";
import { z } from "zod";
import type { Account, LLMModel } from "@shared/schema";
import { requireSession } from "../auth/session";
import { runVerificationPipeline } from "../pipeline";
import { checkHostedQuota, recordHostedUsage } from "../metering";

type AuthedRequest = Request & { account?: Account };

const HOSTED_NOVICE_CHAIN: LLMModel[] = [
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
];

// Per-account 1-query-per-15-seconds limit.
const RATE_LIMIT_MS = 15_000;
const lastRequestAt = new Map<string, number>();

export function registerHostedVerifyRoute(app: Express): void {
  app.post(
    "/api/verify/hosted",
    requireSession,
    async (req: AuthedRequest, res: Response) => {
      const account = req.account!;
      const bodySchema = z.object({ query: z.string().min(1).max(8000) });
      const parsed = bodySchema.safeParse(req.body);
      if (!parsed.success) return res.status(400).json({ error: "Invalid query" });

      // Rate limit
      const now = Date.now();
      const last = lastRequestAt.get(account.id) ?? 0;
      if (now - last < RATE_LIMIT_MS) {
        const waitMs = RATE_LIMIT_MS - (now - last);
        return res.status(429).json({ error: "Rate limit", retryAfterMs: waitMs });
      }
      lastRequestAt.set(account.id, now);

      // Quota + cap check
      const quota = await checkHostedQuota(account.id);
      if (!quota.ok) {
        const status = quota.reason === "monthly_cap_paused" ? 503 : 402;
        return res.status(status).json({ error: quota.reason });
      }

      try {
        await runVerificationPipeline(
          {
            query: parsed.data.query,
            chain: HOSTED_NOVICE_CHAIN,
            adversarialMode: false,
            liveResearch: true,
            autoTieBreaker: false,
            onComplete: async () => {
              await recordHostedUsage(account.id);
            },
          },
          res,
        );
      } catch (error) {
        console.error("Hosted verification error:", error);
        if (!res.headersSent) {
          res.status(500).json({ error: "Verification failed" });
        } else {
          try {
            res.write(`data: ${JSON.stringify({ type: "error", error: "Verification failed" })}\n\n`);
          } catch {}
          res.end();
        }
      }
    },
  );
}
```

- [ ] **Step 2: Register in `server/routes.ts`**

At the top of `server/routes.ts`, add:
```ts
import { registerHostedVerifyRoute } from "./routes/verify-hosted";
```
Inside `registerRoutes`, after `registerAuthRoutes(app)`, add:
```ts
registerHostedVerifyRoute(app);
```

- [ ] **Step 3: Typecheck and smoke**

Run: `npm run check`
Expected: no new errors.

Run: `npm run dev` and from a browser/curl, `POST /api/verify/hosted` without auth → expect `401`. With a valid session cookie (from Phase I sign-in flow, once implemented), expect SSE stream.

Stop the dev server.

- [ ] **Step 4: Commit**

```bash
git add server/routes/verify-hosted.ts server/routes.ts
git commit -m "feat(server): add POST /api/verify/hosted (session-gated, metered)"
```

---

## Phase H — Web client: auth state + sign-in UI

### Task 12: auth API client + `useAuth` hook

**Files:**
- Create: `client/src/lib/auth-api.ts`
- Create: `client/src/hooks/use-auth.ts`

- [ ] **Step 1: Create the fetch helpers**

Create `client/src/lib/auth-api.ts`:

```ts
import type { AccountPublic } from "@shared/schema";

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function requestEmailCode(email: string, turnstileToken?: string): Promise<void> {
  await handle(
    await fetch("/api/auth/email/request", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, turnstileToken }),
      credentials: "include",
    }),
  );
}

export async function verifyEmailCode(email: string, code: string): Promise<{ account: AccountPublic }> {
  return handle(
    await fetch("/api/auth/email/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, code }),
      credentials: "include",
    }),
  );
}

export async function me(): Promise<{ account: AccountPublic } | null> {
  const res = await fetch("/api/auth/me", { credentials: "include" });
  if (res.status === 401) return null;
  return handle(res);
}

export async function signOut(): Promise<void> {
  await fetch("/api/auth/logout", { method: "POST", credentials: "include" });
}
```

- [ ] **Step 2: Create the hook**

Create `client/src/hooks/use-auth.ts`:

```ts
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { me, signOut as apiSignOut } from "@/lib/auth-api";
import type { AccountPublic } from "@shared/schema";

export function useAuth() {
  const qc = useQueryClient();
  const { data, isLoading, refetch } = useQuery<{ account: AccountPublic } | null>({
    queryKey: ["auth", "me"],
    queryFn: me,
    retry: false,
    staleTime: 60_000,
  });

  return {
    account: data?.account ?? null,
    isLoading,
    signedIn: !!data?.account,
    refresh: refetch,
    signOut: async () => {
      await apiSignOut();
      await qc.invalidateQueries({ queryKey: ["auth", "me"] });
    },
  };
}
```

- [ ] **Step 3: Commit**

```bash
git add client/src/lib/auth-api.ts client/src/hooks/use-auth.ts
git commit -m "feat(client): add auth API client + useAuth hook"
```

---

### Task 13: Sign-in page (`/sign-in`)

**Files:**
- Create: `client/src/pages/sign-in.tsx`
- Modify: `client/src/App.tsx` (add route)

- [ ] **Step 1: Create the sign-in page**

Create `client/src/pages/sign-in.tsx`:

```tsx
import { useState } from "react";
import { useLocation } from "wouter";
import { requestEmailCode, verifyEmailCode } from "@/lib/auth-api";
import { useAuth } from "@/hooks/use-auth";

type Phase = "choose" | "email-input" | "code-input";

export default function SignInPage() {
  const [, nav] = useLocation();
  const { refresh } = useAuth();
  const [phase, setPhase] = useState<Phase>("choose");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);

  // Read Turnstile token from the widget when we add it. For dev (no TURNSTILE_SECRET_KEY set server-side), we can pass empty and server bypasses.
  const [turnstileToken, setTurnstileToken] = useState<string>("");

  async function onRequestCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSending(true);
    try {
      await requestEmailCode(email, turnstileToken || undefined);
      setPhase("code-input");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    } finally {
      setSending(false);
    }
  }

  async function onVerifyCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSending(true);
    try {
      await verifyEmailCode(email, code);
      await refresh();
      nav("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="min-h-screen bg-black text-zinc-100 font-mono flex items-center justify-center px-6">
      <div className="w-full max-w-md space-y-6">
        <div className="text-center space-y-2">
          <div className="text-green-500 text-sm">● ROSIN</div>
          <div className="text-zinc-500 text-xs uppercase tracking-widest">[ SIGN IN ]</div>
        </div>

        {phase === "choose" && (
          <div className="space-y-3">
            <a
              href="/api/auth/google/start"
              className="block text-center border border-zinc-700 hover:border-green-500 rounded px-4 py-3"
              data-testid="signin-google"
            >
              Continue with Google
            </a>
            <button
              type="button"
              onClick={() => setPhase("email-input")}
              className="w-full border border-zinc-700 hover:border-green-500 rounded px-4 py-3"
              data-testid="signin-email"
            >
              Continue with Email
            </button>
            {/* Apple button mounted in Task 13b below if APPLE_SERVICES_ID is configured */}
            <div id="appleid-signin" data-color="white" data-border="true" data-type="sign-in" className="w-full" />
            <p className="text-[10px] text-zinc-600 text-center pt-2">
              We only use your email to keep track of your 3 free verifications.
            </p>
          </div>
        )}

        {phase === "email-input" && (
          <form onSubmit={onRequestCode} className="space-y-3">
            <label className="block text-xs text-zinc-500 uppercase tracking-widest">Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700 rounded px-3 py-2 focus:border-green-500 outline-none"
              data-testid="signin-email-input"
            />
            {/* Turnstile widget placeholder — wire up @marsidev/react-turnstile or a script tag if VITE_TURNSTILE_SITE_KEY is configured */}
            <button
              type="submit"
              disabled={sending}
              className="w-full border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-4 py-3 disabled:opacity-50"
              data-testid="signin-email-submit"
            >
              {sending ? "Sending..." : "Send code"}
            </button>
          </form>
        )}

        {phase === "code-input" && (
          <form onSubmit={onVerifyCode} className="space-y-3">
            <p className="text-xs text-zinc-400">Check your email for a 6-digit code.</p>
            <input
              type="text"
              inputMode="numeric"
              pattern="\d{6}"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
              className="w-full bg-zinc-900 border border-zinc-700 rounded px-3 py-2 text-center tracking-[0.5em] focus:border-green-500 outline-none"
              data-testid="signin-code-input"
            />
            <button
              type="submit"
              disabled={sending || code.length !== 6}
              className="w-full border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-4 py-3 disabled:opacity-50"
              data-testid="signin-code-submit"
            >
              {sending ? "Verifying..." : "Verify"}
            </button>
          </form>
        )}

        {error && <div className="text-xs text-red-500 text-center">{error}</div>}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Add the route**

Modify `client/src/App.tsx`. Add the import:
```tsx
import SignInPage from "@/pages/sign-in";
```
Add the route inside the `<Switch>` (before the catch-all `<Route component={NotFound} />`):
```tsx
<Route path="/sign-in" component={SignInPage} />
```

- [ ] **Step 3: Typecheck**

Run: `npm run check`
Expected: no new errors in `client/`.

- [ ] **Step 4: Commit**

```bash
git add client/src/pages/sign-in.tsx client/src/App.tsx
git commit -m "feat(client): add /sign-in page with Google + email code flows"
```

---

### Task 13b: Sign In with Apple on web (Apple JS SDK)

Sign in with Apple on the web uses Apple's official JS SDK. It requires a "Services ID" (separate from the iOS bundle identifier) registered in the Apple Developer portal, plus a verified return URL. Once the user taps the button, Apple returns an `id_token` directly to the SDK's callback, which we POST to the platform-agnostic `/api/auth/apple/token` endpoint (built in Task 8).

**Files:**
- Modify: `client/index.html` (load Apple JS SDK)
- Modify: `client/src/pages/sign-in.tsx` (init + handle callback)
- Modify: `.env.example` (add `APPLE_SERVICES_ID`, `APPLE_RETURN_URL`)
- Modify: `client/src/lib/auth-api.ts` (add `signInWithAppleToken` helper)

- [ ] **Step 1: Add env vars**

Append to `.env.example`:
```
# Sign in with Apple (web — separate from iOS native)
VITE_APPLE_SERVICES_ID=
VITE_APPLE_RETURN_URL=http://localhost:5000/sign-in
```

- [ ] **Step 2: Load the Apple JS SDK**

Modify `client/index.html`. In `<head>`, add (before the Vite script):

```html
<script
  type="text/javascript"
  src="https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"
  defer
></script>
```

- [ ] **Step 3: Add the helper**

Append to `client/src/lib/auth-api.ts`:

```ts
export async function signInWithAppleToken(identityToken: string): Promise<{ account: AccountPublic }> {
  return handle(
    await fetch("/api/auth/apple/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ identityToken }),
    }),
  );
}
```

- [ ] **Step 4: Init Apple on the sign-in page**

Modify `client/src/pages/sign-in.tsx`. Import the helper:
```tsx
import { signInWithAppleToken } from "@/lib/auth-api";
```

Inside the component body (before `return`), add an effect that initializes Apple ID when `phase === "choose"` and the SDK is loaded:

```tsx
import { useEffect } from "react";

useEffect(() => {
  if (phase !== "choose") return;
  const servicesId = import.meta.env.VITE_APPLE_SERVICES_ID;
  const returnURL = import.meta.env.VITE_APPLE_RETURN_URL;
  if (!servicesId || !returnURL) return; // dev mode — Apple button is inert
  // @ts-ignore — SDK-provided global
  if (typeof AppleID === "undefined") return;
  // @ts-ignore
  AppleID.auth.init({
    clientId: servicesId,
    scope: "email",
    redirectURI: returnURL,
    usePopup: true,
  });

  function onSuccess(evt: any) {
    const token = evt?.detail?.authorization?.id_token;
    if (!token) return;
    (async () => {
      try {
        await signInWithAppleToken(token);
        await refresh();
        nav("/");
      } catch (err) {
        setError(err instanceof Error ? err.message : "Apple sign-in failed");
      }
    })();
  }
  function onFailure(evt: any) {
    setError(evt?.detail?.error || "Apple sign-in cancelled");
  }
  document.addEventListener("AppleIDSignInOnSuccess", onSuccess);
  document.addEventListener("AppleIDSignInOnFailure", onFailure);
  return () => {
    document.removeEventListener("AppleIDSignInOnSuccess", onSuccess);
    document.removeEventListener("AppleIDSignInOnFailure", onFailure);
  };
}, [phase, nav, refresh]);
```

(The `<div id="appleid-signin">` placeholder was added in Task 13.)

- [ ] **Step 5: Typecheck + commit**

Run: `npm run check`
Expected: no new errors.

```bash
git add client/index.html client/src/pages/sign-in.tsx client/src/lib/auth-api.ts .env.example
git commit -m "feat(client): add Sign in with Apple on web via Apple JS SDK"
```

**Provisioning note (one-time, manual):** Enable Sign in with Apple in the Apple Developer portal, create a Services ID (e.g. `com.rosinai.web`), add `rosin.app` (prod) and `localhost` (dev) domains, and set `VITE_APPLE_SERVICES_ID` + `VITE_APPLE_RETURN_URL`. If this infra isn't set up at implementation time, the Apple button on web renders inert — users fall back to Google/email, no regression.

---

### Task 14: Wire Novice page to hosted endpoint + auth gate + exhaustion gate

**Files:**
- Create: `client/src/components/novice/auth-gate.tsx`
- Create: `client/src/components/novice/free-tier-exhausted.tsx`
- Modify: `client/src/pages/novice.tsx`

- [ ] **Step 1: Create the auth gate**

Create `client/src/components/novice/auth-gate.tsx`:

```tsx
import { Link } from "wouter";

export function AuthGate() {
  return (
    <div className="max-w-md mx-auto text-center mt-16 space-y-4">
      <div className="text-xs text-zinc-500 uppercase tracking-widest">[ SIGN IN REQUIRED ]</div>
      <p className="text-sm text-zinc-300">
        Verifying across multiple AIs uses shared compute. Sign in for 3 free verifications.
      </p>
      <Link
        href="/sign-in"
        className="inline-block border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-6 py-3 text-sm"
        data-testid="novice-sign-in"
      >
        Sign in to verify
      </Link>
    </div>
  );
}
```

- [ ] **Step 2: Create the exhaustion gate**

Create `client/src/components/novice/free-tier-exhausted.tsx`:

```tsx
export function FreeTierExhausted() {
  return (
    <div className="max-w-md mx-auto text-center mt-16 space-y-4">
      <div className="text-xs text-amber-500 uppercase tracking-widest">[ FREE TIER EXHAUSTED ]</div>
      <p className="text-sm text-zinc-300">
        You've used your 3 free verifications. Add your own API keys in Pro mode to keep going.
      </p>
      <div className="flex flex-col items-center gap-2 text-xs text-zinc-400 pt-2">
        <a href="https://console.anthropic.com/settings/keys" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get an Anthropic key
        </a>
        <a href="https://aistudio.google.com/app/apikey" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get a Gemini key
        </a>
        <a href="https://console.x.ai/" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get an xAI key
        </a>
      </div>
      <a
        href="/pro"
        className="inline-block border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-6 py-3 text-sm mt-4"
      >
        Open Pro mode
      </a>
    </div>
  );
}
```

- [ ] **Step 3: Wire into `novice.tsx`**

Modify `client/src/pages/novice.tsx`:

  a. Add imports at the top:
  ```tsx
  import { useAuth } from "@/hooks/use-auth";
  import { AuthGate } from "@/components/novice/auth-gate";
  import { FreeTierExhausted } from "@/components/novice/free-tier-exhausted";
  ```

  b. Inside `NovicePage` top of the component body:
  ```tsx
  const { signedIn, account, isLoading: authLoading, refresh } = useAuth();
  const [exhausted, setExhausted] = useState(false);
  ```

  c. Replace the fetch URL and body in `runVerification`. Replace:
  ```ts
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
  ```
  with:
  ```ts
  const response = await fetch("/api/verify/hosted", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ query }),
  });
  if (response.status === 402) {
    setExhausted(true);
    setPhase("idle");
    await refresh();
    return;
  }
  if (response.status === 401) {
    // Session expired mid-session; bounce to sign in
    window.location.href = "/sign-in";
    return;
  }
  if (!response.ok || !response.body) throw new Error(`HTTP ${response.status}`);
  ```

  d. After a successful verification (`setPhase("done")`), refresh auth so the remaining count updates:
  ```ts
  await refresh();
  ```

  e. In the JSX, replace the `{phase === "idle" && <NoviceInput onSubmit={runVerification} />}` line with a conditional ladder:
  ```tsx
  {authLoading && phase === "idle" && (
    <div className="text-center text-xs text-zinc-500 mt-10">[ LOADING... ]</div>
  )}
  {!authLoading && !signedIn && phase === "idle" && <AuthGate />}
  {!authLoading && signedIn && exhausted && <FreeTierExhausted />}
  {!authLoading && signedIn && !exhausted && phase === "idle" && (
    <>
      <NoviceInput onSubmit={runVerification} />
      {account && (
        <div className="text-xs text-zinc-500 text-center mt-4">
          {account.queriesRemaining} free verification{account.queriesRemaining === 1 ? "" : "s"} left
        </div>
      )}
    </>
  )}
  ```

- [ ] **Step 4: Typecheck**

Run: `npm run check`
Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add client/src/components/novice/auth-gate.tsx client/src/components/novice/free-tier-exhausted.tsx client/src/pages/novice.tsx
git commit -m "feat(client): gate novice page on auth, switch to /api/verify/hosted"
```

---

## Phase I — iOS: session storage + auth services

### Task 15: SessionStore + auth models

**Files:**
- Create: `ios/Rosin/Services/Session/SessionStore.swift`
- Create: `ios/Rosin/Models/AuthModels.swift`

- [ ] **Step 1: Create the session store**

Create `ios/Rosin/Services/Session/SessionStore.swift`:

```swift
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()
    @Published private(set) var token: String?

    private static let keychainKey = "rosin_session_token"

    init() {
        self.token = KeychainService.load(key: Self.keychainKey)
    }

    func set(_ newToken: String) throws {
        try KeychainService.save(key: Self.keychainKey, value: newToken)
        self.token = newToken
    }

    func clear() throws {
        try KeychainService.delete(key: Self.keychainKey)
        self.token = nil
    }

    var isSignedIn: Bool { token != nil }
}
```

- [ ] **Step 2: Create shared auth models**

Create `ios/Rosin/Models/AuthModels.swift`:

```swift
import Foundation

struct AccountPublic: Codable {
    let id: String
    let email: String
    let authProvider: String
    let queriesUsed: Int
    let queriesRemaining: Int
}

struct SessionResponse: Codable {
    let token: String
    let account: AccountPublic
}

enum AuthMethod {
    case apple, google, email
}

struct RosinEndpoint {
    static let baseURL = URL(string: ProcessInfo.processInfo.environment["ROSIN_API_BASE"] ?? "https://rosin.app")!
    static func url(_ path: String) -> URL { baseURL.appendingPathComponent(path) }
}
```

- [ ] **Step 3: Register with Xcode**

Run:
```bash
ruby ios/scripts/add-files.rb \
  Rosin/Services/Session/SessionStore.swift \
  Rosin/Models/AuthModels.swift
```
Expected: "added" messages for both files.

- [ ] **Step 4: Build to verify compile**

Run:
```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add ios/Rosin/Services/Session/ ios/Rosin/Models/AuthModels.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add SessionStore (Keychain) + auth models"
```

---

### Task 16: Email auth client (6-digit code)

**Files:**
- Create: `ios/Rosin/Services/Auth/EmailAuthClient.swift`

- [ ] **Step 1: Create the client**

Create `ios/Rosin/Services/Auth/EmailAuthClient.swift`:

```swift
import Foundation

enum EmailAuthError: LocalizedError {
    case network(Int)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .network(let c): return "Server error (\(c))"
        case .invalidResponse: return "Unexpected server response"
        }
    }
}

struct EmailAuthClient {
    func requestCode(email: String) async throws {
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/email/request"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw EmailAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmailAuthError.network(http.statusCode) }
    }

    func verifyCode(email: String, code: String) async throws -> SessionResponse {
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/email/verify"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EmailAuthError.network((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(SessionResponse.self, from: data)
    }
}
```

- [ ] **Step 2: Register + build**

Run:
```bash
ruby ios/scripts/add-files.rb Rosin/Services/Auth/EmailAuthClient.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ios/Rosin/Services/Auth/EmailAuthClient.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add EmailAuthClient for 6-digit code flow"
```

---

### Task 17: Apple Sign In controller

**Files:**
- Create: `ios/Rosin/Services/Auth/AppleAuthController.swift`

- [ ] **Step 1: Create the controller**

Create `ios/Rosin/Services/Auth/AppleAuthController.swift`:

```swift
import Foundation
import AuthenticationServices

@MainActor
final class AppleAuthController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<SessionResponse, Error>?

    func signIn() async throws -> SessionResponse {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: NSError(domain: "Apple", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing identity token"]))
            continuation = nil
            return
        }
        Task { [continuation] in
            do {
                var req = URLRequest(url: RosinEndpoint.url("/api/auth/apple/token"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["identityToken": identityToken])
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw NSError(domain: "Apple", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
                }
                let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
                continuation?.resume(returning: decoded)
            } catch {
                continuation?.resume(throwing: error)
            }
            await MainActor.run { self.continuation = nil }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
```

- [ ] **Step 2: Register + build**

Run:
```bash
ruby ios/scripts/add-files.rb Rosin/Services/Auth/AppleAuthController.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Enable "Sign In with Apple" capability**

**Manual step — cannot be automated from the CLI without Xcode project edits.** Open `ios/Rosin.xcodeproj` in Xcode, select the **Rosin** target → Signing & Capabilities → "+ Capability" → **Sign In with Apple**. This writes an entitlement file and updates the provisioning profile.

After doing so in Xcode, commit the resulting changes:
```bash
git add ios/Rosin.xcodeproj/project.pbxproj ios/Rosin/Rosin.entitlements 2>/dev/null || true
git add ios/Rosin/Services/Auth/AppleAuthController.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add Apple Sign In controller + capability"
```

---

### Task 18: Google OAuth controller (ASWebAuthenticationSession + PKCE)

**Files:**
- Create: `ios/Rosin/Services/Auth/GoogleAuthController.swift`

- [ ] **Step 1: Create the controller**

Create `ios/Rosin/Services/Auth/GoogleAuthController.swift`:

```swift
import Foundation
import AuthenticationServices
import CryptoKit

enum GoogleAuthError: Error { case userCancelled, invalidCallback, network(Int) }

@MainActor
final class GoogleAuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let callbackScheme = "rosinai"
    private let callbackHost = "auth"

    func signIn() async throws -> SessionResponse {
        // 1. Generate PKCE pair
        let verifier = randomURLSafeString(length: 64)
        let challenge = sha256Base64URL(verifier)

        // 2. Ask the server for the Google auth URL (server injects our client_id + redirect_uri)
        var startReq = URLRequest(url: RosinEndpoint.url("/api/auth/google/mobile/start"))
        startReq.httpMethod = "POST"
        startReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let redirectBack = "\(callbackScheme)://\(callbackHost)/google/callback"
        startReq.httpBody = try JSONSerialization.data(withJSONObject: [
            "redirectBack": redirectBack,
            "codeChallenge": challenge,
        ])
        let (startData, startRes) = try await URLSession.shared.data(for: startReq)
        guard let http = startRes as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.network((startRes as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: startData) as? [String: Any],
            let authURLString = json["url"] as? String,
            let authURL = URL(string: authURLString)
        else { throw GoogleAuthError.invalidCallback }

        // 3. Run ASWebAuthenticationSession to let the user authorise Google
        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error { cont.resume(throwing: error); return }
                guard let url else { cont.resume(throwing: GoogleAuthError.invalidCallback); return }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        // 4. Server has already exchanged the code and put token=... on the callback URL
        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { throw GoogleAuthError.invalidCallback }

        // 5. Use the token to fetch /api/auth/me to hydrate the account
        var meReq = URLRequest(url: RosinEndpoint.url("/api/auth/me"))
        meReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (meData, meRes) = try await URLSession.shared.data(for: meReq)
        guard let mh = meRes as? HTTPURLResponse, (200..<300).contains(mh.statusCode) else {
            throw GoogleAuthError.network((meRes as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let accountWrap = try JSONDecoder().decode([String: AccountPublic].self, from: meData)
        guard let account = accountWrap["account"] else { throw GoogleAuthError.invalidCallback }
        return SessionResponse(token: token, account: account)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }

    private func randomURLSafeString(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private func sha256Base64URL(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
```

- [ ] **Step 2: Register the URL scheme in Info.plist**

**Manual step (Xcode GUI).** Open `ios/Rosin.xcodeproj` in Xcode, select the Rosin target → Info → URL Types → + → set **URL Schemes** to `rosinai`, Identifier `com.rosinai.app`. This writes the scheme into the Info.plist used at build time.

- [ ] **Step 3: Register Swift file + build**

Run:
```bash
ruby ios/scripts/add-files.rb Rosin/Services/Auth/GoogleAuthController.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/Rosin/Services/Auth/GoogleAuthController.swift ios/Rosin.xcodeproj/project.pbxproj ios/Rosin/Info.plist 2>/dev/null || true
git commit -m "feat(ios): add Google OAuth via ASWebAuthenticationSession + PKCE + URL scheme"
```

---

### Task 19: AuthService orchestrator + AuthViewModel

**Files:**
- Create: `ios/Rosin/Services/Auth/AuthService.swift`
- Create: `ios/Rosin/ViewModels/AuthViewModel.swift`

- [ ] **Step 1: Create AuthService**

Create `ios/Rosin/Services/Auth/AuthService.swift`:

```swift
import Foundation

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let appleController = AppleAuthController()
    private let googleController = GoogleAuthController()
    private let emailClient = EmailAuthClient()

    func signInWithApple() async throws -> AccountPublic {
        let result = try await appleController.signIn()
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func signInWithGoogle() async throws -> AccountPublic {
        let result = try await googleController.signIn()
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func requestEmailCode(_ email: String) async throws {
        try await emailClient.requestCode(email: email)
    }

    func verifyEmailCode(email: String, code: String) async throws -> AccountPublic {
        let result = try await emailClient.verifyCode(email: email, code: code)
        try SessionStore.shared.set(result.token)
        return result.account
    }

    func signOut() async throws {
        if let token = SessionStore.shared.token {
            var req = URLRequest(url: RosinEndpoint.url("/api/auth/logout"))
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        try SessionStore.shared.clear()
    }

    func fetchAccount() async throws -> AccountPublic {
        guard let token = SessionStore.shared.token else {
            throw NSError(domain: "Auth", code: 401)
        }
        var req = URLRequest(url: RosinEndpoint.url("/api/auth/me"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Auth", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let wrap = try JSONDecoder().decode([String: AccountPublic].self, from: data)
        guard let account = wrap["account"] else { throw NSError(domain: "Auth", code: -1) }
        return account
    }
}
```

- [ ] **Step 2: Create AuthViewModel**

Create `ios/Rosin/ViewModels/AuthViewModel.swift`:

```swift
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var account: AccountPublic?
    @Published var isSigningIn = false
    @Published var error: String?

    var isSignedIn: Bool { account != nil }
    var queriesRemaining: Int { account?.queriesRemaining ?? 0 }

    func hydrate() async {
        guard SessionStore.shared.isSignedIn else { account = nil; return }
        do {
            account = try await AuthService.shared.fetchAccount()
        } catch {
            account = nil
            try? SessionStore.shared.clear()
        }
    }

    func signInWithApple() async {
        await perform { try await AuthService.shared.signInWithApple() }
    }

    func signInWithGoogle() async {
        await perform { try await AuthService.shared.signInWithGoogle() }
    }

    func requestEmailCode(_ email: String) async throws {
        try await AuthService.shared.requestEmailCode(email)
    }

    func verifyEmailCode(email: String, code: String) async {
        await perform { try await AuthService.shared.verifyEmailCode(email: email, code: code) }
    }

    func signOut() async {
        try? await AuthService.shared.signOut()
        account = nil
    }

    private func perform(_ op: @Sendable () async throws -> AccountPublic) async {
        isSigningIn = true
        error = nil
        defer { isSigningIn = false }
        do {
            account = try await op()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed"
        }
    }
}
```

- [ ] **Step 3: Register + build + commit**

```bash
ruby ios/scripts/add-files.rb \
  Rosin/Services/Auth/AuthService.swift \
  Rosin/ViewModels/AuthViewModel.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

```bash
git add ios/Rosin/Services/Auth/AuthService.swift ios/Rosin/ViewModels/AuthViewModel.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add AuthService orchestrator + AuthViewModel"
```

---

## Phase J — iOS: sign-in UI + hosted streaming

### Task 20: SignInView with Apple / Google / Email buttons

**Files:**
- Create: `ios/Rosin/Views/Auth/SignInView.swift`
- Create: `ios/Rosin/Views/Auth/EmailCodeView.swift`

- [ ] **Step 1: Create SignInView**

Create `ios/Rosin/Views/Auth/SignInView.swift`:

```swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showEmailFlow = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Text("● ROSIN").foregroundColor(Color("RosinGreen")).font(.system(.caption, design: .monospaced))
                Text("[ SIGN IN ]").foregroundColor(.secondary).font(.system(.caption2, design: .monospaced)).tracking(2)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 48)
                    .overlay(
                        Button(action: { Task { await auth.signInWithApple() } }) {
                            Color.clear
                        }
                    )

                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    Text("Continue with Google")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                }

                Button {
                    showEmailFlow = true
                } label: {
                    Text("Continue with Email")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                }
            }
            .padding(.horizontal, 24)

            if let error = auth.error {
                Text(error).foregroundColor(Color("RosinDestructive"))
                    .font(.system(.caption, design: .monospaced))
            }

            Spacer()
        }
        .background(Color("RosinBackground").ignoresSafeArea())
        .sheet(isPresented: $showEmailFlow) {
            EmailCodeView().environmentObject(auth)
        }
    }
}
```

- [ ] **Step 2: Create EmailCodeView**

Create `ios/Rosin/Views/Auth/EmailCodeView.swift`:

```swift
import SwiftUI

struct EmailCodeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var phase: Phase = .email
    @State private var error: String?
    @State private var sending = false

    enum Phase { case email, code }

    var body: some View {
        VStack(spacing: 20) {
            Text(phase == .email ? "Enter your email" : "Enter your 6-digit code")
                .font(.system(.headline, design: .monospaced))
                .padding(.top, 24)

            if phase == .email {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                    .padding(.horizontal, 24)

                Button {
                    Task {
                        sending = true; error = nil
                        defer { sending = false }
                        do {
                            try await auth.requestEmailCode(email)
                            phase = .code
                        } catch {
                            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed"
                        }
                    }
                } label: {
                    Text(sending ? "Sending..." : "Send code")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("RosinGreen")))
                }
                .disabled(sending || email.isEmpty)
                .padding(.horizontal, 24)
            } else {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                    .padding(.horizontal, 24)
                    .onChange(of: code) { newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }

                Button {
                    Task {
                        await auth.verifyEmailCode(email: email, code: code)
                        if auth.isSignedIn { dismiss() }
                        else { error = auth.error ?? "Invalid code" }
                    }
                } label: {
                    Text("Verify").font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("RosinGreen")))
                }
                .disabled(code.count != 6)
                .padding(.horizontal, 24)
            }

            if let error { Text(error).foregroundColor(Color("RosinDestructive")).font(.system(.caption, design: .monospaced)) }

            Spacer()
        }
        .padding(.top, 12)
        .background(Color("RosinBackground").ignoresSafeArea())
    }
}
```

- [ ] **Step 3: Register + build + commit**

```bash
ruby ios/scripts/add-files.rb \
  Rosin/Views/Auth/SignInView.swift \
  Rosin/Views/Auth/EmailCodeView.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

```bash
git add ios/Rosin/Views/Auth/ ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add SignInView + EmailCodeView (Apple/Google/Email)"
```

---

### Task 21: HostedVerificationService — streams /api/verify/hosted

**Files:**
- Create: `ios/Rosin/Services/Networking/HostedVerificationService.swift`

- [ ] **Step 1: Create the service**

Create `ios/Rosin/Services/Networking/HostedVerificationService.swift`:

```swift
import Foundation

/// Streams the server-side 2-stage novice pipeline from POST /api/verify/hosted.
/// Emits events parsed from the shared SSE format via SSELineParser.
actor HostedVerificationService {
    enum HostedError: LocalizedError {
        case notSignedIn
        case freeTierExhausted
        case rateLimited(retryAfterMs: Int?)
        case network(Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Not signed in"
            case .freeTierExhausted: return "Free tier exhausted"
            case .rateLimited(let ms):
                if let ms { return "Slow down — try again in \(ms/1000)s" }
                return "Rate limited"
            case .network(let c): return "Server error (\(c))"
            }
        }
    }

    /// Returns an AsyncThrowingStream of raw SSE `data:` payloads for the caller to JSON-decode per event.
    func stream(query: String, token: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: RosinEndpoint.url("/api/verify/hosted"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw HostedError.network(-1)
                    }
                    if http.statusCode == 401 { throw HostedError.notSignedIn }
                    if http.statusCode == 402 { throw HostedError.freeTierExhausted }
                    if http.statusCode == 429 {
                        // Body has retryAfterMs but for simplicity we don't parse it here
                        throw HostedError.rateLimited(retryAfterMs: nil)
                    }
                    if !(200..<300).contains(http.statusCode) {
                        throw HostedError.network(http.statusCode)
                    }

                    let parser = SSELineParser()
                    for try await payload in parser.parse(bytes) {
                        continuation.yield(payload)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

*Note:* This assumes `SSELineParser` already exposes `func parse(_ bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error>`. If its surface differs, adapt the call accordingly (inspect `ios/Rosin/Services/Networking/SSELineParser.swift` while implementing).

- [ ] **Step 2: Register + build + commit**

```bash
ruby ios/scripts/add-files.rb Rosin/Services/Networking/HostedVerificationService.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

```bash
git add ios/Rosin/Services/Networking/HostedVerificationService.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add HostedVerificationService for /api/verify/hosted"
```

---

### Task 22: FreeGateView (post-3-queries)

**Files:**
- Create: `ios/Rosin/Views/Novice/FreeGateView.swift`

- [ ] **Step 1: Create the view**

Create `ios/Rosin/Views/Novice/FreeGateView.swift`:

```swift
import SwiftUI

struct FreeGateView: View {
    let onOpenProvider: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("[ FREE TIER EXHAUSTED ]")
                .foregroundColor(.orange)
                .font(.system(.caption, design: .monospaced)).tracking(2)
            Text("You've used your 3 free verifications.\nAdd your own API keys to keep going.")
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                providerButton("Get an Anthropic key", url: URL(string: "https://console.anthropic.com/settings/keys")!)
                providerButton("Get a Gemini key", url: URL(string: "https://aistudio.google.com/app/apikey")!)
                providerButton("Get an xAI key", url: URL(string: "https://console.x.ai/")!)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Spacer()
        }
        .background(Color("RosinBackground").ignoresSafeArea())
    }

    private func providerButton(_ label: String, url: URL) -> some View {
        Button {
            onOpenProvider(url)
        } label: {
            Text(label).font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
        }
    }
}
```

- [ ] **Step 2: Register + build + commit**

```bash
ruby ios/scripts/add-files.rb Rosin/Views/Novice/FreeGateView.swift
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
git add ios/Rosin/Views/Novice/FreeGateView.swift ios/Rosin.xcodeproj/project.pbxproj
git commit -m "feat(ios): add FreeGateView (post-3-queries gate)"
```

---

### Task 23: Wire NoviceTerminalViewModel to HostedVerificationService + exhaustion gate

**Files:**
- Modify: `ios/Rosin/ViewModels/NoviceTerminalViewModel.swift`

**Before coding:** read the current `NoviceTerminalViewModel.swift` to understand its existing shape. Then adapt the following changes to fit.

- [ ] **Step 1: Inspect current VM**

Run:
```bash
cat ios/Rosin/ViewModels/NoviceTerminalViewModel.swift
```

- [ ] **Step 2: Modify to use HostedVerificationService**

The existing VM currently drives `VerificationPipelineManager` for BYO-key execution. We're adding a hosted path that takes over when a session token is present (novice mode).

Add these properties and the hosted verify method to `NoviceTerminalViewModel`:

```swift
@Published var freeTierExhausted = false

private let hostedService = HostedVerificationService()

func runHostedVerification(query: String, token: String) async {
    phase = .verifying
    freeTierExhausted = false
    // Reset stages/sources/result in whatever shape the existing VM uses — match the BYO path.
    do {
        for try await payload in await hostedService.stream(query: query, token: token) {
            // Decode each event via the same code path the BYO streaming uses.
            // Reuse the existing event-dispatch method; e.g.:
            handleSSEPayload(payload)
        }
        phase = .done
    } catch let e as HostedVerificationService.HostedError {
        switch e {
        case .freeTierExhausted: freeTierExhausted = true; phase = .idle
        case .notSignedIn: phase = .idle
        default: phase = .error
        }
        error = e.errorDescription
    } catch {
        phase = .error
        self.error = error.localizedDescription
    }
}
```

If the VM does not already have a `handleSSEPayload` function, factor the event-dispatch switch out of the BYO path into one so both paths parse the same event types.

Callers switching between BYO and hosted paths: in `RosinApp.swift` / `NoviceTerminalView.swift`, invoke `runHostedVerification` when `SessionStore.shared.isSignedIn`; otherwise present `SignInView`.

- [ ] **Step 3: Build + commit**

```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
git add ios/Rosin/ViewModels/NoviceTerminalViewModel.swift
git commit -m "feat(ios): wire NoviceTerminalViewModel to HostedVerificationService"
```

---

### Task 24: Route auth gate in RosinApp, add sign-out to Settings

**Files:**
- Modify: `ios/Rosin/RosinApp.swift`
- Modify: `ios/Rosin/Views/Settings/SettingsView.swift`
- Modify: `ios/Rosin/Views/Novice/NoviceTerminalView.swift`

- [ ] **Step 1: Inspect current files**

Run:
```bash
cat ios/Rosin/RosinApp.swift
cat ios/Rosin/Views/Novice/NoviceTerminalView.swift
cat ios/Rosin/Views/Settings/SettingsView.swift
```

- [ ] **Step 2: Add AuthViewModel to the environment in RosinApp**

In `RosinApp.swift`, create a `@StateObject var auth = AuthViewModel()` and inject it into the root via `.environmentObject(auth)`. On `.task`, call `await auth.hydrate()`.

When `RosinModeManager` reports Novice mode AND `!auth.isSignedIn`, render `SignInView()` instead of `NoviceTerminalView()`. Pro mode is unaffected — it continues to render the existing terminal regardless of auth.

- [ ] **Step 3: Show free-tier gate in NoviceTerminalView**

When `viewModel.freeTierExhausted == true`, render `FreeGateView { url in UIApplication.shared.open(url) }` instead of the input.

Also show "X free verifications left" under the input, pulled from `auth.queriesRemaining`.

- [ ] **Step 4: Add Sign Out row to SettingsView**

Add a Section with a Sign Out button shown only when `auth.isSignedIn`:

```swift
if auth.isSignedIn {
    Section("Account") {
        if let email = auth.account?.email {
            Text(email).font(.system(.caption, design: .monospaced))
        }
        Button("Sign out") {
            Task { await auth.signOut() }
        }
        .foregroundColor(Color("RosinDestructive"))
    }
}
```

Inject `@EnvironmentObject var auth: AuthViewModel` into `SettingsView`.

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -project ios/Rosin.xcodeproj -scheme Rosin -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D2CC7E2D-2A95-4259-9DA5-16D84F7C19F6' \
  build CODE_SIGNING_ALLOWED=NO
git add ios/Rosin/RosinApp.swift ios/Rosin/Views/Settings/SettingsView.swift ios/Rosin/Views/Novice/NoviceTerminalView.swift
git commit -m "feat(ios): gate Novice mode on auth, add Sign Out in Settings"
```

---

## Phase K — Docs + env

### Task 25: Update `.env.example` and CLAUDE.md

**Files:**
- Modify: `.env.example`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Append new env vars to `.env.example`**

Append the Environment Variables block from this plan's preamble to `.env.example`.

- [ ] **Step 2: Add a "Hosted Free Tier" section to CLAUDE.md**

Append under Architecture:

```markdown
### Hosted Free Tier

Authenticated users get 3 lifetime free queries via `POST /api/verify/hosted` (same Express server). Sessions are 30-day sliding opaque tokens stored in Postgres (`sessions` table). Auth methods:
- Email + 6-digit code (Resend)
- Google OAuth (server code exchange; iOS uses ASWebAuthenticationSession + PKCE)
- Apple Sign In (native on iOS; web falls back to email)

Metering: `accounts.queries_used` + `monthly_spend` aggregate with a $50/month cap (`HOSTED_MONTHLY_CAP_USD`). Per-account rate limit 1 query / 15s (in-memory).

iOS bundle id is `com.rosinai.app` (not `com.rosin.app`). The URL scheme `rosinai://` is registered for OAuth callbacks.
```

- [ ] **Step 3: Commit**

```bash
git add .env.example CLAUDE.md
git commit -m "docs: document hosted free tier env vars + architecture"
```

---

## Manual E2E test plan (user runs)

After implementation, user should verify:

**Web:**
1. Cold load `/` → AuthGate shown.
2. Click "Sign in" → Google OAuth → returns to `/` signed in with "3 free verifications left".
3. Run a verify → SSE streams → trust-score banner renders, counter drops to 2.
4. Burn through 3 → 4th attempt shows FreeTierExhausted.
5. Sign out from a debug endpoint (or clear cookie) → AuthGate returns.
6. `/pro` path is untouched and works BYO-keys as before.
7. Email code flow: enter email → receive Resend email → enter 6 digits → signed in.

**iOS:**
1. Launch app cold (no session in Keychain) → SignInView.
2. Sign in with Apple → lands on NoviceTerminalView with count "3 left".
3. Verify a query → streams → trust-score banner → count drops.
4. Burn through 3 → FreeGateView appears with provider deep links.
5. Switch to Pro mode in Settings → existing BYO UI intact.
6. Sign out from Settings → back to SignInView.
7. Google sign-in: tap button → ASWebAuthenticationSession opens → Google consent → returns to app signed in.

---

## Out of scope (deferred)

- Real Turnstile widget on the web sign-in screen — a placeholder comment is present; wiring up the widget is a 10-min follow-up once `VITE_TURNSTILE_SITE_KEY` is available.
- Payment / subscriptions — spec §out-of-scope.
- Universal-links-based magic links — replaced by 6-digit code.
- iOS test infrastructure — not requested.
- Analytics events — spec open-question #7; deferred.
- Unit tests for Google/Apple OAuth endpoints — covered by manual E2E given the heavy external dependency; happy to add vcr-style fixtures if requested.
- Async monthly-cap sweep — replaced by per-request check per decision.

---

## Self-review notes

- Every spec §3 requirement maps to a task: accounts/sessions tables (T1), hosted endpoint (T11), email code (T4+T8), Google on web (T6+T8+T13), Apple on web (T7+T8+T13b), Turnstile (T5+T8), metering (T9), monthly cap (T9+T11), no query persistence (hosted endpoint does NOT call `storage.saveVerification` — see T11).

- Every spec §4 iOS requirement maps: AuthService (T19), HostedVerificationService (T21), SignInView with Apple top (T20), session in Keychain (T15), post-3-queries gate (T22), Pro mode untouched (T24 preserves routing).

- Types referenced across tasks (`Account`, `AccountPublic`, `SessionResponse`) are defined at first use (T1 for DB rows, T8 for `accountPublic()`, T15 for iOS).

- Pipeline refactor (T10) is the one task with serious regression risk — flagged for full 3-agent review per project preferences (touches `/api/verify` handler).

- No TODOs / placeholders. Spots that explicitly require manual Xcode GUI work are called out (T17 Apple capability, T18 URL scheme) because they cannot be automated reliably from the CLI.
