import type { Express, Response } from "express";
import { registerAuthRoutes } from "./auth/routes";
import { createServer, type Server } from "http";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";
import { tavily } from "@tavily/core";
import { insertVerificationRequestSchema, type LLMModel, type VerificationSummary, type JudgeVerdict, type StageAnalysis, judgeVerdictSchema } from "@shared/schema";
import { computeTrustScore } from "./trust-score";
import { z } from "zod";
import { storage } from "./storage";
import { randomUUID } from "crypto";
import { runVerificationPipeline } from "./pipeline";

const anthropic = new Anthropic({
  apiKey: process.env.AI_INTEGRATIONS_ANTHROPIC_API_KEY!,
  baseURL: process.env.AI_INTEGRATIONS_ANTHROPIC_BASE_URL,
});

const gemini = new GoogleGenAI({
  apiKey: process.env.AI_INTEGRATIONS_GEMINI_API_KEY!,
  httpOptions: {
    apiVersion: "",
    baseUrl: process.env.AI_INTEGRATIONS_GEMINI_BASE_URL,
  },
});

// xAI/Grok client using OpenAI-compatible API (initialized lazily)
let xai: OpenAI | null = null;
function getXAIClient(): OpenAI {
  if (!xai) {
    if (!process.env.XAI_API_KEY) {
      throw new Error("XAI_API_KEY environment variable is not set. Please add your xAI API key to use Grok models.");
    }
    xai = new OpenAI({
      apiKey: process.env.XAI_API_KEY,
      baseURL: "https://api.x.ai/v1",
    });
  }
  return xai;
}

// Tavily search client for live web research (initialized lazily)
let tavilyClient: ReturnType<typeof tavily> | null = null;
function getTavilyClient(): ReturnType<typeof tavily> | null {
  if (!process.env.TAVILY_API_KEY) return null;
  if (!tavilyClient) {
    tavilyClient = tavily({ apiKey: process.env.TAVILY_API_KEY });
  }
  return tavilyClient;
}

/** Exa.ai neural search — preferred over Tavily when EXA_API_KEY is set */
export async function exaSearch(query: string, maxResults = 8): Promise<{ title: string; url: string; content: string }[]> {
  const apiKey = process.env.EXA_API_KEY;
  if (!apiKey) return [];

  const response = await fetch("https://api.exa.ai/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
    },
    body: JSON.stringify({
      query,
      type: "auto",
      numResults: maxResults,
      contents: {
        text: { maxCharacters: 1000 },
      },
    }),
  });

  if (!response.ok) {
    console.error(`[Exa] Search failed with status ${response.status}`);
    throw new Error(`Exa search failed: ${response.status}`);
  }

  const data = await response.json() as { results?: { title?: string; url?: string; text?: string }[] };
  return (data.results || [])
    .filter((r) => r.title && r.url)
    .map((r) => ({
      title: r.title || "",
      url: r.url || "",
      content: r.text || "",
    }));
}

/**
 * Score a Tavily search result for source credibility (0–100).
 * High scores = official/reputable sources. Low scores = spam/speculation.
 */
