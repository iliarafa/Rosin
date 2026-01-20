import { type StageOutput, type VerificationSummary as VerificationSummaryType } from "@shared/schema";
import { StageBlock } from "./stage-block";
import { VerificationSummary } from "./verification-summary";

interface TerminalOutputProps {
  query: string;
  stages: StageOutput[];
  summary: VerificationSummaryType | null;
  isProcessing: boolean;
}

export function TerminalOutput({
  query,
  stages,
  summary,
  isProcessing,
}: TerminalOutputProps) {
  if (stages.length === 0 && !isProcessing) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
        <div className="text-center space-y-4">
          <div className="text-sm opacity-60">MULTI-LLM VERIFICATION SYSTEM</div>
          <div className="text-xs opacity-40 max-w-md">
            Enter a query below. It will pass through 4 LLMs in sequence.
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

  const stage4Complete = stages.find((s) => s.stage === 4 && s.status === "complete");
  const allComplete = stages.length === 4 && stages.every((s) => s.status === "complete");

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

      {allComplete && stage4Complete && (
        <div className="mt-8 space-y-2" data-testid="verified-output">
          <div className="text-xs text-muted-foreground">
            {"=".repeat(50)}
          </div>
          <div className="text-sm font-medium text-foreground">VERIFIED OUTPUT</div>
          <div className="text-xs text-muted-foreground">
            {"=".repeat(50)}
          </div>
          <div className="text-sm whitespace-pre-wrap leading-relaxed py-2">
            {stage4Complete.content}
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
