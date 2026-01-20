import { type StageOutput, type VerificationSummary as VerificationSummaryType } from "@shared/schema";
import { StageBlock } from "./stage-block";
import { VerificationSummary } from "./verification-summary";
import { Download } from "lucide-react";

interface TerminalOutputProps {
  query: string;
  stages: StageOutput[];
  summary: VerificationSummaryType | null;
  isProcessing: boolean;
  expectedStageCount: number;
}

function exportToCSV(query: string, stages: StageOutput[]) {
  const escapeCSV = (str: string) => {
    if (str.includes(",") || str.includes('"') || str.includes("\n")) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const headers = ["Stage", "Provider", "Model", "Content"];
  const rows = stages.map((stage) => [
    stage.stage.toString(),
    stage.model.provider,
    stage.model.model,
    escapeCSV(stage.content),
  ]);

  const csvContent = [
    `Query,${escapeCSV(query)}`,
    "",
    headers.join(","),
    ...rows.map((row) => row.join(",")),
  ].join("\n");

  const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = `verification-${Date.now()}.csv`;
  link.click();
  URL.revokeObjectURL(link.href);
}

function exportToPDF(query: string, stages: StageOutput[]) {
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Verification Results</title>
      <style>
        body { font-family: 'Courier New', monospace; padding: 40px; max-width: 800px; margin: 0 auto; }
        h1 { font-size: 18px; border-bottom: 2px solid #000; padding-bottom: 10px; }
        .query { background: #f5f5f5; padding: 15px; margin: 20px 0; }
        .stage { margin: 25px 0; padding: 15px; border-left: 3px solid #333; }
        .stage-header { font-weight: bold; margin-bottom: 10px; }
        .stage-content { white-space: pre-wrap; line-height: 1.6; }
        .verified { margin-top: 30px; padding: 20px; border: 2px solid #000; }
        @media print { body { padding: 20px; } }
      </style>
    </head>
    <body>
      <h1>MULTI-LLM VERIFICATION RESULTS</h1>
      <div class="query"><strong>QUERY:</strong> ${query}</div>
      ${stages.map((stage) => `
        <div class="stage">
          <div class="stage-header">STAGE ${stage.stage}: ${stage.model.provider.toUpperCase()} / ${stage.model.model}</div>
          <div class="stage-content">${stage.content}</div>
        </div>
      `).join("")}
      ${stages.length > 0 ? `
        <div class="verified">
          <strong>VERIFIED OUTPUT</strong>
          <div class="stage-content" style="margin-top: 10px;">${stages[stages.length - 1].content}</div>
        </div>
      ` : ""}
    </body>
    </html>
  `;

  const printWindow = window.open("", "_blank");
  if (printWindow) {
    printWindow.document.write(htmlContent);
    printWindow.document.close();
    printWindow.print();
  }
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
          <div className="text-sm opacity-60 text-[#000000]">ROSIN - PURE OUTPUT</div>
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

      {allComplete && stages.length > 0 && (
        <div className="flex items-center gap-3 mt-6 pt-4 border-t border-border" data-testid="export-buttons">
          <span className="text-xs text-muted-foreground opacity-60">EXPORT:</span>
          <button
            onClick={() => exportToCSV(query, stages)}
            className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 border border-border rounded-none"
            data-testid="button-export-csv"
          >
            <Download className="w-3 h-3" />
            [CSV]
          </button>
          <button
            onClick={() => exportToPDF(query, stages)}
            className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 border border-border rounded-none"
            data-testid="button-export-pdf"
          >
            <Download className="w-3 h-3" />
            [PDF]
          </button>
        </div>
      )}
    </div>
  );
}
