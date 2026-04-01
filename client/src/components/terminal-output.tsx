import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { type StageOutput, type VerificationSummary as VerificationSummaryType, type ResearchStatus } from "@shared/schema";
import { StageBlock } from "./stage-block";
import { VerificationSummary } from "./verification-summary";
import { ContradictionsView } from "./contradictions-view";
import { FinalVerifiedAnswer } from "./final-verified-answer";
import { Download, Share2 } from "lucide-react";

/* ── Example queries shown on the idle screen ── */
const EXAMPLE_QUERIES = [
  {
    label: "SCIENCE",
    query: "Is it true that we only use 10% of our brain?",
  },
  {
    label: "HISTORY",
    query: "Did Napoleon Bonaparte actually lose the Battle of Waterloo due to bad weather?",
  },
  {
    label: "HEALTH",
    query: "Does cracking your knuckles cause arthritis?",
  },
];

/* ── Typing animation hook ── */
function useTypingAnimation(text: string, speed = 60, startDelay = 400) {
  const [displayed, setDisplayed] = useState("");
  const [done, setDone] = useState(false);

  useEffect(() => {
    let i = 0;
    let timeout: ReturnType<typeof setTimeout>;
    const startTimeout = setTimeout(() => {
      const tick = () => {
        if (i < text.length) {
          setDisplayed(text.slice(0, i + 1));
          i++;
          timeout = setTimeout(tick, speed);
        } else {
          setDone(true);
        }
      };
      tick();
    }, startDelay);
    return () => {
      clearTimeout(startTimeout);
      clearTimeout(timeout);
    };
  }, [text, speed, startDelay]);

  return { displayed, done };
}

