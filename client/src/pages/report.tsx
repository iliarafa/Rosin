import { useState, useEffect } from "react";
import { useParams, Link } from "wouter";
import { type LocalHistoryItem } from "@/hooks/use-local-history";
import { StageBlock } from "@/components/stage-block";
import { VerificationSummary } from "@/components/verification-summary";
import { ContradictionsView } from "@/components/contradictions-view";
import { FinalVerifiedAnswer } from "@/components/final-verified-answer";

// ── Report / History Detail View ────────────────────────────────────
// Reads the full verification result from localStorage (100% local).
// Renders in read-only mode with all expandable sections working
// (stages with analysis, Judge verdict, provenance, scores, etc.).

const STORAGE_KEY = "rosin_local_history";

export default function ReportPage() {
  const params = useParams<{ id: string }>();
  const [run, setRun] = useState<LocalHistoryItem | null>(null);
  const [loading, setLoading] = useState(true);

  // Load the verification from localStorage by ID
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const items: LocalHistoryItem[] = JSON.parse(raw);
        const found = items.find((item) => item.id === params.id);
        if (found) {
          setRun(found);
        }
      }
    } catch {
      // Corrupted localStorage — ignore
    }
    setLoading(false);
  }, [params.id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-background text-foreground font-mono">
        <div className="text-sm text-muted-foreground animate-pulse">[...] Loading report</div>
      </div>
    );
  }

  if (!run) {
    return (
      <div className="flex flex-col items-center justify-center h-screen bg-background text-foreground font-mono gap-4">
        <div className="text-sm text-destructive">[ERR] Report not found</div>
        <div className="flex items-center gap-2">
          <Link
            href="/history"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
          >
            [HISTORY]
          </Link>
          <Link
            href="/terminal"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
          >
            [TERMINAL]
          </Link>
        </div>
      </div>
    );
  }

  const lastStage = run.stages[run.stages.length - 1];
  const allComplete = run.stages.every((s) => s.status === "complete");

  return (
    <div className="flex flex-col min-h-screen bg-background text-foreground font-mono">
      <header className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex items-center justify-between max-w-4xl mx-auto">
          <div className="flex items-center gap-3">
            <div className="text-sm font-medium">VERIFICATION REPORT</div>
            <span className="text-[10px] text-muted-foreground/40">LOCAL</span>
          </div>
          <div className="flex items-center gap-2">
            <Link
              href="/history"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            >
              [HISTORY]
            </Link>
            <Link
              href="/terminal"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            >
              [TERMINAL]
            </Link>
          </div>
        </div>
      </header>

      <main className="flex-1 px-4 py-6 sm:px-8 sm:py-8 crt-scanlines">
        <div className="max-w-4xl mx-auto space-y-0">
          {/* Query and metadata */}
          <div className="space-y-2 mb-6">
            <div className="text-sm text-muted-foreground">
              <span className="opacity-60">QUERY: </span>
              <span className="text-foreground">{run.query}</span>
            </div>
            <div className="flex items-center gap-4 text-xs text-muted-foreground">
              <span>{run.chain.map((m) => m.model).join(" → ")}</span>
              <span>{new Date(run.createdAt).toLocaleString()}</span>
              {run.adversarialMode && <span className="text-destructive">[ADVERSARIAL]</span>}
            </div>
          </div>

          {/* Full stage blocks — same rich rendering as live terminal */}
          {run.stages.map((stage) => (
            <StageBlock key={stage.stage} stage={stage} />
          ))}

          {/* Contradictions */}
          {allComplete && run.summary?.contradictions && run.summary.contradictions.length > 0 && (
            <ContradictionsView contradictions={run.summary.contradictions} />
          )}

          {/* Final verified answer */}
          {allComplete && lastStage && (
            <FinalVerifiedAnswer
              content={lastStage.content}
              confidenceScore={run.summary?.confidenceScore}
            />
          )}

          {/* Verification summary with Judge verdict */}
          {run.summary && allComplete && (
            <VerificationSummary summary={run.summary} />
          )}

          {/* Footer */}
          <div className="text-xs text-muted-foreground opacity-40 text-center pt-8 pb-4 border-t border-border">
            Stored locally on this device
          </div>
        </div>
      </main>
    </div>
  );
}