function scoreSearchResult(result: { title: string; url: string; content: string }): number {
  let score = 0;
  const urlLower = result.url.toLowerCase();
  const contentLower = result.content.toLowerCase();
  const titleLower = result.title.toLowerCase();

  // Domain reputation (0–40 pts)
  const tier1 = ["apple.com", "google.com", "microsoft.com", "nvidia.com", "developer.apple.com"];
  const tier2 = ["macrumors.com", "theverge.com", "arstechnica.com", "techcrunch.com", "wired.com",
    "reuters.com", "apnews.com", "bbc.com", "bbc.co.uk", "nytimes.com", "washingtonpost.com",
    "bloomberg.com", "wsj.com", "cnbc.com", "ft.com"];
  const tier3 = ["tomshardware.com", "anandtech.com", "cnet.com", "engadget.com", "9to5mac.com",
    "9to5google.com", "tomsguide.com", "pcmag.com", "zdnet.com", "gsmarena.com", "howtogeek.com"];
  const tier4 = ["wikipedia.org", "github.com", "stackoverflow.com", "medium.com", "substack.com"];

  if (tier1.some((d) => urlLower.includes(d))) score += 40;
  else if (tier2.some((d) => urlLower.includes(d))) score += 35;
  else if (tier3.some((d) => urlLower.includes(d))) score += 25;
  else if (tier4.some((d) => urlLower.includes(d))) score += 15;
  else score += 5;

  // Content quality signals (0–30 pts)
  const hasSpecificData = /\$\d|€\d|\d{3,}(?:\s*mah|\s*gb|\s*tb|\s*ghz|\s*mm)|(?:a\d{2}|m\d)\s*(?:pro|max|chip)/i.test(result.content);
  if (hasSpecificData) score += 15;
  const hasAttribution = /(?:press release|official|announced|by\s+[A-Z][a-z]+ [A-Z])/i.test(result.content);
  if (hasAttribution) score += 10;
  if (result.content.length > 200) score += 5;

  // Red flags (negative pts)
  const aiSpam = /in this article|let'?s explore|let'?s dive|in this comprehensive|everything you need to know/i.test(contentLower + " " + titleLower);
  if (aiSpam) score -= 15;
  const speculative = /\b(?:rumored|reportedly|expected to|could be|might be|is said to|unconfirmed)\b/i.test(contentLower);
  if (speculative) score -= 10;
  const spamUrl = /affiliate|ai-generated|sponsored/i.test(urlLower) || (urlLower.split("/").length > 8);
  if (spamUrl) score -= 5;

  return Math.max(0, Math.min(100, score));
}

/** Verify URLs by fetching them (HEAD request, 5s timeout) */
export async function verifyURLs(results: { title: string; url: string; content: string }[]): Promise<{ title: string; url: string; content: string; urlStatus: string }[]> {
  const verified = await Promise.all(
    results.map(async (r) => {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);
        const response = await fetch(r.url, {
          method: "HEAD",
          signal: controller.signal,
          redirect: "follow",
        });
        clearTimeout(timeout);
        const status = response.status >= 200 && response.status < 400
          ? "VERIFIED: 200 OK"
          : `BROKEN: ${response.status}`;
        return { ...r, urlStatus: status };
      } catch (error) {
        const isTimeout = (error as Error).name === "AbortError";
        return { ...r, urlStatus: isTimeout ? "TIMEOUT" : "BROKEN: 404/Error" };
      }
    })
  );
  const verifiedCount = verified.filter((r) => r.urlStatus.startsWith("VERIFIED")).length;
  const brokenCount = verified.filter((r) => r.urlStatus.startsWith("BROKEN")).length;
  console.log(`[URLVerifier] ${verifiedCount} verified, ${brokenCount} broken, ${verified.length - verifiedCount - brokenCount} timeout`);
  return verified;
}

/** Format search results with credibility scores and URL verification for LLM prompts */
export function formatSearchContext(results: { title: string; url: string; content: string; urlStatus?: string }[]): string {
  // Score and sort by credibility
  const scored = results
    .map((r) => ({ ...r, credibility: scoreSearchResult(r) }))
    .sort((a, b) => b.credibility - a.credibility);

  const verifiedCount = scored.filter((r) => r.urlStatus?.startsWith("VERIFIED")).length;

  const lines = scored.map((r, i) =>
    `[${i + 1}] [${r.urlStatus || "UNCHECKED"}] [CREDIBILITY: ${r.credibility}/100] ${r.title}\n    ${r.url}\n    ${r.content}`
  );
  return `LIVE WEB SEARCH RESULTS (ranked by source credibility).
Each URL has been MACHINE-VERIFIED by fetching it — this is not an LLM opinion.
${verifiedCount} of ${scored.length} URLs returned HTTP 200 (confirmed to exist).
Sources marked [VERIFIED: 200 OK] are CONFIRMED REAL PAGES. Their content is factual.
Sources marked [BROKEN: 404/Error] may be fabricated — ignore their claims.
You MUST NOT claim a product "does not exist" if ANY verified source describes it.

Sources:
${lines.join("\n\n")}`;
}

export function sendSSE(res: Response, data: Record<string, unknown>) {
  if (!res.writableEnded) {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  }
}

type ComplexityTier = "brief" | "moderate" | "detailed";

interface LengthConfig {
  tier: ComplexityTier;
  maxTokens: number;
  promptInstruction: string;
  verifyInstruction: string;
  finalInstruction: string;
}

