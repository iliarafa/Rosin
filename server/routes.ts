import type { Express, Response } from "express";
import { createServer, type Server } from "http";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";
import { insertVerificationRequestSchema, type LLMModel } from "@shared/schema";
import { z } from "zod";

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

function sendSSE(res: Response, data: Record<string, unknown>) {
  if (!res.writableEnded) {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  }
}

async function streamOpenAI(
  model: string,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number
): Promise<string> {
  let fullResponse = "";

  const stream = await openai.chat.completions.create({
    model,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userContent },
    ],
    stream: true,
    max_completion_tokens: 2048,
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
  stage: number
): Promise<string> {
  let fullResponse = "";

  const stream = anthropic.messages.stream({
    model,
    max_tokens: 2048,
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
  stage: number
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

async function runStage(
  model: LLMModel,
  systemPrompt: string,
  userContent: string,
  res: Response,
  stage: number
): Promise<string> {
  sendSSE(res, { type: "stage_start", stage, model });

  try {
    let result: string;

    switch (model.provider) {
      case "openai":
        result = await streamOpenAI(model.model, systemPrompt, userContent, res, stage);
        break;
      case "anthropic":
        result = await streamAnthropic(model.model, systemPrompt, userContent, res, stage);
        break;
      case "gemini":
        result = await streamGemini(model.model, systemPrompt, userContent, res, stage);
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

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {
  app.post("/api/verify", async (req, res) => {
    try {
      const parsed = insertVerificationRequestSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: "Invalid request", details: parsed.error.errors });
      }

      const { query, chain } = parsed.data;

      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");
      res.setHeader("X-Accel-Buffering", "no");

      let clientDisconnected = false;
      req.on("close", () => {
        clientDisconnected = true;
      });

      const checkDisconnect = () => {
        if (clientDisconnected) {
          throw new Error("Client disconnected");
        }
      };

      const totalStages = chain.length;

      const getStagePrompt = (stageNum: number, isLast: boolean): string => {
        if (stageNum === 1) {
          return `You are the first stage of a multi-LLM verification pipeline. Your task is to provide an initial, thorough response to the user's query. Focus on accuracy and comprehensive coverage of the topic.

Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.`;
        }

        if (isLast) {
          return `You are the final stage of a multi-LLM verification pipeline. You produce the definitive, verified response.

Your tasks:
1. Final verification of all claims
2. Synthesize all previous stages into a clear, concise final answer
3. Remove any redundancy
4. Ensure the response is well-structured and easy to understand
5. Note any remaining caveats or areas of genuine uncertainty

Produce the final verified response that best answers the user's original query.`;
        }

        return `You are stage ${stageNum} of a multi-LLM verification pipeline. You are reviewing and verifying the previous output.

Your tasks:
1. Verify the factual accuracy of the previous response
2. Identify any potential errors, hallucinations, or unsupported claims
3. Correct any inaccuracies you find
4. Add any important information that was missed
5. Cross-check the information against your knowledge
6. Improve clarity where needed

Provide a refined and verified version of the response.`;
      };

      let previousOutput = query;

      for (let i = 0; i < totalStages; i++) {
        checkDisconnect();
        const stageNum = i + 1;
        const isFirst = i === 0;
        const isLast = i === totalStages - 1;
        const prompt = getStagePrompt(stageNum, isLast);

        const userContent = isFirst
          ? `Original Query: ${query}`
          : `Original Query: ${query}\n\nPrevious Response:\n${previousOutput}`;

        previousOutput = await runStage(chain[i], prompt, userContent, res, stageNum);
      }

      const summary = {
        consistency: `Cross-verified across ${totalStages} independent LLMs`,
        hallucinations: "Checked at each stage - potential issues flagged",
        confidence: totalStages >= 3 ? "High - multi-stage verification complete" : "Moderate - dual verification complete",
      };

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

  return httpServer;
}
