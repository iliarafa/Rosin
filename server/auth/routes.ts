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
  app.get("/api/auth/me", requireSession, async (req: Request, res: Response) => {
    res.json({ account: accountPublic(req.account!) });
  });
}