export function classifyComplexity(query: string): LengthConfig {
  const words = query.trim().split(/\s+/);
  const wordCount = words.length;
  const lower = query.toLowerCase();

  let score = 0;

  // Word count
  if (wordCount >= 9 && wordCount <= 25) score += 1;
  else if (wordCount >= 26 && wordCount <= 50) score += 2;
  else if (wordCount > 50) score += 3;

  // Multiple question marks
  if ((query.match(/\?/g) || []).length >= 2) score += 2;

  // Multi-part connectors
  if (/and also|additionally|furthermore|moreover/i.test(query) ||
      /\d+\.\s/.test(query) || query.includes(";")) {
    score += 2;
  }

  // Depth keywords (cap at +2)
  const depthKeywords = ["explain", "analyze", "analyse", "compare", "contrast", "discuss", "step by step", "in detail", "elaborate", "comprehensive"];
  let depthHits = 0;
  for (const kw of depthKeywords) {
    if (lower.includes(kw)) depthHits++;
  }
  score += Math.min(depthHits, 2);

  // Simplicity keywords
  const simplicityPatterns = ["what is", "what's", "define", "who is", "who's", "yes or no", "true or false"];
  for (const pat of simplicityPatterns) {
    if (lower.includes(pat)) { score -= 2; break; }
  }

  if (score <= 0) {
    return {
      tier: "brief",
      maxTokens: 512,
      promptInstruction: "Respond concisely. A few sentences is ideal.",
      verifyInstruction: "Keep your verification concise. Only flag real issues.",
      finalInstruction: "Synthesize into a brief, direct answer.",
    };
  }
  if (score <= 3) {
    return {
      tier: "moderate",
      maxTokens: 1536,
      promptInstruction: "Cover key points without excessive elaboration.",
      verifyInstruction: "Verify key claims. Be thorough but not verbose.",
      finalInstruction: "Produce a clear, well-structured answer covering the key points.",
    };
  }
  return {
    tier: "detailed",
    maxTokens: 3072,
    promptInstruction: "Be thorough and comprehensive. Cover all aspects in depth.",
    verifyInstruction: "Conduct a thorough verification. Check every claim and add missing detail.",
    finalInstruction: "Produce a comprehensive, detailed synthesis covering all aspects in depth.",
  };
}

async function streamAnthropic(
  model: string,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number,
  maxTokens: number
): Promise<string> {
  let fullResponse = "";

  const stream = anthropic.messages.stream({
    model,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: "user", content: userContent }],
  });

  for await (const event of stream) {
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      const content = event.delta.text;
      if (content) {
        fullResponse += content;
        sendSSE(res, { type: "stage_content", stage, content });
      }
    }
  }

  return fullResponse;
}

async function streamGemini(
  model: string,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number,
  maxTokens: number
): Promise<string> {
  let fullResponse = "";

  const stream = await gemini.models.generateContentStream({
    model,
    contents: [
      {
        role: "user",
        parts: [{ text: `${systemPrompt}\n\n${userContent}` }],
      },
    ],
    config: {
      maxOutputTokens: maxTokens,
    },
  });

  for await (const chunk of stream) {
    const content = chunk.text || "";
    if (content) {
      fullResponse += content;
      sendSSE(res, { type: "stage_content", stage, content });
    }
  }

  return fullResponse;
}

async function streamXAI(
  model: string,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number,
  maxTokens: number
): Promise<string> {
  let fullResponse = "";
  const client = getXAIClient();

  const stream = await client.chat.completions.create({
    model,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userContent },
    ],
    stream: true,
    max_tokens: maxTokens,
  });

  for await (const chunk of stream) {
    const content = chunk.choices[0]?.delta?.content || "";
    if (content) {
      fullResponse += content;
      sendSSE(res, { type: "stage_content", stage, content });
    }
  }

  return fullResponse;
}

export async function runStage(
  model: LLMModel,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number,
  maxTokens: number
): Promise<string> {
  sendSSE(res, { type: "stage_start", stage, model });

  try {
    let result: string;

    switch (model.provider) {
      case "anthropic":
        result = await streamAnthropic(model.model, systemPrompt, userContent, res, stage, maxTokens);
        break;
      case "gemini":
        result = await streamGemini(model.model, systemPrompt, userContent, res, stage, maxTokens);
        break;
      case "xai":
        result = await streamXAI(model.model, systemPrompt, userContent, res, stage, maxTokens);
        break;
      default:
        throw new Error(`Unknown provider: ${model.provider}`);
    }

    sendSSE(res, { type: "stage_complete", stage });
    return result;
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    sendSSE(res, { type: "stage_error", stage, error: errorMessage });
    throw error;
  }
}

