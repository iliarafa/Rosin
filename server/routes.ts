import type { Express, Response } from "express";
import { createServer, type Server } from "http";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";
import { tavily } from "@tavily/core";
import { insertVerificationRequestSchema, type LLMModel, type VerificationSummary, type JudgeVerdict, type StageAnalysis, judgeVerdictSchema } from "@shared/schema";
import { z } from "zod";
import { storage } from "./storage";
import { randomUUID } from "crypto";

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

/** Format Tavily search results with credibility scores for LLM prompts */
function formatSearchContext(results: { title: string; url: string; content: string }[]): string {
  // Score and sort by credibility
  const scored = results
    .map((r) => ({ ...r, credibility: scoreSearchResult(r) }))
    .sort((a, b) => b.credibility - a.credibility);

  const lines = scored.map((r, i) =>
    `[${i + 1}] [CREDIBILITY: ${r.credibility}/100] ${r.title}\n    ${r.url}\n    ${r.content}`
  );
  return `LIVE WEB SEARCH RESULTS (ranked by source credibility).
Prioritize high-credibility sources (≥80) over low-credibility ones (<60).
Sources with credibility ≥80 are from established, reputable outlets — trust them over your training data.
Sources with credibility <40 may be AI-generated or speculative — treat with caution.

Sources:
${lines.join("\n\n")}`;
}

