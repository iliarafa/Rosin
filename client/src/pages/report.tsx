import { useQuery } from "@tanstack/react-query";
import { useParams, Link } from "wouter";
import { type VerificationRun } from "@shared/schema";
import { ContradictionsView } from "@/components/contradictions-view";
import { VerificationSummary } from "@/components/verification-summary";

function getConfidenceBorderColor(score?: number): string {
  if (score === undefined) return "border-foreground/20";
  if (score >= 0.8) return "border-green-500";
  if (score >= 0.5) return "border-yellow-500";
  return "border-red-500";
}

export default function ReportPage() {
  const params = useParams<{ id: string }>();

  const { data: run, isLoading, error } = useQuery<VerificationRun>({
    queryKey: ["/api/report", params.id],
    queryFn: async () => {
      const res = await fetch(`/api/report/${params.id}`);
      if (!res.ok) throw new Error("Report not found");
      return res.json();
    },
    enabled: !!params.id,
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen bg-background text-foreground font-mono">
        <div className="text-sm text-muted-foreground animate-pulse">[...] Loading report</div>
      </div>
    );
  }

  if (error || !run) {
    return (
      <div className="flex flex-col items-center justify-center h-screen bg-background text-foreground font-mono gap-4">
        <div className="text-sm text-destructive">[ERR] Report not found</div>
        <Link
          href="/terminal"
          className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
        >
          [TERMINAL]
        </Link>
      </div>
    );
  }

  const lastStage = run.stages[run.stages.length - 1];

  return (
    <div className="flex flex-col min-h-screen bg-background text-foreground font-mono">
      <header className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex items-center justify-between max-w-4xl mx-auto">
          <div className="text-sm font-medium">VERIFICATION REPORT</div>
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

      <main className="flex-1 px-4 py-6 sm:px-8 sm:py-8">
        <div className="max-w-4xl mx-auto space-y-8">
          {/* Query and metadata */}
          <div className="space-y-2">
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

          {/* Contradictions */}
          {run.summary?.contradictions && run.summary.contradictions.length > 0 && (
            <ContradictionsView contradictions={run.summary.contradictions} />
          )}

          {/* Verified output */}
          {lastStage && (
            <div
              className={`pt-6 border-t-2 ${getConfidenceBorderColor(run.summary?.confidenceScore)} space-y-3 border-l-4 pl-4`}
            >
              <div className="text-sm font-medium text-foreground">VERIFIED OUTPUT</div>
              <div className="text-sm whitespace-pre-wrap leading-relaxed py-3">
                {lastStage.content}
              </div>
            </div>
          )}

          {/* Stages (collapsed) */}
          <details className="border border-border">
            <summary className="px-4 py-3 text-xs text-muted-foreground cursor-pointer hover:text-foreground transition-colors">
              STAGE OUTPUTS ({run.stages.length})
            </summary>
            <div className="border-t border-border divide-y divide-border">
              {run.stages.map((stage) => (
                <div key={stage.stage} className="px-4 py-4">
                  <div className="text-xs text-muted-foreground mb-2">
                    STAGE {stage.stage}: {stage.model.provider.toUpperCase()} / {stage.model.model}
                  </div>
                  <div className="text-sm whitespace-pre-wrap leading-relaxed">
                    {stage.content}
                  </div>
                </div>
              ))}
            </div>
          </details>

          {/* Summary */}
          {run.summary && <VerificationSummary summary={run.summary} />}

          {/* Footer */}
          <div className="text-xs text-muted-foreground opacity-40 text-center pt-8 pb-4 border-t border-border">
            Generated by Rosin
          </div>
        </div>
      </main>
    </div>
  );
}