// Non-streaming LLM calls for analysis.
// When jsonMode is true, providers that support it will enforce JSON output
// at the API level (Gemini via responseMimeType, xAI/OpenAI via response_format).
// Anthropic relies on the system prompt instruction since its Messages API
// does not have a dedicated JSON mode flag.
async function callLLM(
  provider: string,
  model: string,
  systemPrompt: string,
  userContent: string,
  maxTokens: number,
  jsonMode: boolean = false
): Promise<string> {
  switch (provider) {
    case "anthropic": {
      const msg = await anthropic.messages.create({
        model,
        max_tokens: maxTokens,
        system: systemPrompt,
        messages: [{ role: "user", content: userContent }],
      });
      return msg.content
        .filter((b) => b.type === "text")
        .map((b) => (b as { type: "text"; text: string }).text)
        .join("");
    }
    case "gemini": {
      const config: Record<string, unknown> = { maxOutputTokens: maxTokens };
      if (jsonMode) {
        config.responseMimeType = "application/json";
      }
      const result = await gemini.models.generateContent({
        model,
        contents: [{ role: "user", parts: [{ text: `${systemPrompt}\n\n${userContent}` }] }],
        config,
      });
      return result.text || "";
    }
    case "xai": {
      const client = getXAIClient();
      const params: Record<string, unknown> = {
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        max_tokens: maxTokens,
      };
      if (jsonMode) {
        params.response_format = { type: "json_object" };
      }
      const completion = await client.chat.completions.create(params as any);
      return completion.choices[0]?.message?.content || "";
    }
    default:
      throw new Error(`Unknown provider: ${provider}`);
  }
}

interface CompletedStage {
  stage: number;
  model: LLMModel;
  content: string;
}

/** Map provider ID to short display name for analyst bullets */
function providerShortName(provider: string): string {
  switch (provider) {
    case "anthropic": return "Claude";
    case "gemini": return "Gemini";
    case "xai": return "Grok";
    default: return provider;
  }
}

/** Build contextual fallback bullets from pipeline metadata when LLM analysis is unavailable */
function buildFallbackBullets(
  query: string,
  completedStages: CompletedStage[],
  totalStages: number,
  liveResearchUsed: boolean
): string[] {
  const bullets: string[] = [];

  // Extract a short topic snippet from the query (first ~60 chars at word boundary)
  const trimmed = query.trim();
  let topicSnippet = trimmed;
  if (trimmed.length > 60) {
    const prefix = trimmed.slice(0, 60);
    const lastSpace = prefix.lastIndexOf(" ");
    topicSnippet = lastSpace > 0 ? prefix.slice(0, lastSpace) + "\u2026" : prefix + "\u2026";
  }

  // Bullet 1: Model names used
  const modelNames = Array.from(new Set(completedStages.map((s) => providerShortName(s.model.provider))));
  bullets.push(`Queried "${topicSnippet}" through ${modelNames.join(", ")}`);

  // Bullet 2: Pipeline completion
  if (completedStages.length === totalStages) {
    bullets.push(`All ${completedStages.length} verification stages completed successfully`);
  } else {
    bullets.push(`${completedStages.length} of ${totalStages} stages completed \u2014 partial coverage`);
  }

  // Bullet 3: Live research or data source note
  if (liveResearchUsed) {
    bullets.push("Grounded with live web data via Tavily search");
  } else {
    bullets.push("Based on model training data \u2014 no live web sources used");
  }

  return bullets;
}

function fallbackSummary(
  query: string,
  completedStages: CompletedStage[],
  totalStages: number,
  liveResearchUsed: boolean = false
): VerificationSummary {
  const completed = completedStages.length;
  const skipped = totalStages - completed;
  const consistency = completed < 2
    ? "Insufficient stages for cross-verification"
    : skipped > 0
      ? `Cross-verified across ${completed} of ${totalStages} LLMs (${skipped} skipped)`
      : `Cross-verified across ${completed} independent LLMs`;

  const confidence = completed >= 3
    ? "High \u2013 multi-stage verification complete"
    : completed === 2
      ? "Moderate \u2013 dual verification complete"
      : "Low \u2013 single-stage only";

  const hallucinations = skipped > 0
    ? `Checked at ${completed} of ${totalStages} stages \u2013 coverage reduced`
    : "Checked at each stage \u2013 potential issues flagged";

  const analysisBullets = buildFallbackBullets(query, completedStages, totalStages, liveResearchUsed);

  return { consistency, hallucinations, confidence, contradictions: [], isAnalyzed: false, analysisBullets };
}