function sendSSE(res: Response, data: Record<string, unknown>) {
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

function classifyComplexity(query: string): LengthConfig {
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

async function runStage(
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
function shouldTriggerTieBreaker(verdict: JudgeVerdict | undefined): { triggered: boolean; reason: string } {
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

async function runJudge(
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
  app.post("/api/verify", async (req, res) => {
    try {
      const extendedSchema = insertVerificationRequestSchema.extend({
        adversarialMode: z.boolean().optional().default(false),
        liveResearch: z.boolean().optional().default(false),
        autoTieBreaker: z.boolean().optional().default(true),
      });
      const parsed = extendedSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: "Invalid request", details: parsed.error.errors });
      }

      const { query, chain, adversarialMode, liveResearch, autoTieBreaker } = parsed.data;

      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");
      res.setHeader("X-Accel-Buffering", "no");

      const checkDisconnect = () => {
        if (res.writableEnded) {
          console.log("Response already ended, stopping");
          throw new Error("Client disconnected");
        }
      };

      const totalStages = chain.length;
      const lengthConfig = classifyComplexity(query);

      // Live Research: run Tavily search before the verification pipeline
      let searchContext = "";
      if (liveResearch) {
        const client = getTavilyClient();
        if (client) {
          // Emit a research_start event so the UI shows a search indicator
          sendSSE(res, { type: "research_start" });
          try {
            const searchResponse = await client.search(query, {
              maxResults: 8,
              searchDepth: "advanced",
              includeAnswer: true,
            });
            const results = searchResponse.results.map((r) => ({
              title: r.title,
              url: r.url,
              content: r.content,
            }));
            searchContext = formatSearchContext(results);

            // Stream a brief summary of sources found
            const sourceSummary = results
              .map((r, i) => `  [${i + 1}] ${r.title} — ${r.url}`)
              .join("\n");
            sendSSE(res, {
              type: "research_complete",
              sourceCount: results.length,
              sources: sourceSummary,
            });
          } catch (searchError) {
            console.error("Tavily search failed, continuing without web context:", searchError);
            sendSSE(res, { type: "research_error", error: "Web search unavailable — proceeding without live data" });
          }
        } else {
          // No Tavily key configured — warn and proceed
          sendSSE(res, { type: "research_error", error: "TAVILY_API_KEY not configured — proceeding without live data" });
        }
      }

      const hasWebResearch = searchContext.length > 0;

      const getStagePrompt = (stageNum: number, isLast: boolean): string => {
        if (stageNum === 1) {
          const webResearchDirective = hasWebResearch
            ? `\n\nIMPORTANT: You have been provided with live web search results alongside the user's query. These results contain current, real-time information retrieved just now. You MUST:
- Use the web search results as your primary source for current events, recent developments, and time-sensitive information
- Cite sources by their number (e.g. [1], [2]) when referencing information from the search results
- Do NOT disclaim knowledge cutoffs or say you lack access to current information — the search results ARE your access to current information
- If the search results conflict with your training data, prefer the search results as they are more recent`
            : "";
          return `You are the first stage of a multi-LLM verification pipeline. Your task is to provide an initial, thorough response to the user's query. Focus on accuracy and comprehensive coverage of the topic.

Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.${webResearchDirective}

${lengthConfig.promptInstruction}`;
        }

        if (isLast) {
          return `You are the final stage of a multi-LLM verification pipeline. You produce the definitive, verified response.
${hasWebResearch ? "\nYou have live web search results below — use them as your primary source of truth.\n" : ""}
Your tasks:
1. Synthesize all previous stages into a clear, concise final answer
2. ${hasWebResearch ? "Ground your answer in the web search results provided" : "Final verification of all claims"}
3. Remove any redundancy
4. Ensure the response is well-structured and easy to understand
5. Note any remaining caveats or areas of genuine uncertainty

Produce the final verified response that best answers the user's original query.

${lengthConfig.finalInstruction}`;
        }

        // Middle stage — adversarial or standard (only when no web research)
        if (adversarialMode && !hasWebResearch) {
          return `You are in ADVERSARIAL MODE. You are stage ${stageNum} of a multi-LLM verification pipeline. Your job is to find flaws.

Your tasks:
1. Actively search for errors and weak claims in the previous response
2. Challenge every assumption — demand evidence
3. Identify hallucinations and fabricated details
4. Cross-check facts rigorously against your knowledge
5. Flag misleading, vague, or unsubstantiated information
6. Provide a corrected and hardened version of the response

Be aggressive in your analysis. Do not give the benefit of the doubt.

${lengthConfig.verifyInstruction}`;
        }

        // When live web research is available, reframe the task as "refine using sources"
        // instead of "verify and find errors" — the verification framing causes models to
        // flag web-sourced facts as hallucinations when they're absent from training data.
        if (hasWebResearch) {
          return `You are stage ${stageNum} of a multi-LLM verification pipeline. You have been provided with live web search results AND the previous stage's response.

Your tasks:
1. Use the web search results as your primary source of truth
2. Refine and improve the previous response using evidence from the web sources
3. Add any relevant details from the web sources that the previous stage missed
4. Ensure the response directly answers the user's question
5. Do NOT question whether subjects mentioned in the web sources exist — they have been verified via live search

Produce an improved, well-sourced response.

${lengthConfig.verifyInstruction}`;
        }

        return `You are stage ${stageNum} of a multi-LLM verification pipeline. You are reviewing and verifying the previous output.

Your tasks:
1. Verify the factual accuracy of the previous response
2. Identify any potential errors, hallucinations, or unsupported claims
3. Correct any inaccuracies you find
4. Add any important information that was missed
5. Cross-check the information against your knowledge
6. Improve clarity where needed

Provide a refined and verified version of the response.

${lengthConfig.verifyInstruction}`;
      };

      let previousOutput = query;
      const completedStages: CompletedStage[] = [];

      console.log(`Starting verification with ${totalStages} stages${adversarialMode ? " [ADVERSARIAL]" : ""}`);

      for (let i = 0; i < totalStages; i++) {
        checkDisconnect();
        const stageNum = i + 1;
        const isFirst = i === 0;
        const isLast = i === totalStages - 1;
        const prompt = getStagePrompt(stageNum, isLast);

        console.log(`Starting stage ${stageNum}/${totalStages}, provider: ${chain[i].provider}, model: ${chain[i].model}`);

        // Every stage gets the Tavily results so each model can independently
        // verify claims against fresh web sources, not just training data.
        let userContent = isFirst
          ? `Original Query: ${query}`
          : `Original Query: ${query}\n\nPrevious Response:\n${previousOutput}`;
        if (searchContext) {
          userContent += `\n\n── LIVE WEB RESEARCH (Tavily — retrieved just now) ──\n${searchContext}`;
        }

        try {
          previousOutput = await runStage(chain[i], prompt, userContent, res, stageNum, lengthConfig.maxTokens);
          completedStages.push({ stage: stageNum, model: chain[i], content: previousOutput });
          console.log(`Stage ${stageNum} completed successfully`);
        } catch (stageError) {
          console.error(`Stage ${stageNum} failed:`, stageError);
          throw stageError;
        }
      }

      // ── Judge Stage ──
      // Run the dedicated Judge to produce structured per-stage analysis + overall verdict
      let summary = await runJudge(query, completedStages, totalStages, liveResearch, searchContext);

      // ── Auto Tie-Breaker ──
      // If the Judge detects strong disagreement, run an extra verification stage
      // to resolve conflicts before finalizing the result.
      const tieBreak = shouldTriggerTieBreaker(summary.judgeVerdict);
      if (tieBreak.triggered && autoTieBreaker) {
        checkDisconnect();
        console.log(`Tie-breaker triggered: ${tieBreak.reason}`);
        sendSSE(res, { type: "tie_breaker_triggered", reason: tieBreak.reason });

        const tbModel = pickJudgeModel();
        if (tbModel) {
          const tbStageNum = totalStages + 1;
          const jv = summary.judgeVerdict!;

          // Build Judge analysis context for the tie-breaker
          const flaggedIssues = jv.stageAnalyses.flatMap((sa) =>
            sa.hallucinationFlags.map((f) => `[Stage ${sa.stage}] [${f.severity.toUpperCase()}] ${f.claim}: ${f.reason}`)
          ).join("\n");

          const tbSystemPrompt = `You are the TIE-BREAKER in Rosin AI — an extra stage triggered because previous stages had conflicting results.

You have been given:
1. The original query
2. All previous stage outputs
3. The Judge's analysis including scores and flagged claims
4. Live web search results (if available)

CONSENSUS RULE (HIGHEST PRIORITY):
- If most or all previous stages AGREE on a claim, your job is to reinforce and refine that consensus — NOT to override it.
- Only break from consensus when you have clear, specific contradictory evidence from high-credibility sources.
- "I don't recognize this product from my training data" is NOT valid grounds to override consensus.

Your tasks:
1. Identify the strongest consensus across stages
2. Reinforce consensus claims with evidence from web sources
3. Resolve any remaining minor conflicts
4. If a claim cannot be verified, say "could not independently verify" — never "does not exist"
5. Produce the definitive final answer aligned with stage consensus and web evidence

${lengthConfig.finalInstruction}`;

          let tbUserContent = `Original Query: ${query}\n\n`;
          for (const stage of completedStages) {
            tbUserContent += `── Stage ${stage.stage} (${providerShortName(stage.model.provider)} / ${stage.model.model}) ──\n`;
            tbUserContent += stage.content;
            tbUserContent += "\n\n";
          }
          tbUserContent += `── Judge Analysis ──\nOverall Score: ${jv.overallScore}/100\nConfidence: ${jv.confidence}\nVerdict: ${jv.verdict}\n\nKey Findings:\n`;
          tbUserContent += jv.keyFindings.map((f) => `• ${f}`).join("\n");
          if (flaggedIssues) {
            tbUserContent += `\n\nFlagged Issues:\n${flaggedIssues}`;
          }
          if (searchContext) {
            tbUserContent += `\n\n── VERIFIED LIVE WEB RESEARCH (Tavily — real-time, retrieved just now) ──\nTHE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND OVERRIDE YOUR TRAINING DATA.\n\n${searchContext}`;
          }

          try {
            const tbOutput = await runStage(tbModel as LLMModel, tbSystemPrompt, tbUserContent, res, tbStageNum, lengthConfig.maxTokens);
            completedStages.push({ stage: tbStageNum, model: tbModel as LLMModel, content: tbOutput });
            console.log("Tie-breaker stage completed, re-running Judge");

            // Re-run the Judge with the expanded stage set for an updated summary
            summary = await runJudge(query, completedStages, completedStages.length, liveResearch, searchContext);
          } catch (tbError) {
            console.error("Tie-breaker stage failed:", tbError);
            // Continue with original summary — tie-breaker is best-effort
          }
        }
      }

      // Send per-stage analysis events so the frontend can show score badges on each stage
      if (summary.judgeVerdict) {
        for (const sa of summary.judgeVerdict.stageAnalyses) {
          sendSSE(res, { type: "stage_analysis", stage: sa.stage, analysis: sa });
        }
      }

      // Save to history (non-blocking)
      const verificationId = randomUUID();
      storage.saveVerification({
        id: verificationId,
        query,
        chain,
        stages: completedStages.map((s) => ({
          stage: s.stage,
          model: s.model,
          content: s.content,
          status: "complete" as const,
        })),
        summary,
        adversarialMode,
        createdAt: new Date().toISOString(),
      }).catch((err) => console.error("Failed to save verification:", err));

      sendSSE(res, { type: "verification_id", id: verificationId });
      sendSSE(res, { type: "summary", summary });
      sendSSE(res, { type: "done" });
      res.end();
    } catch (error) {
      console.error("Verification error:", error);
      if (!res.headersSent) {
        res.status(500).json({ error: "Verification failed" });
      } else {
        sendSSE(res, { type: "error", error: "Verification failed" });
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
