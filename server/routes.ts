import type { Express, Response } from "express";
import { createServer, type Server } from "http";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";
import { insertVerificationRequestSchema, type LLMModel, type VerificationSummary } from "@shared/schema";
import { z } from "zod";
import { storage } from "./storage";
import { randomUUID } from "crypto";

const openai = new OpenAI({
  apiKey: process.env.AI_INTEGRATIONS_OPENAI_API_KEY,
  baseURL: process.env.AI_INTEGRATIONS_OPENAI_BASE_URL,
});

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

async function streamOpenAI(
  model: string,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number,
  maxTokens: number
): Promise<string> {
  let fullResponse = "";

  const stream = await openai.chat.completions.create({
    model,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userContent },
    ],
    stream: true,
    max_completion_tokens: maxTokens,
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
      case "openai":
        result = await streamOpenAI(model.model, systemPrompt, userContent, res, stage, maxTokens);
        break;
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
    case "openai": {
      const completion = await openai.chat.completions.create({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        max_completion_tokens: maxTokens,
      });
      return completion.choices[0]?.message?.content || "";
    }
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

function fallbackSummary(completed: number, total: number): VerificationSummary {
  const skipped = total - completed;
  const consistency = completed < 2
    ? "Insufficient stages for cross-verification"
    : skipped > 0
      ? `Cross-verified across ${completed} of ${total} LLMs (${skipped} skipped)`
      : `Cross-verified across ${completed} independent LLMs`;

  const confidence = completed >= 3
    ? "High \u2013 multi-stage verification complete"
    : completed === 2
      ? "Moderate \u2013 dual verification complete"
      : "Low \u2013 single-stage only";

  const hallucinations = skipped > 0
    ? `Checked at ${completed} of ${total} stages \u2013 coverage reduced`
    : "Checked at each stage \u2013 potential issues flagged";

  return { consistency, hallucinations, confidence, contradictions: [], isAnalyzed: false };
}

async function computeVerificationSummary(
  query: string,
  completedStages: CompletedStage[],
  totalStages: number
): Promise<VerificationSummary> {
  if (completedStages.length < 2) {
    return fallbackSummary(completedStages.length, totalStages);
  }

  // Pick cheapest available model for analysis
  const candidates: { provider: string; model: string; envKey: string }[] = [
    { provider: "gemini", model: "gemini-2.5-flash", envKey: "AI_INTEGRATIONS_GEMINI_API_KEY" },
    { provider: "xai", model: "grok-3-fast", envKey: "XAI_API_KEY" },
    { provider: "anthropic", model: "claude-haiku-4-5", envKey: "AI_INTEGRATIONS_ANTHROPIC_API_KEY" },
  ];

  const chosen = candidates.find((c) => process.env[c.envKey]);
  if (!chosen) {
    return fallbackSummary(completedStages.length, totalStages);
  }

  let stageOutputsText = "";
  for (const stage of completedStages) {
    stageOutputsText += `── Stage ${stage.stage} (${stage.model.provider} / ${stage.model.model}) ──\n`;
    stageOutputsText += stage.content;
    stageOutputsText += "\n\n";
  }

  const systemPrompt = `You are an analysis tool. You will receive a query and multiple LLM outputs for that query from different stages of a verification pipeline. Analyze them for consistency, potential hallucinations, and contradictions.

Respond with ONLY valid JSON in this exact format (no markdown, no code fences):
{
  "consistencySummary": "Brief description of how consistent the outputs are",
  "hallucinationRisk": "Low/Medium/High with brief explanation",
  "confidenceLevel": "High/Moderate/Low",
  "confidenceScore": 0.85,
  "contradictions": [
    {
      "topic": "The specific topic of disagreement",
      "stageA": 1,
      "stageB": 2,
      "description": "Brief description of the contradiction"
    }
  ]
}

If there are no contradictions, return an empty array for contradictions.
The confidenceScore should be a number between 0.0 and 1.0.`;

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

    return {
      consistency: parsed.consistencySummary || `Cross-verified across ${completedStages.length} LLMs`,
      hallucinations: parsed.hallucinationRisk || "Checked at each stage",
      confidence: confidenceText,
      contradictions,
      confidenceScore,
      isAnalyzed: true,
    };
  } catch (error) {
    console.error("Analysis failed:", error);
    return fallbackSummary(completedStages.length, totalStages);
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
      });
      const parsed = extendedSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: "Invalid request", details: parsed.error.errors });
      }

      const { query, chain, adversarialMode } = parsed.data;

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

      const getStagePrompt = (stageNum: number, isLast: boolean): string => {
        if (stageNum === 1) {
          return `You are the first stage of a multi-LLM verification pipeline. Your task is to provide an initial, thorough response to the user's query. Focus on accuracy and comprehensive coverage of the topic.

Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.

${lengthConfig.promptInstruction}`;
        }

        if (isLast) {
          return `You are the final stage of a multi-LLM verification pipeline. You produce the definitive, verified response.

Your tasks:
1. Final verification of all claims
2. Synthesize all previous stages into a clear, concise final answer
3. Remove any redundancy
4. Ensure the response is well-structured and easy to understand
5. Note any remaining caveats or areas of genuine uncertainty

Produce the final verified response that best answers the user's original query.

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

Be aggressive in your analysis. Do not give the benefit of the doubt.

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

        const userContent = isFirst
          ? `Original Query: ${query}`
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

      const summary = await computeVerificationSummary(query, completedStages, totalStages);

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