// ── Judge Stage ──────────────────────────────────────────────────────
// The Judge is a dedicated analysis stage that runs after all verification
// stages complete. It produces a comprehensive structured verdict with:
// - Per-stage agreement scores (0–100), key claims, hallucination flags
// - Overall score, confidence, and expert-style key findings
// The Judge output is validated against the JudgeVerdict Zod schema.

/** Parse raw LLM text as JSON, stripping markdown fences if needed */
function parseJudgeJSON(text: string): any {
  try {
    return JSON.parse(text);
  } catch {
    const cleaned = text
      .replace(/```json\s*/g, "")
      .replace(/```\s*/g, "")
      .trim();
    return JSON.parse(cleaned);
  }
}

/**
 * Determine if the Tie-Breaker stage should run based on Judge verdict.
 * Triggers when:
 *   1. Score variance between stages > 25 points (strong disagreement)
 *   2. Overall Judge score < 50 (low confidence)
 *   3. >= 2 "flagged" or "corrected" provenance entries (significant corrections)
 */
export function shouldTriggerTieBreaker(verdict: JudgeVerdict | undefined): { triggered: boolean; reason: string } {
  if (!verdict || verdict.stageAnalyses.length < 2) return { triggered: false, reason: "" };

  const scores = verdict.stageAnalyses.map((sa) => sa.agreementScore);
  const scoreVariance = Math.max(...scores) - Math.min(...scores) > 25;

  const lowConfidence = verdict.overallScore < 50;

  const flaggedOrCorrected = verdict.stageAnalyses.flatMap((sa) =>
    sa.claims.flatMap((c) => (c.provenance || []).filter((p) =>
      p.changeType === "flagged" || p.changeType === "corrected"
    ))
  ).length;
  const hasManyFlags = flaggedOrCorrected >= 2;

  const reasons: string[] = [];
  if (scoreVariance) reasons.push(`stage score variance > 25pts`);
  if (lowConfidence) reasons.push(`overall score ${verdict.overallScore}/100`);
  if (hasManyFlags) reasons.push(`${flaggedOrCorrected} flagged/corrected claims`);

  return {
    triggered: scoreVariance || lowConfidence || hasManyFlags,
    reason: reasons.join(", "),
  };
}

/** Pick the strongest available model for the Judge call */
function pickJudgeModel(): { provider: string; model: string } | null {
  // Prefer strong models — the Judge needs the best reasoning
  const candidates: { provider: string; model: string; envKey: string }[] = [
    { provider: "anthropic", model: "claude-sonnet-4-5", envKey: "AI_INTEGRATIONS_ANTHROPIC_API_KEY" },
    { provider: "gemini", model: "gemini-2.5-flash", envKey: "AI_INTEGRATIONS_GEMINI_API_KEY" },
    { provider: "xai", model: "grok-3", envKey: "XAI_API_KEY" },
  ];
  const chosen = candidates.find((c) => process.env[c.envKey]);
  return chosen ? { provider: chosen.provider, model: chosen.model } : null;
}

/** Pick model for the Tie-Breaker — Grok first (has real-time X data) */
export function pickTieBreakerModel(): { provider: string; model: string } | null {
  const candidates: { provider: string; model: string; envKey: string }[] = [
    { provider: "xai", model: "grok-3", envKey: "XAI_API_KEY" },
    { provider: "gemini", model: "gemini-2.5-flash", envKey: "AI_INTEGRATIONS_GEMINI_API_KEY" },
    { provider: "anthropic", model: "claude-sonnet-4-5", envKey: "AI_INTEGRATIONS_ANTHROPIC_API_KEY" },
  ];
  const chosen = candidates.find((c) => process.env[c.envKey]);
  return chosen ? { provider: chosen.provider, model: chosen.model } : null;
}

