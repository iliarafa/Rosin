import type { Express, Response } from "express";
import { createServer, type Server } from "http";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";
import { tavily } from "@tavily/core";
import { insertVerificationRequestSchema, type LLMModel, type VerificationSummary } from "@shared/schema";
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

/** Format Tavily search results into a context block for LLM prompts */
function formatSearchContext(results: { title: string; url: string; content: string }[]): string {
  const lines = results.map((r, i) =>
    `[${i + 1}] ${r.title}\n    ${r.url}\n    ${r.content}`
  );
  return `You have access to the following live web search results. Use them to ground your answer with current, up-to-date facts. Always prefer this information over your training data when they conflict.\n\nSources:\n${lines.join("\n\n")}`;
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

// Non-streaming LLM calls for analysis
async function callLLM(
  provider: string,
  model: string,
  systemPrompt: string,
  userContent: string,
  maxTokens: number
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
      const result = await gemini.models.generateContent({
        model,
        contents: [{ role: "user", parts: [{ text: `${systemPrompt}\n\n${userContent}` }] }],
        config: { maxOutputTokens: maxTokens },
      });
      return result.text || "";
    }
    case "xai": {
      const client = getXAIClient();
      const completion = await client.chat.completions.create({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        max_tokens: maxTokens,
      });
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

async function computeVerificationSummary(
  query: string,
  completedStages: CompletedStage[],
  totalStages: number,
  liveResearchUsed: boolean = false
): Promise<VerificationSummary> {
  if (completedStages.length < 2) {
    return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
  }

  // Pick cheapest available model for analysis
  const candidates: { provider: string; model: string; envKey: string }[] = [
    { provider: "gemini", model: "gemini-2.5-flash", envKey: "AI_INTEGRATIONS_GEMINI_API_KEY" },
    { provider: "xai", model: "grok-3-fast", envKey: "XAI_API_KEY" },
    { provider: "anthropic", model: "claude-haiku-4-5", envKey: "AI_INTEGRATIONS_ANTHROPIC_API_KEY" },
  ];

  const chosen = candidates.find((c) => process.env[c.envKey]);
  if (!chosen) {
    return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
  }

  // Build model names list so the analysis LLM can reference them by name
  const modelNames = completedStages.map((s) => `${providerShortName(s.model.provider)} (${s.model.model})`).join(", ");
  const liveResearchNote = liveResearchUsed ? " Live web research (Tavily) was used to ground Stage 1." : "";

  let stageOutputsText = "";
  for (const stage of completedStages) {
    stageOutputsText += `── Stage ${stage.stage} (${stage.model.provider} / ${stage.model.model}) ──\n`;
    stageOutputsText += stage.content;
    stageOutputsText += "\n\n";
  }

  const systemPrompt = `You are an expert verification analyst. You will receive a query and multiple LLM outputs from a multi-stage verification pipeline. The models used were: ${modelNames}.${liveResearchNote}

Analyze consistency, hallucination risk, and contradictions. Then write 3-4 concise analyst-style bullet points that:
- Reference the actual query topic (e.g. "Nuclear fusion claims…", not "the query")
- Name specific models by their short name (Claude, Gemini, Grok) when describing agreement or disagreement
- Mention live web research grounding if it was used
- Justify the confidence level based on what the models actually said

Respond with ONLY valid JSON (no markdown, no code fences):
{
  "consistencySummary": "Brief description of consistency across models",
  "hallucinationRisk": "Low/Medium/High with brief explanation",
  "confidenceLevel": "High/Moderate/Low",
  "confidenceScore": 0.85,
  "contradictions": [
    {
      "topic": "Specific topic of disagreement",
      "stageA": 1,
      "stageB": 2,
      "description": "Brief description of the contradiction"
    }
  ],
  "analysisBullets": [
    "First expert verdict bullet — topic-specific, referencing models by name",
    "Second bullet — about consensus, corrections, or disagreements found",
    "Third bullet — confidence justification tied to the query content",
    "Optional fourth bullet — live research note or additional insight"
  ]
}

Rules:
- analysisBullets must have 3-4 items, each under 120 characters
- Each bullet must feel unique to THIS specific query, never generic
- If there are no contradictions, return an empty array
- confidenceScore: 0.0 to 1.0`;

  const userContent = `Original Query: ${query}\n\n${stageOutputsText}`;

  try {
    const responseText = await callLLM(chosen.provider, chosen.model, systemPrompt, userContent, 1024);

    let parsed: any;
    try {
      parsed = JSON.parse(responseText);
    } catch {
      // Strip markdown fences and retry
      const cleaned = responseText
        .replace(/```json\s*/g, "")
        .replace(/```\s*/g, "")
        .trim();
      parsed = JSON.parse(cleaned);
    }

    const contradictions = (parsed.contradictions || []).map((c: any) => ({
      topic: c.topic || "",
      stageA: c.stageA || 0,
      stageB: c.stageB || 0,
      description: c.description || "",
    }));

    const confidenceScore = typeof parsed.confidenceScore === "number"
      ? Math.max(0, Math.min(1, parsed.confidenceScore))
      : undefined;

    const confidenceText = confidenceScore !== undefined
      ? `${parsed.confidenceLevel || "Unknown"} (${Math.round(confidenceScore * 100)}%)`
      : parsed.confidenceLevel || "Unknown";

    // Extract analysisBullets from the LLM response, falling back to metadata-based bullets
    const analysisBullets = Array.isArray(parsed.analysisBullets) && parsed.analysisBullets.length > 0
      ? parsed.analysisBullets.map((b: any) => String(b))
      : buildFallbackBullets(query, completedStages, totalStages, liveResearchUsed);

    return {
      consistency: parsed.consistencySummary || `Cross-verified across ${completedStages.length} LLMs`,
      hallucinations: parsed.hallucinationRisk || "Checked at each stage",
      confidence: confidenceText,
      contradictions,
      confidenceScore,
      isAnalyzed: true,
      analysisBullets,
    };
  } catch (error) {
    console.error("Analysis failed:", error);
    return fallbackSummary(query, completedStages, totalStages, liveResearchUsed);
  }
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
      });
      const parsed = extendedSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: "Invalid request", details: parsed.error.errors });
      }

      const { query, chain, adversarialMode, liveResearch } = parsed.data;

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
              maxResults: 5,
              searchDepth: "basic",
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

        const webGroundingNote = hasWebResearch
          ? "\n\nNote: The first stage was provided with live web search results. Information about current events and recent developments in the previous response is grounded in real-time web data — treat it as sourced information, not speculation. Do not dismiss it as beyond your knowledge cutoff."
          : "";

        if (isLast) {
          return `You are the final stage of a multi-LLM verification pipeline. You produce the definitive, verified response.

Your tasks:
1. Final verification of all claims
2. Synthesize all previous stages into a clear, concise final answer
3. Remove any redundancy
4. Ensure the response is well-structured and easy to understand
5. Note any remaining caveats or areas of genuine uncertainty

Produce the final verified response that best answers the user's original query.${webGroundingNote}

${lengthConfig.finalInstruction}`;
        }

        // Middle stage — adversarial or standard
        if (adversarialMode) {
          return `You are in ADVERSARIAL MODE. You are stage ${stageNum} of a multi-LLM verification pipeline. Your job is to find flaws.

Your tasks:
1. Actively search for errors and weak claims in the previous response
2. Challenge every assumption — demand evidence
3. Identify hallucinations and fabricated details
4. Cross-check facts rigorously against your knowledge
5. Flag misleading, vague, or unsubstantiated information
6. Provide a corrected and hardened version of the response

Be aggressive in your analysis. Do not give the benefit of the doubt.${webGroundingNote}

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

Provide a refined and verified version of the response.${webGroundingNote}

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

        // Inject live web search context into the first stage so all subsequent
        // stages benefit from grounded information flowing through the pipeline
        const userContent = isFirst
          ? searchContext
            ? `Original Query: ${query}\n\n── Live Web Research ──\n${searchContext}`
            : `Original Query: ${query}`
          : `Original Query: ${query}\n\nPrevious Response:\n${previousOutput}`;

        try {
          previousOutput = await runStage(chain[i], prompt, userContent, res, stageNum, lengthConfig.maxTokens);
          completedStages.push({ stage: stageNum, model: chain[i], content: previousOutput });
          console.log(`Stage ${stageNum} completed successfully`);
        } catch (stageError) {
          console.error(`Stage ${stageNum} failed:`, stageError);
          throw stageError;
        }
      }

      const summary = await computeVerificationSummary(query, completedStages, totalStages, liveResearch);

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
