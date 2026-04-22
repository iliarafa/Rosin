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
