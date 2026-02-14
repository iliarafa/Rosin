import { type VerificationSummary as VerificationSummaryType } from "@shared/schema";

interface VerificationSummaryProps {
  summary: VerificationSummaryType;
}

function getConfidenceBarColor(score?: number): string {
  if (score === undefined) return "bg-muted-foreground";
  if (score >= 0.8) return "bg-green-500";
  if (score >= 0.5) return "bg-yellow-500";
  return "bg-red-500";
}

export function VerificationSummary({ summary }: VerificationSummaryProps) {
  return (
    <div className="mt-10 pt-6 border-t-2 border-primary/30 space-y-3" data-testid="verification-summary">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium text-primary">VERIFICATION SUMMARY</span>
        {summary.isAnalyzed && (
          <span className="text-xs text-primary opacity-70">[ANALYZED]</span>
        )}
      </div>

      <div className="space-y-3 text-sm py-3">
        <div className="flex gap-2">
          <span className="text-muted-foreground">Consistency:</span>
          <span className="text-foreground">{summary.consistency}</span>
        </div>
        <div className="flex gap-2">
          <span className="text-muted-foreground">Hallucinations:</span>
          <span className="text-foreground">{summary.hallucinations}</span>
        </div>
        <div className="flex gap-2">
          <span className="text-muted-foreground">Confidence:</span>
          <span className="text-foreground">{summary.confidence}</span>
        </div>

        {summary.confidenceScore !== undefined && (
          <div className="mt-1">
            <div className="h-1.5 bg-muted rounded-sm overflow-hidden">
              <div
                className={`h-full ${getConfidenceBarColor(summary.confidenceScore)} transition-all duration-500`}
                style={{ width: `${Math.round(summary.confidenceScore * 100)}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {summary.contradictions && summary.contradictions.length > 0 && (
        <div className="space-y-2 pt-2">
          <div className="text-xs font-medium text-destructive">
            DISAGREEMENTS ({summary.contradictions.length})
          </div>
          {summary.contradictions.map((c, i) => (
            <div key={i} className="text-xs space-y-0.5">
              <span className="text-destructive/80">{c.topic}</span>
              <span className="text-muted-foreground ml-1">
                (Stage {c.stageA} vs {c.stageB})
              </span>
              <div className="text-muted-foreground">{c.description}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
