import { sql } from "drizzle-orm";
import { pgTable, text, varchar } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const users = pgTable("users", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
});

export const insertUserSchema = createInsertSchema(users).pick({
  username: true,
  password: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;

export const llmProviders = ["anthropic", "gemini", "xai"] as const;
export type LLMProvider = (typeof llmProviders)[number];

export const llmModels = {
  anthropic: ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-opus-4-5"],
  gemini: ["gemini-2.5-flash", "gemini-2.5-pro"],
  xai: ["grok-3", "grok-3-fast"],
} as const;

export const llmModelSchema = z.object({
  provider: z.enum(llmProviders),
  model: z.string(),
});

export type LLMModel = z.infer<typeof llmModelSchema>;

export const insertVerificationRequestSchema = z.object({
  query: z.string().min(1),
  chain: z.array(llmModelSchema).min(2).max(4),
});

export type InsertVerificationRequest = z.infer<typeof insertVerificationRequestSchema>;

// ── Structured scoring schemas (Judge pipeline) ──────────────────────

/** A single factual claim extracted from a stage's output */
export const claimSchema = z.object({
  text: z.string(),
  confidence: z.number().min(0).max(100),
  sources: z.array(z.string()).optional(),
});
export type Claim = z.infer<typeof claimSchema>;

/** A potential hallucination flagged by the Judge */
export const hallucinationFlagSchema = z.object({
  claim: z.string(),
  reason: z.string(),
  severity: z.enum(["low", "medium", "high"]),
});
export type HallucinationFlag = z.infer<typeof hallucinationFlagSchema>;

/** Per-stage structured analysis produced by the Judge */
export const stageAnalysisSchema = z.object({
  stage: z.number(),
  agreementScore: z.number().min(0).max(100),
  claims: z.array(claimSchema),
  hallucinationFlags: z.array(hallucinationFlagSchema),
  corrections: z.array(z.string()),
});
export type StageAnalysis = z.infer<typeof stageAnalysisSchema>;

/** The Judge's comprehensive verdict across all stages */
export const judgeVerdictSchema = z.object({
  verdict: z.string(),
  overallScore: z.number().min(0).max(100),
  confidence: z.enum(["high", "moderate", "low"]),
  keyFindings: z.array(z.string()),
  stageAnalyses: z.array(stageAnalysisSchema),
});
export type JudgeVerdict = z.infer<typeof judgeVerdictSchema>;

// ── Stage output (now includes optional Judge analysis) ──────────────

export const stageOutputSchema = z.object({
  stage: z.number(),
  model: llmModelSchema,
  content: z.string(),
  status: z.enum(["pending", "streaming", "complete", "error"]),
  error: z.string().optional(),
  /** Per-stage analysis populated after the Judge runs */
  analysis: stageAnalysisSchema.optional(),
});

export type StageOutput = z.infer<typeof stageOutputSchema>;

export const contradictionSchema = z.object({
  topic: z.string(),
  stageA: z.number(),
  stageB: z.number(),
  description: z.string(),
});

export type Contradiction = z.infer<typeof contradictionSchema>;

// ── Verification summary (enhanced with Judge verdict) ───────────────

export const verificationSummarySchema = z.object({
  consistency: z.string(),
  hallucinations: z.string(),
  confidence: z.string(),
  contradictions: z.array(contradictionSchema).optional(),
  confidenceScore: z.number().min(0).max(1).optional(),
  isAnalyzed: z.boolean().optional(),
  analysisBullets: z.array(z.string()).optional(),
  /** Structured Judge verdict — present when the Judge stage completes */
  judgeVerdict: judgeVerdictSchema.optional(),
});

export type VerificationSummary = z.infer<typeof verificationSummarySchema>;

export const verificationRunSchema = z.object({
  id: z.string(),
  query: z.string(),
  chain: z.array(llmModelSchema),
  stages: z.array(stageOutputSchema),
  summary: verificationSummarySchema.nullable(),
  adversarialMode: z.boolean().default(false),
  createdAt: z.string(),
});

export type VerificationRun = z.infer<typeof verificationRunSchema>;

// Live Research status for the UI
export type ResearchStatus =
  | { status: "searching" }
  | { status: "complete"; sourceCount: number; sources: string }
  | { status: "error"; error: string };
