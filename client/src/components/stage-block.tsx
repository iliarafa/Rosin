import { useState } from "react";
import { type StageOutput } from "@shared/schema";

interface StageBlockProps {
  stage: StageOutput;
}

const providerLabels: Record<string, string> = {
  openai: "OpenAI",
  anthropic: "Anthropic",
  gemini: "Gemini",
};

function StatusIcon({ status }: { status: StageOutput["status"] }) {
  switch (status) {
    case "pending":
      return <span className="text-muted-foreground opacity-40" aria-label="Pending">[...]</span>;
    case "streaming":
      return <span className="text-muted-foreground animate-pulse" aria-label="Processing">[RUN]</span>;
    case "complete":
      return <span className="text-foreground" aria-label="Complete">[OK]</span>;
    case "error":
      return <span className="text-destructive" aria-label="Error">[ERR]</span>;
  }
}

/** Color for an agreement score badge (0–100) */
function scoreColor(score: number): string {
  if (score >= 80) return "text-green-500 border-green-500/40";
  if (score >= 50) return "text-yellow-500 border-yellow-500/40";
  return "text-red-500 border-red-500/40";
}

/** Severity badge color for hallucination flags */
function severityColor(severity: string): string {
  if (severity === "high") return "text-red-500";
  if (severity === "medium") return "text-yellow-500";
  return "text-muted-foreground";
}

export function StageBlock({ stage }: StageBlockProps) {
  const providerName = providerLabels[stage.model.provider] || stage.model.provider;
  const isActive = stage.status === "streaming";
  const [showDetails, setShowDetails] = useState(false);
  const analysis = stage.analysis;

  return (
    <div
      className={`space-y-3 ${isActive ? "bg-muted/30" : ""} p-4 sm:p-5 border-b border-border/50 transition-colors`}
      data-testid={`stage-block-${stage.stage}`}
    >
      <div className="flex items-center gap-2 text-sm">
        <span className="text-muted-foreground">{">"}</span>
        <span className="font-medium">STAGE [{stage.stage}]:</span>
        <span className="text-muted-foreground">
          {providerName} / {stage.model.model}
        </span>
        <StatusIcon status={stage.status} />

        {/* Agreement score badge — shown after Judge analysis is available */}
        {analysis && (
          <span
            className={`ml-auto text-xs border px-1.5 py-0.5 rounded-none tabular-nums ${scoreColor(analysis.agreementScore)}`}
            title={`Agreement score: ${analysis.agreementScore}/100`}
          >
            {analysis.agreementScore}
          </span>
        )}
      </div>

      <div className="text-sm whitespace-pre-wrap leading-relaxed pt-1">
        {stage.content}
        {stage.status === "streaming" && (
          <span className="text-muted-foreground animate-pulse">_</span>
        )}
      </div>

      {stage.error && (
        <div className="text-sm text-destructive mt-2">
          ERROR: {stage.error}
        </div>
      )}

      {/* Expandable Judge analysis details (claims + hallucination flags) */}
      {analysis && (analysis.hallucinationFlags.length > 0 || analysis.claims.length > 0) && (
        <div className="pt-1">
          <button
            onClick={() => setShowDetails(!showDetails)}
            className="text-xs text-muted-foreground hover:text-foreground transition-colors"
          >
            {showDetails ? "[-] Hide analysis" : `[+] ${analysis.claims.length} claims, ${analysis.hallucinationFlags.length} flags`}
          </button>

          {showDetails && (
            <div className="mt-2 space-y-2 text-xs border-l-2 border-border pl-3">
              {/* Key claims with confidence */}
              {analysis.claims.length > 0 && (
                <div className="space-y-1">
                  {analysis.claims.map((c, i) => (
                    <div key={i} className="flex items-start gap-2">
                      <span className={`shrink-0 tabular-nums ${c.confidence >= 80 ? "text-green-500" : c.confidence >= 50 ? "text-yellow-500" : "text-red-500"}`}>
                        [{c.confidence}]
                      </span>
                      <span className="text-muted-foreground">{c.text}</span>
                    </div>
                  ))}
                </div>
              )}

              {/* Hallucination flags */}
              {analysis.hallucinationFlags.length > 0 && (
                <div className="space-y-1 pt-1">
                  <span className="text-destructive/80 font-medium">FLAGGED:</span>
                  {analysis.hallucinationFlags.map((f, i) => (
                    <div key={i} className="flex items-start gap-2">
                      <span className={`shrink-0 ${severityColor(f.severity)}`}>
                        [{f.severity.toUpperCase()}]
                      </span>
                      <span className="text-muted-foreground">{f.claim} — {f.reason}</span>
                    </div>
                  ))}
                </div>
              )}

              {/* Corrections */}
              {analysis.corrections.length > 0 && (
                <div className="space-y-1 pt-1">
                  <span className="text-primary/80 font-medium">CORRECTIONS:</span>
                  {analysis.corrections.map((c, i) => (
                    <div key={i} className="text-muted-foreground">• {c}</div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
