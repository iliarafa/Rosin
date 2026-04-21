import { useState } from "react";
import { Link } from "wouter";
import { NoviceInput } from "@/components/novice/novice-input";
import { TrustScoreBanner } from "@/components/novice/trust-score-banner";
import { VerifiedAnswerCard, type VerifiedSource } from "@/components/novice/verified-answer-card";
import type { LLMModel, VerificationSummary, StageOutput } from "@shared/schema";
import { useRosinMode } from "@/hooks/use-rosin-mode";

const NOVICE_CHAIN: LLMModel[] = [
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
];

type Phase = "idle" | "verifying" | "done" | "error";

interface ResultState {
  question: string;
  answer: string;
  summary: VerificationSummary | null;
  sources: VerifiedSource[];
}

export default function NovicePage() {
  const [, setMode] = useRosinMode();
  const [phase, setPhase] = useState<Phase>("idle");
  const [statusLine, setStatusLine] = useState<string>("");
  const [result, setResult] = useState<ResultState | null>(null);
  const [showPro, setShowPro] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function runVerification(query: string) {
    setPhase("verifying");
    setResult(null);
    setError(null);
    setStatusLine("[ CONTACTING AIs... ]");

    const stages: StageOutput[] = [];
    const sources: VerifiedSource[] = [];
    let summary: VerificationSummary | null = null;

    try {
      const response = await fetch("/api/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          query,
          chain: NOVICE_CHAIN,
          adversarialMode: false,
          liveResearch: true,
          autoTieBreaker: false,
        }),
      });
      if (!response.ok || !response.body) throw new Error(`HTTP ${response.status}`);

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const event = JSON.parse(line.slice(6));
          switch (event.type) {
            case "research_start":
              setStatusLine("[ SEARCHING THE WEB... ]");
              break;
            case "research_complete":
              setStatusLine(`[ VERIFYING ... 2 AIs, ${event.sourceCount} sources ]`);
              if (Array.isArray(event.verifiedSources)) {
                for (const s of event.verifiedSources) {
                  sources.push({
                    title: s.title,
                    url: s.url,
                    status: (s.urlStatus?.split(":")[0]?.trim() ?? "UNCHECKED") as VerifiedSource["status"],
                  });
                }
              }
              break;
            case "stage_start":
              setStatusLine(`[ AI ${event.stage} THINKING... ]`);
              break;
            case "stage_content":
              stages[event.stage] = stages[event.stage] ?? { stage: event.stage, model: NOVICE_CHAIN[event.stage - 1], content: "", status: "streaming" };
              stages[event.stage].content += event.content;
              break;
            case "stage_complete":
              if (stages[event.stage]) stages[event.stage].status = "complete";
              break;
            case "summary":
              summary = event.summary;
              break;
            case "stage_error":
              throw new Error(event.error || "Stage failed");
          }
        }
      }

      const finalStage = stages.filter((s) => s && s.status === "complete").pop();
      const answer = finalStage?.content.trim() ?? "No answer produced.";

      setResult({ question: query, answer, summary, sources });
      setPhase("done");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
      setPhase("error");
    }
  }

  function reset() {
    setPhase("idle");
    setResult(null);
    setError(null);
    setStatusLine("");
    setShowPro(false);
  }

  const trustScore = result?.summary?.trustScore ?? null;
  const verifiedCount = result?.sources.filter((s) => s.status === "VERIFIED").length ?? 0;

  return (
    <div className="min-h-screen bg-black text-zinc-100 font-mono">
      <header className="flex items-center justify-between px-6 py-4">
        <div className="flex items-center gap-3 text-xs">
          <span className="text-green-500">● ROSIN</span>
          <span className="text-zinc-500 uppercase tracking-widest">[ NOVICE MODE ]</span>
        </div>
        <Link
          href="/pro"
          onClick={() => setMode("pro")}
          className="text-xs text-zinc-500 hover:text-zinc-200 uppercase tracking-widest"
          data-testid="novice-to-pro"
        >
          [ PRO → ]
        </Link>
      </header>

      <main className="px-6 pt-12 pb-20">
        {phase === "idle" && <NoviceInput onSubmit={runVerification} />}

        {phase === "verifying" && (
          <div className="text-center text-sm text-zinc-400 mt-10">
            <div className="animate-pulse">{statusLine}</div>
          </div>
        )}

        {phase === "done" && result && (
          <div className="space-y-6 max-w-2xl mx-auto">
            <TrustScoreBanner
              score={trustScore}
              aiCount={2}
              sourceCount={verifiedCount}
            />
            <VerifiedAnswerCard
              question={result.question}
              answer={result.answer}
              sources={result.sources}
              onAskAnother={reset}
              onShowVerification={() => setShowPro(true)}
            />
            {showPro && (
              <div className="text-xs text-zinc-400 border border-zinc-800 rounded p-4">
                <p>For the full per-stage scoring, claim provenance, and Judge details, switch to Pro mode.</p>
                <Link
                  href="/pro"
                  onClick={() => setMode("pro")}
                  className="text-green-500 underline underline-offset-4"
                >
                  Open in Pro →
                </Link>
              </div>
            )}
          </div>
        )}

        {phase === "error" && (
          <div className="max-w-2xl mx-auto text-center mt-10">
            <div className="border border-red-500/40 text-red-500 rounded px-4 py-3 inline-block">
              [ VERIFICATION FAILED ] {error}
            </div>
            <div className="mt-4">
              <button onClick={reset} className="text-xs text-zinc-400 underline">
                Try again
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