export async function runJudge(
  query: string,
  completedStages: CompletedStage[],
  totalStages: number,
  liveResearchUsed: boolean = false,
  searchContext: string = ""
): Promise<VerificationSummary> {
  if (completedStages.length < 2) {
    return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
  }

  const judgeModel = pickJudgeModel();
  if (!judgeModel) {
    return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
  }

  // Build the stage outputs text block for the Judge
  const modelNames = completedStages.map((s) => `${providerShortName(s.model.provider)} (${s.model.model})`).join(", ");
  const liveResearchNote = liveResearchUsed ? " Live web research (Tavily) was used to ground Stage 1 with real-time data." : "";

  // Cap each stage's content to ~4000 chars to keep Judge input within model context limits.
  const maxStageChars = 4000;
  let stageOutputsText = "";
  for (const stage of completedStages) {
    stageOutputsText += `── Stage ${stage.stage} (${providerShortName(stage.model.provider)} / ${stage.model.model}) ──\n`;
    if (stage.content.length > maxStageChars) {
      stageOutputsText += stage.content.slice(0, maxStageChars);
      stageOutputsText += "\n[... truncated for Judge analysis]\n";
    } else {
      stageOutputsText += stage.content;
    }
    stageOutputsText += "\n\n";
  }
  console.log(`[Judge] Input: ${completedStages.length} stages, ~${stageOutputsText.length} chars total`);

  // The Judge prompt requests the full JudgeVerdict JSON structure with
  // per-stage analysis (claims, scores, hallucination flags) and overall verdict
  const systemPrompt = `You are the final JUDGE in Rosin AI's multi-LLM verification pipeline. The models used were: ${modelNames}.${liveResearchNote}

Your job is to synthesize all previous stages and produce a truthful, well-calibrated final verdict.

CONSENSUS RULE (HIGHEST PRIORITY):
- When ALL or MOST stages agree on a claim (especially about a product's existence, specs, or pricing), you MUST heavily favor that consensus. Do NOT override multi-stage agreement with your own skepticism.
- You may ONLY override strong stage consensus when you have clear, specific contradictory evidence from high-credibility sources (apple.com, official press releases, MacRumors, The Verge, etc.).
- If you do override consensus, you MUST explain exactly why with specific evidence. "I don't recognize this product" is NOT valid evidence.

NEW/RECENT PRODUCTS (within last 60 days):
- Recent web search results + stage consensus are MORE reliable than your training data.
- Only declare a product "does not exist" when there is overwhelming evidence: zero official presence on apple.com, no press releases, no credible journalism. Noisy or speculative sources are NOT sufficient grounds.
- When Live Research was used, treat the provided Tavily results as primary evidence.

CONFIDENCE RULES:
- confidence MUST be consistent with overallScore: "high" (score >= 80), "moderate" (50-79), "low" (< 50).
- NEVER output a low score with "high" confidence or vice versa.

Always prioritize truth and evidence over forced skepticism.

Respond with ONLY valid JSON (no markdown, no code fences) matching this exact schema:
{
  "verdict": "2-3 sentence expert verdict summarizing the verification result, referencing the actual topic",
  "overallScore": 87,
  "confidence": "high",
  "keyFindings": [
    "Finding 1 — topic-specific, referencing models by short name (Claude/Gemini/Grok)",
    "Finding 2 — note consensus or disagreements between specific models",
    "Finding 3 — confidence justification tied to the query content",
    "Finding 4 — mention live web research if used, or note data currency"
  ],
  "stageAnalyses": [
    {
      "stage": 1,
      "agreementScore": 92,
      "claims": [
        {
          "text": "Key claim extracted from this stage",
          "confidence": 85,
          "sources": [],
          "provenance": [
            {
              "model": "Claude",
              "stage": 1,
              "changeType": "added",
              "newText": "Key claim as first introduced",
              "reason": "Initial response to query"
            }
          ]
        }
      ],
      "hallucinationFlags": [
        { "claim": "Specific claim that may be hallucinated", "reason": "Why it's suspect", "severity": "low" }
      ],
      "corrections": ["Corrections this stage made to previous output"]
    }
  ]
}

JSON field rules:
- verdict: 2-3 sentences, never generic — reference the actual query topic
- overallScore: 0-100 representing factual confidence weighted by source recency
- keyFindings: 3-5 items, each under 120 chars, referencing models by name
- stageAnalyses: one entry per stage with agreementScore 0-100
  - claims: 2-5 key factual claims per stage with confidence 0-100
    - Each claim MUST include a "provenance" array tracking its lifecycle:
      - model: short name of the model (Claude/Gemini/Grok)
      - stage: stage number where the change occurred
      - changeType: "added" (new claim), "modified" (refined), "flagged" (questioned), "corrected" (error fixed)
      - originalText: (optional) the previous version of the claim before modification/correction
      - newText: the claim text as it stands after this change
      - reason: one sentence explaining why this change was made
    - Stage 1 claims always have one "added" entry. Later stages may add "modified"/"corrected" entries.
    - If a claim was introduced in stage 1 and unchanged through all stages, it has only the single "added" entry.
  - hallucinationFlags: only include if genuinely suspect (empty array if none)
  - corrections: list corrections this stage made (empty for stage 1)
- If live research was used, mention it in keyFindings
- Be specific — never say "the query" or "the topic", say what it actually is`;

  let userContent = `Original Query: ${query}\n\n${stageOutputsText}`;
  if (searchContext) {
    userContent += `── VERIFIED LIVE WEB RESEARCH (Tavily — real-time, retrieved just now) ──\nTHE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND OVERRIDE YOUR TRAINING DATA.\n\n${searchContext}\n`;
  }

  // Attempt the Judge call with one retry if JSON parsing fails entirely.
  // Uses jsonMode: true so providers that support it (Gemini, xAI) enforce
  // JSON output at the API level, reducing parse failures.
  const MAX_JUDGE_ATTEMPTS = 2;
  let lastError: unknown;

  for (let attempt = 1; attempt <= MAX_JUDGE_ATTEMPTS; attempt++) {
    try {
      console.log(`Running Judge stage with ${judgeModel.provider}/${judgeModel.model} (attempt ${attempt})`);
      const responseText = await callLLM(judgeModel.provider, judgeModel.model, systemPrompt, userContent, 8192, true);
      const raw = parseJudgeJSON(responseText);

      // Validate with Zod — if it fails, we still try to extract what we can
      const judgeResult = judgeVerdictSchema.safeParse(raw);
      let judgeVerdict: JudgeVerdict;

      if (judgeResult.success) {
        judgeVerdict = judgeResult.data;
      } else {
        console.warn(`Judge JSON didn't fully validate (attempt ${attempt}), using raw with defaults:`, judgeResult.error.issues);
        // Graceful degradation: build a valid verdict from whatever we got
        judgeVerdict = {
          verdict: raw.verdict || "Verification analysis complete",
          overallScore: typeof raw.overallScore === "number" ? Math.max(0, Math.min(100, raw.overallScore)) : 75,
          confidence: ["high", "moderate", "low"].includes(raw.confidence) ? raw.confidence : "moderate",
          keyFindings: Array.isArray(raw.keyFindings) ? raw.keyFindings.map(String) : [],
          stageAnalyses: Array.isArray(raw.stageAnalyses) ? raw.stageAnalyses.map((sa: any) => ({
            stage: sa.stage || 0,
            agreementScore: typeof sa.agreementScore === "number" ? sa.agreementScore : 75,
            claims: Array.isArray(sa.claims) ? sa.claims : [],
            hallucinationFlags: Array.isArray(sa.hallucinationFlags) ? sa.hallucinationFlags : [],
            corrections: Array.isArray(sa.corrections) ? sa.corrections : [],
          })) : [],
        };
      }

      // Enforce confidence ↔ score consistency (prevent "25/100 — High confidence" contradictions)
      const expectedConfidence = judgeVerdict.overallScore >= 80 ? "high" : judgeVerdict.overallScore >= 50 ? "moderate" : "low";
      if (judgeVerdict.confidence !== expectedConfidence) {
        console.warn(`Judge confidence mismatch: score=${judgeVerdict.overallScore} but confidence="${judgeVerdict.confidence}", correcting to "${expectedConfidence}"`);
        judgeVerdict = { ...judgeVerdict, confidence: expectedConfidence };
      }

      // Build the VerificationSummary from the Judge verdict
      const confidenceScore = judgeVerdict.overallScore / 100;
      const confidenceText = `${judgeVerdict.confidence.charAt(0).toUpperCase() + judgeVerdict.confidence.slice(1)} (${judgeVerdict.overallScore}%)`;

      // Extract high-severity hallucination flags as contradictions
      const contradictions = judgeVerdict.stageAnalyses.flatMap((sa) =>
        sa.hallucinationFlags
          .filter((f) => f.severity === "high")
          .map((f) => ({
            topic: f.claim,
            stageA: sa.stage,
            stageB: 0,
            description: f.reason,
          }))
      );

      // Count total hallucination flags across all stages
      const totalFlags = judgeVerdict.stageAnalyses.reduce((sum, sa) => sum + sa.hallucinationFlags.length, 0);
      const hallucinationText = totalFlags === 0
        ? "No hallucinations detected across any stage"
        : `${totalFlags} potential issue${totalFlags > 1 ? "s" : ""} flagged across ${judgeVerdict.stageAnalyses.filter((sa) => sa.hallucinationFlags.length > 0).length} stage${judgeVerdict.stageAnalyses.filter((sa) => sa.hallucinationFlags.length > 0).length > 1 ? "s" : ""}`;

      // Consistency from agreement scores
      const avgAgreement = judgeVerdict.stageAnalyses.length > 0
        ? Math.round(judgeVerdict.stageAnalyses.reduce((sum, sa) => sum + sa.agreementScore, 0) / judgeVerdict.stageAnalyses.length)
        : 0;
      const consistencyText = `${avgAgreement}% average agreement across ${completedStages.length} stages`;

      return {
        consistency: consistencyText,
        hallucinations: hallucinationText,
        confidence: confidenceText,
        contradictions,
        confidenceScore,
        isAnalyzed: true,
        analysisBullets: judgeVerdict.keyFindings,
        judgeVerdict,
      };
    } catch (error) {
      lastError = error;
      console.error(`Judge attempt ${attempt} failed:`, error);
      // Loop will retry if attempts remain
    }
  }

  // All attempts exhausted — fall back to metadata-based summary
  console.error("Judge stage failed after all attempts, using fallback:", lastError);
  return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
}

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {
  registerAuthRoutes(app);
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

  app.get("/api/history", async (_req, res) => {
    try {
      const runs = await storage.listVerifications(50);
      const items = runs.map((r) => ({
        id: r.id,
        query: r.query,
        chainSummary: r.chain.map((m) => m.model).join(" → "),
        stageCount: r.stages.length,
        confidenceScore: r.summary?.confidenceScore,
        contradictionCount: r.summary?.contradictions?.length || 0,
        adversarialMode: r.adversarialMode,
        createdAt: r.createdAt,
      }));
      res.json(items);
    } catch (error) {
      res.status(500).json({ error: "Failed to load history" });
    }
  });

  app.get("/api/history/:id", async (req, res) => {
    try {
      const run = await storage.getVerification(req.params.id);
      if (!run) {
        return res.status(404).json({ error: "Verification not found" });
      }
      res.json(run);
    } catch (error) {
      res.status(500).json({ error: "Failed to load verification" });
    }
  });

  app.get("/api/report/:id", async (req, res) => {
    try {
      const run = await storage.getVerification(req.params.id);
      if (!run) {
        return res.status(404).json({ error: "Verification not found" });
      }
      res.json(run);
    } catch (error) {
      res.status(500).json({ error: "Failed to load report" });
    }
  });

  // Generate a concise bullet-point summary of the final verified answer
  app.post("/api/summarize", async (req, res) => {
    try {
      const { text } = req.body;
      if (!text || typeof text !== "string") {
        return res.status(400).json({ error: "Missing 'text' field" });
      }

      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 512,
        system:
          "You are a precise summarizer. Given a verified answer, produce a concise summary as 3-6 bullet points. " +
          "Each bullet should capture one key fact or conclusion. Use plain language. " +
          "Start each bullet with '•'. Do not add any preamble or closing — just the bullets.",
        messages: [{ role: "user", content: text }],
      });

      const summary = (msg.content[0] as { type: string; text: string }).text?.trim() || "Unable to generate summary.";
      res.json({ summary });
    } catch (error) {
      console.error("Summarize error:", error);
      res.status(500).json({ error: "Failed to generate summary" });
    }
  });

  app.get("/api/disagreement-stats", async (_req, res) => {
    try {
      const stats = await storage.getDisagreementStats();
      res.json(stats);
    } catch (error) {
      res.status(500).json({ error: "Failed to compute stats" });
    }
  });

  return httpServer;
}
