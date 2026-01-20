import { type StageOutput, type VerificationSummary as VerificationSummaryType } from "@shared/schema";
import { StageBlock } from "./stage-block";
import { VerificationSummary } from "./verification-summary";

interface TerminalOutputProps {
  query: string;
  stages: StageOutput[];
  summary: VerificationSummaryType | null;
  isProcessing: boolean;
  expectedStageCount: number;
}

export function TerminalOutput({
  query,
  stages,
  summary,
  isProcessing,
  expectedStageCount,
}: TerminalOutputProps) {
  if (stages.length === 0 && !isProcessing) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
        <div className="text-center space-y-4">
          <div className="text-sm opacity-60">ROSIN - PURE OUTPUT</div>
          <div className="text-xs opacity-40 max-w-md">
            Enter a query below. It will pass through multiple LLMs in sequence.
            Each model verifies and refines the previous output to distill truth
            and detect hallucinations.
          </div>
          <div className="text-xs opacity-30 pt-4">
            <span className="opacity-60">$ </span>
            <span className="animate-pulse">_</span>
          </div>
        </div>
      </div>
    );
  }

  const allComplete = stages.length === expectedStageCount && stages.every((s) => s.status === "complete");
  const lastStage = allComplete ? stages[stages.length - 1] : null;

  return (
    <div className="space-y-6" data-testid="stages-container">
      {query && stages.length > 0 && (
        <div className="text-sm text-muted-foreground mb-4">
          <span className="opacity-60">QUERY: </span>
          <span className="text-foreground">{query}</span>
        </div>
      )}

      {stages.map((stage) => (
        <StageBlock key={stage.stage} stage={stage} />
      ))}

      {allComplete && lastStage && (
        <div className="mt-8 space-y-2" data-testid="verified-output">
          <div className="text-xs text-muted-foreground">
            {"=".repeat(50)}
          </div>
          <div className="text-sm font-medium text-foreground">VERIFIED OUTPUT</div>
          <div className="text-xs text-muted-foreground">
            {"=".repeat(50)}
          </div>
          <div className="text-sm whitespace-pre-wrap leading-relaxed py-2">
            {lastStage.content}
          </div>
          <div className="text-xs text-muted-foreground">
            {"=".repeat(50)}
          </div>
        </div>
      )}

      {summary && allComplete && (
        <VerificationSummary summary={summary} />
      )}
    </div>
  );
}
