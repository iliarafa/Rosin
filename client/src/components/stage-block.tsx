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

export function StageBlock({ stage }: StageBlockProps) {
  const providerName = providerLabels[stage.model.provider] || stage.model.provider;
  const isActive = stage.status === "streaming";

  return (
    <div
      className={`space-y-2 ${isActive ? "bg-muted/30" : ""} p-3 -mx-3 transition-colors`}
      data-testid={`stage-block-${stage.stage}`}
    >
      <div className="flex items-center gap-2 text-sm">
        <span className="text-muted-foreground">{">"}</span>
        <span className="font-medium">STAGE [{stage.stage}]:</span>
        <span className="text-muted-foreground">
          {providerName} / {stage.model.model}
        </span>
        <StatusIcon status={stage.status} />
      </div>

      <div className="text-xs text-muted-foreground opacity-60">
        {"─".repeat(50)}
      </div>

      <div className="text-sm whitespace-pre-wrap leading-relaxed">
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

      <div className="text-xs text-muted-foreground opacity-60 pt-2">
        {"─".repeat(50)}
      </div>
    </div>
  );
}
