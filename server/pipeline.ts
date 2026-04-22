import type { Response } from "express";
import { randomUUID } from "crypto";
import type { LLMModel } from "@shared/schema";
import { computeTrustScore } from "./trust-score";
import { storage } from "./storage";
import {
  sendSSE,
  classifyComplexity,
  exaSearch,
  verifyURLs,
  formatSearchContext,
  runStage,
  runJudge,
  shouldTriggerTieBreaker,
  pickTieBreakerModel,
  getTavilyClient,
} from "./routes";

// Re-export CompletedStage shape used internally by the pipeline
interface CompletedStage {
  stage: number;
  model: LLMModel;
  content: string;
}

/** Map provider ID to short display name for tie-breaker user content */
function providerShortName(provider: string): string {
  switch (provider) {
    case "anthropic": return "Claude";
    case "gemini": return "Gemini";
    case "xai": return "Grok";
    default: return provider;
  }
}

export interface PipelineOptions {
  query: string;
  chain: LLMModel[];
  adversarialMode: boolean;
  liveResearch: boolean;
  autoTieBreaker: boolean;
  /** Hook fired after the summary is computed but before the `done` SSE event.
   *  Used by the hosted tier to record per-request usage against the account. */
  onComplete?: (meta: { verifiedSourceCount: number; brokenSourceCount: number }) => Promise<void> | void;
}

export async function runVerificationPipeline(options: PipelineOptions, res: Response): Promise<void> {
  const { query, chain, adversarialMode, liveResearch, autoTieBreaker, onComplete } = options;

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

  // Live Research: search → verify URLs → format with credibility + verification status
  let searchContext = "";
  let verifiedSourceCount = 0;
  let brokenSourceCount = 0;
  if (liveResearch) {
    sendSSE(res, { type: "research_start" });
    let rawResults: { title: string; url: string; content: string }[] | null = null;

    // Step 1: Search — prefer Exa, fall back to Tavily
    if (process.env.EXA_API_KEY) {
      try {
        console.log("[Research] Using Exa.ai for web search");
        rawResults = await exaSearch(query);
      } catch (exaError) {
        console.error("[Research] Exa failed, falling back to Tavily:", exaError);
      }
    }
    if (!rawResults) {
      const client = getTavilyClient();
      if (client) {
        try {
          console.log("[Research] Using Tavily for web search");
          const searchResponse = await client.search(query, {
            maxResults: 8,
            searchDepth: "advanced",
            includeAnswer: true,
          });
          rawResults = searchResponse.results.map((r) => ({
            title: r.title, url: r.url, content: r.content,
          }));
        } catch (searchError) {
          console.error("[Research] Tavily also failed:", searchError);
        }
      }
    }

    if (rawResults && rawResults.length > 0) {
      // Step 2: Verify URLs — HEAD request each to confirm pages exist
      const verified = await verifyURLs(rawResults);
      verifiedSourceCount = verified.filter((r) => r.urlStatus.startsWith("VERIFIED")).length;
      brokenSourceCount = verified.filter((r) => r.urlStatus.startsWith("BROKEN")).length;
      searchContext = formatSearchContext(verified);
      const sourceSummary = verified
        .map((r, i) => {
          const tag = r.urlStatus.startsWith("VERIFIED") ? "✓" : (r.urlStatus.startsWith("BROKEN") ? "✗" : "?");
          return `  [${i + 1}] [${tag}] ${r.title} — ${r.url}`;
        })
        .join("\n");
      sendSSE(res, {
        type: "research_complete",
        sourceCount: verified.length,
        sources: sourceSummary,
        verifiedSources: verified.map((r) => ({
          title: r.title,
          url: r.url,
          urlStatus: r.urlStatus,
        })),
      });
    } else if (!process.env.EXA_API_KEY && !process.env.TAVILY_API_KEY) {
      sendSSE(res, { type: "research_error", error: "No search API key configured (EXA_API_KEY or TAVILY_API_KEY)" });
    } else {
      sendSSE(res, { type: "research_error", error: "Web search failed — proceeding without live data" });
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

    // Every stage gets the search results so each model can independently
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

    const tbModel = pickTieBreakerModel();
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
  summary.trustScore = computeTrustScore({
    judgeVerdict: summary.judgeVerdict,
    verifiedSources: verifiedSourceCount,
    brokenSources: brokenSourceCount,
  }) ?? undefined;

  sendSSE(res, { type: "summary", summary });
  if (onComplete) await onComplete({ verifiedSourceCount, brokenSourceCount });
  sendSSE(res, { type: "done" });
  res.end();
}
