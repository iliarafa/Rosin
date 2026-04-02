import { useState, useRef, useEffect, useCallback } from "react";
import { Link } from "wouter";
import { useMutation } from "@tanstack/react-query";
import { motion, AnimatePresence } from "framer-motion";
import { apiRequest, queryClient } from "@/lib/queryClient";
import { ModelSelector } from "@/components/model-selector";
import { StageCountSelector } from "@/components/stage-count-selector";
import { TerminalOutput } from "@/components/terminal-output";
import { TerminalInput } from "@/components/terminal-input";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { type LLMModel, type StageOutput, type VerificationSummary, type ResearchStatus } from "@shared/schema";
import { useLocalHistory, type LocalHistoryItem } from "@/hooks/use-local-history";

const allModels: LLMModel[] = [
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
  { provider: "xai", model: "grok-3" },
  { provider: "anthropic", model: "claude-opus-4-5" },
];

interface VerificationInput {
  query: string;
  chain: LLMModel[];
}

/** Color class for Judge overall score badge (0–100) */
function judgeScoreColor(score: number): string {
  if (score >= 80) return "text-green-500 border-green-500/40";
  if (score >= 50) return "text-yellow-500 border-yellow-500/40";
  return "text-red-500 border-red-500/40";
}

function relativeTime(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = now - then;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export default function Terminal() {
  const [stageCount, setStageCount] = useState(4);
  const [chain, setChain] = useState<LLMModel[]>(allModels);
  const [query, setQuery] = useState("");
  const [stages, setStages] = useState<StageOutput[]>([]);
  const [finalSummary, setFinalSummary] = useState<VerificationSummary | null>(null);
  const [adversarialMode, setAdversarialMode] = useState(false);
  const [liveResearch, setLiveResearch] = useState(false);
  const [researchStatus, setResearchStatus] = useState<ResearchStatus | null>(null);
  const [verificationId, setVerificationId] = useState<string | null>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const outputRef = useRef<HTMLDivElement>(null);
  const localHistory = useLocalHistory();

  // ── History drawer + read-only mode state ──────────────────────────
  const [historyOpen, setHistoryOpen] = useState(false);
  const [confirmClear, setConfirmClear] = useState(false);
  // When viewing a saved verification, this holds the loaded item.
  // The terminal renders it read-only with all expandable sections working.
  const [viewingItem, setViewingItem] = useState<LocalHistoryItem | null>(null);

  const activeChain = chain.slice(0, stageCount);

  const updateModel = (index: number, model: LLMModel) => {
    setChain((prev) => {
      const updated = [...prev];
      updated[index] = model;
      return updated;
    });
  };

  /** Load a saved verification into the terminal in read-only mode */
  const loadHistoryItem = useCallback((item: LocalHistoryItem) => {
    setViewingItem(item);
    setQuery(item.query);
    setStages(item.stages);
    setFinalSummary(item.summary);
    setResearchStatus(null);
    setVerificationId(null);
    setHistoryOpen(false);
  }, []);

  /** Exit read-only mode and reset for a new query */
  const clearViewing = useCallback(() => {
    setViewingItem(null);
    setQuery("");
    setStages([]);
    setFinalSummary(null);
    setResearchStatus(null);
    setVerificationId(null);
  }, []);

  const processSSEStream = useCallback(async (response: Response, chainModels: LLMModel[]) => {
    const reader = response.body?.getReader();
    if (!reader) throw new Error("No response body");

    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;

        try {
          const event = JSON.parse(line.slice(6));

          if (event.type === "research_start") {
            setResearchStatus({ status: "searching" });
          } else if (event.type === "research_complete") {
            setResearchStatus({
              status: "complete",
              sourceCount: event.sourceCount,
              sources: event.sources,
            });
          } else if (event.type === "research_error") {
            setResearchStatus({ status: "error", error: event.error });
          } else if (event.type === "stage_start") {
            setStages((prev) => [
              ...prev,
              {
                stage: event.stage,
                model: event.model,
                content: "",
                status: "streaming",
              },
            ]);
          } else if (event.type === "stage_content") {
            setStages((prev) =>
              prev.map((s) =>
                s.stage === event.stage
                  ? { ...s, content: s.content + event.content }
                  : s
              )
            );
          } else if (event.type === "stage_complete") {
            setStages((prev) =>
              prev.map((s) =>
                s.stage === event.stage ? { ...s, status: "complete" } : s
              )
            );
          } else if (event.type === "stage_error") {
            setStages((prev) =>
              prev.map((s) =>
                s.stage === event.stage
                  ? { ...s, status: "error", error: event.error }
                  : s
              )
            );
          } else if (event.type === "verification_id") {
            setVerificationId(event.id);
          } else if (event.type === "stage_analysis") {
            setStages((prev) =>
              prev.map((s) =>
                s.stage === event.stage
                  ? { ...s, analysis: event.analysis }
                  : s
              )
            );
          } else if (event.type === "summary") {
            setFinalSummary(event.summary);
          }
        } catch (e) {
        }
      }
    }
  }, []);

  const verifyMutation = useMutation({
    mutationFn: async ({ query, chain }: VerificationInput) => {
      const response = await apiRequest("POST", "/api/verify", { query, chain, adversarialMode, liveResearch });
      await processSSEStream(response, chain);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/verify"] });
    },
    onError: (error: Error) => {
      console.error("Verification error:", error);
      setStages((prev) => [
        ...prev,
        {
          stage: prev.length + 1,
          model: chain[prev.length] || chain[0],
          content: "",
          status: "error",
          error: error.message || "Unknown error",
        },
      ]);
    },
  });

  const handleSubmit = () => {
    if (!query.trim() || verifyMutation.isPending) return;

    // Clear read-only mode if active
    if (viewingItem) setViewingItem(null);

    setStages([]);
    setFinalSummary(null);
    setResearchStatus(null);
    setVerificationId(null);
    verifyMutation.mutate({ query, chain: activeChain });
  };

  // Save completed verifications to local history (100% on-device, no server)
  useEffect(() => {
    if (
      finalSummary &&
      stages.length > 0 &&
      stages.every((s) => s.status === "complete") &&
      !viewingItem // Don't re-save when viewing a past item
    ) {
      localHistory.save({
        query,
        chain: activeChain,
        stages,
        summary: finalSummary,
        adversarialMode,
      });
    }
  }, [finalSummary]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [stages]);

  // Reset confirm-clear state when drawer closes
  useEffect(() => {
    if (!historyOpen) setConfirmClear(false);
  }, [historyOpen]);

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header
        className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4"
        data-testid="header-model-selection"
      >
        {/* ── Mobile header row ── */}
        <div className="flex items-center justify-between mb-2 sm:hidden">
          <StageCountSelector
            value={stageCount}
            onChange={setStageCount}
            disabled={verifyMutation.isPending || !!viewingItem}
          />
          <div className="flex items-center gap-1.5">
            <button
              onClick={() => setLiveResearch((v) => !v)}
              className={`text-xs transition-colors px-1.5 py-1 border rounded-none ${
                liveResearch
                  ? "text-primary border-primary/50"
                  : "text-muted-foreground border-border"
              }`}
              disabled={verifyMutation.isPending || !!viewingItem}
            >
              [LIVE]
            </button>
            <button
              onClick={() => setAdversarialMode((v) => !v)}
              className={`text-xs transition-colors px-1.5 py-1 border rounded-none ${
                adversarialMode
                  ? "text-destructive border-destructive/50"
                  : "text-muted-foreground border-border"
              }`}
              disabled={verifyMutation.isPending || !!viewingItem}
            >
              [ADV]
            </button>
            <div className="relative">
              <button
                onClick={() => setMobileMenuOpen((v) => !v)}
                className="text-xs text-muted-foreground hover:text-foreground transition-colors px-1.5 py-1 border border-border rounded-none"
              >
                [···]
              </button>
              {mobileMenuOpen && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setMobileMenuOpen(false)} />
                  <div className="absolute right-0 top-full mt-1 z-50 border border-border bg-background py-1 min-w-[120px]">
                    <button
                      className="block w-full text-left text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5"
                      onClick={() => { setMobileMenuOpen(false); setHistoryOpen(true); }}
                    >
                      [HISTORY]
                    </button>
                    <Link
                      href="/heatmap"
                      className="block text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5"
                      onClick={() => setMobileMenuOpen(false)}
                    >
                      [STATS]
                    </Link>
                    <Link
                      href="/readme"
                      className="block text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5"
                      onClick={() => setMobileMenuOpen(false)}
                      data-testid="link-readme-mobile"
                    >
                      [README]
                    </Link>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>

        {/* ── Desktop header row ── */}
        <div className="grid grid-cols-2 gap-3 sm:flex sm:flex-wrap sm:items-center sm:gap-6">
          <div className="hidden sm:flex sm:items-center sm:gap-5">
            <StageCountSelector
              value={stageCount}
              onChange={setStageCount}
              disabled={verifyMutation.isPending || !!viewingItem}
            />
            <span className="text-muted-foreground opacity-40">|</span>
          </div>
          {activeChain.map((model, index) => {
            const stageData = stages.find((s) => s.stage === index + 1);
            const isActive = stageData?.status === "streaming";
            return (
              <ModelSelector
                key={index}
                stageNumber={index + 1}
                selectedModel={model}
                onModelChange={(m) => updateModel(index, m)}
                disabled={verifyMutation.isPending || !!viewingItem}
                isActive={isActive}
              />
            );
          })}
          <div className="hidden sm:flex sm:items-center sm:ml-auto sm:gap-2">
            <button
              onClick={() => setLiveResearch((v) => !v)}
              className={`text-xs transition-colors px-2 py-1 border rounded-none ${
                liveResearch
                  ? "text-primary border-primary/50"
                  : "text-muted-foreground border-border"
              } hover:text-foreground`}
              disabled={verifyMutation.isPending || !!viewingItem}
              data-testid="button-live-research"
            >
              {liveResearch ? "[LIVE: ON]" : "[LIVE: OFF]"}
            </button>
            <button
              onClick={() => setAdversarialMode((v) => !v)}
              className={`text-xs transition-colors px-2 py-1 border rounded-none ${
                adversarialMode
                  ? "text-destructive border-destructive/50"
                  : "text-muted-foreground border-border"
              } hover:text-foreground`}
              disabled={verifyMutation.isPending || !!viewingItem}
              data-testid="button-adversarial"
            >
              {adversarialMode ? "[ADV: ON]" : "[ADV: OFF]"}
            </button>
            {/* History drawer trigger — opens slide-in panel */}
            <button
              onClick={() => setHistoryOpen(true)}
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            >
              [HISTORY]
            </button>
            <Link
              href="/heatmap"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            >
              [STATS]
            </Link>
            <Link
              href="/readme"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
              data-testid="link-readme"
            >
              [README]
            </Link>
          </div>
        </div>
      </header>

      {/* ── Read-only banner (shown when viewing a saved verification) ── */}
      <AnimatePresence>
        {viewingItem && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="overflow-hidden border-b border-primary/20 bg-primary/5"
          >
            <div className="flex items-center justify-between px-4 py-2 sm:px-6">
              <div className="flex items-center gap-3 text-xs">
                <span className="text-primary/70">Viewing saved verification</span>
                <span className="text-muted-foreground/40">
                  {new Date(viewingItem.createdAt).toLocaleString()}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={clearViewing}
                  className="text-xs text-primary hover:text-foreground transition-colors px-2 py-1 border border-primary/30 rounded-none"
                >
                  [NEW QUERY]
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <main
        ref={outputRef}
        className="flex-1 overflow-auto px-4 py-6 sm:px-8 sm:py-8 crt-scanlines"
        data-testid="terminal-output-area"
      >
        <div className="max-w-4xl mx-auto">
          <TerminalOutput
            query={query}
            stages={stages}
            summary={finalSummary}
            isProcessing={verifyMutation.isPending}
            expectedStageCount={viewingItem ? viewingItem.stages.length : stageCount}
            verificationId={verificationId}
            researchStatus={researchStatus}
            onQuerySelect={(q) => { if (!viewingItem) setQuery(q); }}
          />
        </div>
      </main>

      <footer
        className="sticky bottom-0 z-50 border-t border-border bg-background/80 backdrop-blur-sm px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-4"
        data-testid="footer-input"
      >
        <TerminalInput
          value={query}
          onChange={setQuery}
          onSubmit={handleSubmit}
          isProcessing={verifyMutation.isPending}
        />
      </footer>

      {/* ── History Drawer (shadcn Sheet, slides from right) ── */}
      <Sheet open={historyOpen} onOpenChange={setHistoryOpen}>
        <SheetContent
          side="right"
          className="w-full sm:max-w-md bg-background border-l border-border p-0 font-mono flex flex-col"
        >
          <SheetHeader className="px-5 pt-5 pb-3 border-b border-border shrink-0">
            <div className="flex items-center justify-between">
              <SheetTitle className="text-sm font-medium tracking-wide">
                HISTORY
              </SheetTitle>
              {/* Clear All with two-step confirmation */}
              {localHistory.items.length > 0 && (
                confirmClear ? (
                  <div className="flex items-center gap-1.5">
                    <span className="text-[10px] text-destructive">Clear all?</span>
                    <button
                      onClick={() => { localHistory.clearAll(); setConfirmClear(false); }}
                      className="text-[10px] text-destructive hover:text-foreground transition-colors px-1.5 py-0.5 border border-destructive/50 rounded-none"
                    >
                      YES
                    </button>
                    <button
                      onClick={() => setConfirmClear(false)}
                      className="text-[10px] text-muted-foreground hover:text-foreground transition-colors px-1.5 py-0.5 border border-border rounded-none"
                    >
                      NO
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => setConfirmClear(true)}
                    className="text-[10px] text-muted-foreground hover:text-destructive transition-colors px-1.5 py-0.5 border border-border rounded-none"
                  >
                    [CLEAR]
                  </button>
                )
              )}
            </div>
            <SheetDescription className="text-[10px] text-muted-foreground/40 tracking-wide">
              100% LOCAL — stored on this device only
            </SheetDescription>
          </SheetHeader>

          <div className="flex-1 overflow-auto">
            {localHistory.items.length === 0 ? (
              <div className="text-center text-xs text-muted-foreground py-20 px-5">
                <div className="opacity-60">No verifications yet.</div>
                <div className="opacity-40 mt-2">Run a verification to see history here.</div>
              </div>
            ) : (
              <div className="divide-y divide-border/50">
                {localHistory.items.map((item) => {
                  const jv = item.summary?.judgeVerdict;
                  return (
                    <button
                      key={item.id}
                      onClick={() => loadHistoryItem(item)}
                      className="w-full text-left px-5 py-3.5 hover:bg-muted/30 transition-colors"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex-1 min-w-0">
                          <div className="text-xs truncate">{item.query}</div>
                          <div className="flex items-center gap-2 mt-1.5 text-[10px] text-muted-foreground/60">
                            <span>{item.stages.length} stages</span>
                            {item.adversarialMode && (
                              <span className="text-destructive">[ADV]</span>
                            )}
                            <span>{relativeTime(item.createdAt)}</span>
                          </div>
                        </div>
                        {/* Judge overall score badge */}
                        {jv && (
                          <span
                            className={`shrink-0 text-[10px] border px-1.5 py-0.5 rounded-none tabular-nums ${judgeScoreColor(jv.overallScore)}`}
                          >
                            {jv.overallScore}
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
