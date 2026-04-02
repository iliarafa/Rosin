import { useState } from "react";
import { Link, useLocation } from "wouter";
import { motion, AnimatePresence } from "framer-motion";
import { useLocalHistory } from "@/hooks/use-local-history";

// ── Local-only verification history ────────────────────────────────
// All data is stored in localStorage on the user's device.
// No server calls, no cloud sync, no data collection.

function getConfidenceColor(score?: number): string {
  if (score === undefined) return "text-muted-foreground";
  if (score >= 0.8) return "text-green-500";
  if (score >= 0.5) return "text-yellow-500";
  return "text-red-500";
}

/** Color for the Judge overall score (0–100) */
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

export default function HistoryPage() {
  const { items, remove, clearAll } = useLocalHistory();
  const [, navigate] = useLocation();
  const [confirmClear, setConfirmClear] = useState(false);

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex items-center justify-between max-w-4xl mx-auto">
          <div className="text-sm font-medium">VERIFICATION HISTORY</div>
          <div className="flex items-center gap-2">
            {/* Clear All — with confirmation step */}
            {items.length > 0 && (
              confirmClear ? (
                <div className="flex items-center gap-1.5">
                  <span className="text-xs text-destructive">Clear all?</span>
                  <button
                    onClick={() => { clearAll(); setConfirmClear(false); }}
                    className="text-xs text-destructive hover:text-foreground transition-colors px-2 py-1 border border-destructive/50 rounded-none"
                  >
                    [YES]
                  </button>
                  <button
                    onClick={() => setConfirmClear(false)}
                    className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
                  >
                    [NO]
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setConfirmClear(true)}
                  className="text-xs text-muted-foreground hover:text-destructive transition-colors px-2 py-1 border border-border rounded-none"
                >
                  [CLEAR]
                </button>
              )
            )}
            <Link
              href="/terminal"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            >
              [TERMINAL]
            </Link>
          </div>
        </div>
      </header>

      <main className="flex-1 overflow-auto px-4 py-6 sm:px-8 sm:py-8">
        <div className="max-w-4xl mx-auto space-y-4">
          {/* Privacy notice */}
          <div className="text-[10px] text-muted-foreground/40 tracking-wide">
            100% LOCAL — stored on this device only
          </div>

          {items.length === 0 && (
            <div className="text-center text-sm text-muted-foreground py-20">
              <div className="opacity-60">No verifications yet.</div>
              <div className="opacity-40 mt-2">Run a verification to see history here.</div>
            </div>
          )}

          <AnimatePresence>
            {items.map((item) => {
              const jv = item.summary?.judgeVerdict;
              return (
                <motion.div
                  key={item.id}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.2 }}
                >
                  <div
                    onClick={() => navigate(`/report/${item.id}`)}
                    className="block border border-border p-4 hover:border-foreground/30 transition-colors cursor-pointer"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1 min-w-0">
                        <div className="text-sm truncate">{item.query}</div>
                        <div className="text-xs text-muted-foreground mt-1.5">
                          {item.chain.map((m) => m.model).join(" → ")}
                          {item.adversarialMode && (
                            <span className="text-destructive ml-2">[ADV]</span>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-3 text-xs text-muted-foreground shrink-0">
                        {/* Judge overall score badge */}
                        {jv && (
                          <span
                            className={`border px-1.5 py-0.5 rounded-none tabular-nums ${judgeScoreColor(jv.overallScore)}`}
                            title={`Judge score: ${jv.overallScore}/100`}
                          >
                            {jv.overallScore}
                          </span>
                        )}
                        {/* Fallback confidence % when no Judge verdict */}
                        {!jv && item.summary?.confidenceScore !== undefined && (
                          <span className={getConfidenceColor(item.summary.confidenceScore)}>
                            {Math.round(item.summary.confidenceScore * 100)}%
                          </span>
                        )}
                        <span>{item.stages.length} stages</span>
                        <span className="opacity-60">{relativeTime(item.createdAt)}</span>
                      </div>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
      </main>
    </div>
  );
}