interface TerminalOutputProps {
  query: string;
  stages: StageOutput[];
  summary: VerificationSummaryType | null;
  isProcessing: boolean;
  expectedStageCount: number;
  verificationId?: string | null;
  researchStatus?: ResearchStatus | null;
  onQuerySelect?: (query: string) => void;
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
  verificationId,
  researchStatus,
  onQuerySelect,
}: TerminalOutputProps) {
  /* ── Boot sequence state — runs once on first mount ── */
  const [booted, setBooted] = useState(false);
  const [bootLines, setBootLines] = useState<string[]>([]);

  const BOOT_MESSAGES = [
    "> ROSIN v1.0 — multi-LLM verification engine",
    "> Loading provider modules...",
    "> Anthropic ✓  Gemini ✓  xAI ✓  OpenAI ✓",
    "> Pipeline ready. Awaiting query.",
  ];

  useEffect(() => {
    if (booted) return;
    let i = 0;
    const interval = setInterval(() => {
      if (i < BOOT_MESSAGES.length) {
        setBootLines((prev) => [...prev, BOOT_MESSAGES[i]]);
        i++;
      } else {
        clearInterval(interval);
        setTimeout(() => setBooted(true), 300);
      }
    }, 280);
    return () => clearInterval(interval);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  /* ── Typing animation for the title ── */
  const { displayed: typedTitle, done: titleDone } = useTypingAnimation(
    "ROSIN — PURE OUTPUT",
    55,
    booted ? 0 : 1500
  );

  const handleExampleClick = useCallback(
    (q: string) => {
      onQuerySelect?.(q);
    },
    [onQuerySelect]
  );

  if (stages.length === 0 && !isProcessing && !researchStatus) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-muted-foreground crt-scanlines">
        {/* ── Boot sequence overlay ── */}
        <AnimatePresence>
          {!booted && (
            <motion.div
              className="absolute inset-0 flex flex-col items-start justify-center px-8 sm:px-16 z-10"
              exit={{ opacity: 0 }}
              transition={{ duration: 0.4 }}
            >
              {bootLines.map((line, i) => (
                <div
                  key={i}
                  className="boot-line text-xs text-primary/70 mb-1"
                  style={{ animationDelay: `${i * 50}ms` }}
                >
                  {line}
                </div>
              ))}
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Main idle content (visible after boot) ── */}
        <AnimatePresence>
          {booted && (
            <motion.div
              className="text-center space-y-4"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6 }}
            >
              {/* Title with typing animation + neon glow */}
              <div className="text-sm text-foreground tracking-wider">
                <span className="neon-glow">{typedTitle.split("—")[0]}</span>
                {typedTitle.includes("—") && (
                  <span className="opacity-60">— {typedTitle.split("—")[1]}</span>
                )}
                {!titleDone && <span className="terminal-cursor">▎</span>}
              </div>

              {/* Subtitle */}
              <motion.div
                className="text-xs opacity-40 max-w-md"
                initial={{ opacity: 0 }}
                animate={{ opacity: 0.4 }}
                transition={{ delay: 0.8, duration: 0.5 }}
              >
                Launch a query through multiple LLMs. Verify, refine
                and detect hallucinations.
              </motion.div>

              {/* Pulsing cursor */}
              <div className="text-xs pt-4">
                <span className="text-primary/50">{">"} </span>
                <span className="terminal-cursor">_</span>
              </div>

              {/* ── Example query cards ── */}
              <motion.div
                className="flex flex-col sm:flex-row gap-3 pt-6 max-w-2xl mx-auto"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 1.4, duration: 0.5 }}
              >
                {EXAMPLE_QUERIES.map((ex, i) => (
                  <button
                    key={i}
                    onClick={() => handleExampleClick(ex.query)}
                    className="example-card flex-1 text-left p-3 border border-border rounded-none"
                  >
                    <div className="text-[10px] text-primary/70 mb-1.5 tracking-widest">
                      [{ex.label}]
                    </div>
                    <div className="text-xs text-muted-foreground leading-relaxed">
                      {ex.query}
                    </div>
                  </button>
                ))}
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  const allComplete = stages.length === expectedStageCount && stages.every((s) => s.status === "complete");
  const lastStage = allComplete ? stages[stages.length - 1] : null;

  return (
    <div className="space-y-8" data-testid="stages-container">
      {query && (stages.length > 0 || researchStatus) && (
        <div className="text-sm text-muted-foreground mb-6">
          <span className="opacity-60">QUERY: </span>
          <span className="text-foreground">{query}</span>
        </div>
      )}

      {researchStatus && (
        <div className="p-4 sm:p-5 border-b border-border/50 space-y-2" data-testid="research-block">
          <div className="flex items-center gap-2 text-sm">
            <span className="text-muted-foreground">{">"}</span>
            <span className="font-medium text-primary">LIVE RESEARCH</span>
            {researchStatus.status === "searching" && (
              <span className="text-muted-foreground animate-pulse">[RUN]</span>
            )}
            {researchStatus.status === "complete" && (
              <span className="text-foreground">[OK]</span>
            )}
            {researchStatus.status === "error" && (
              <span className="text-destructive">[ERR]</span>
            )}
          </div>
          {researchStatus.status === "searching" && (
            <div className="text-sm text-muted-foreground pt-1">
              Searching the web for current information<span className="animate-pulse">...</span>
            </div>
          )}
          {researchStatus.status === "complete" && (
            <div className="text-sm text-muted-foreground pt-1 whitespace-pre-wrap">
              Found {researchStatus.sourceCount} source{researchStatus.sourceCount !== 1 ? "s" : ""}:{"\n"}{researchStatus.sources}
            </div>
          )}
          {researchStatus.status === "error" && (
            <div className="text-sm text-destructive/80 pt-1">{researchStatus.error}</div>
          )}
        </div>
      )}

      {stages.map((stage) => (
        <StageBlock key={stage.stage} stage={stage} />
      ))}

      {allComplete && summary?.contradictions && summary.contradictions.length > 0 && (
        <ContradictionsView contradictions={summary.contradictions} />
      )}

      {allComplete && lastStage && (
        <FinalVerifiedAnswer
          content={lastStage.content}
          confidenceScore={summary?.confidenceScore}
        />
      )}

      {summary && allComplete && (
        <VerificationSummary summary={summary} />
      )}

      {allComplete && stages.length > 0 && (
        <div className="flex items-center gap-3 mt-8 pt-5 border-t border-border" data-testid="export-buttons">
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
          {verificationId && (
            <button
              onClick={() => {
                const url = `${window.location.origin}/report/${verificationId}`;
                navigator.clipboard.writeText(url);
              }}
              className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 border border-border rounded-none"
              data-testid="button-share"
            >
              <Share2 className="w-3 h-3" />
              [SHARE]
            </button>
          )}
        </div>
      )}
    </div>
  );
}
