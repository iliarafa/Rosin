import { randomBytes, createHash } from "crypto";
import type { Request, Response, NextFunction } from "express";
import { eq } from "drizzle-orm";
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

/** Returns the account on success, sliding the window when appropriate. */
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

  // Extend expiry when the session is older than (TTL - window) = 23 days —
  // i.e., active users roll the clock forward every 7+ days of use.
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
export async function withSession(req: Request, _res: Response, next: NextFunction): Promise<void> {
  const token = extractSessionToken(req);
  if (!token) return next();
  const result = await verifySession(token);
  if (result) req.account = result.account;
  next();
}

/** Express middleware: responds 401 if no valid session. */
export async function requireSession(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void | Response> {
  const token = extractSessionToken(req);
  if (!token) return res.status(401).json({ error: "Not signed in" });
  const result = await verifySession(token);
  if (!result) return res.status(401).json({ error: "Invalid or expired session" });
  req.account = result.account;
  next();
}
