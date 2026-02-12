interface VerificationSummaryProps {
  summary: {
    consistency: string;
    hallucinations: string;
    confidence: string;
  };
}

export function VerificationSummary({ summary }: VerificationSummaryProps) {
  return (
    <div className="mt-10 pt-6 border-t-2 border-primary/30 space-y-3" data-testid="verification-summary">
      <div className="text-sm font-medium text-primary">VERIFICATION SUMMARY</div>

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
      </div>
    </div>
  );
}
