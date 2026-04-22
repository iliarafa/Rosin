import type { Express, Request, Response } from "express";
import { z } from "zod";
import type { Account, LLMModel } from "@shared/schema";
import { requireSession } from "../auth/session";
import { runVerificationPipeline } from "../pipeline";
import { checkHostedQuota, recordHostedUsage } from "../metering";

type AuthedRequest = Request & { account: Account };

const HOSTED_NOVICE_CHAIN: LLMModel[] = [
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
];

// Per-account 1-query-per-15-seconds limit. In-memory; resets on server restart.
const RATE_LIMIT_MS = 15_000;
const lastRequestAt = new Map<string, number>();

export function registerHostedVerifyRoute(app: Express): void {
  app.post(
    "/api/verify/hosted",
    requireSession,
    async (req: Request, res: Response) => {
      const account = (req as AuthedRequest).account;
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

      // Quota + monthly cap check
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
