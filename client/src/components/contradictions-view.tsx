import { type Contradiction } from "@shared/schema";

interface ContradictionsViewProps {
  contradictions: Contradiction[];
}

export function ContradictionsView({ contradictions }: ContradictionsViewProps) {
  if (contradictions.length === 0) return null;

  return (
    <div
      className="mt-10 pt-6 border-t-2 border-destructive/30 space-y-3"
      data-testid="contradictions-view"
    >
      <div className="text-sm font-medium text-destructive">
        DISAGREEMENTS DETECTED ({contradictions.length})
      </div>

      <div className="space-y-4 py-3">
        {contradictions.map((c, i) => (
          <div key={i} className="space-y-1">
            <div className="text-sm">
              <span className="font-medium text-destructive/80">{c.topic}</span>
              <span className="text-muted-foreground ml-2 text-xs">
                Stage {c.stageA} vs Stage {c.stageB}
              </span>
            </div>
            <div className="text-xs text-muted-foreground leading-relaxed">
              {c.description}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
