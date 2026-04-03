import { motion } from "framer-motion";
import { Download, Share2 } from "lucide-react";
import { type StageOutput, type VerificationSummary as VerificationSummaryType } from "@shared/schema";
import { FinalVerifiedAnswer } from "./final-verified-answer";
import { VerificationSummary } from "./verification-summary";
import { ContradictionsView } from "./contradictions-view";

interface RosinResultsViewProps {
  query: string;
  stages: StageOutput[];
  summary: VerificationSummaryType | null;
  verificationId?: string | null;
  onViewFullOutput: () => void;
}

export function RosinResultsView({
  query,
  stages,
  summary,
  verificationId,
  onViewFullOutput,
}: RosinResultsViewProps) {
  const lastStage = stages[stages.length - 1];

  return (
    <motion.div
      className="space-y-8"
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: "easeOut" }}
    >
      {/* Query reminder */}
      {query && (
        <div className="text-sm text-muted-foreground">
          <span className="opacity-60">QUERY: </span>
          <span className="text-foreground">{query}</span>
        </div>
      )}

      {/* Final Verified Answer */}
      {lastStage && (
        <FinalVerifiedAnswer
          content={lastStage.content}
          confidenceScore={summary?.confidenceScore}
        />
      )}

      {/* Contradictions */}
      {summary?.contradictions && summary.contradictions.length > 0 && (
        <ContradictionsView contradictions={summary.contradictions} />
      )}

      {/* Verification Summary with Judge */}
      {summary && <VerificationSummary summary={summary} />}

      {/* View full output + Export buttons */}
      <div className="flex flex-wrap items-center gap-3 mt-8 pt-5 border-t border-border">
        <button
          onClick={onViewFullOutput}
          className="text-xs text-primary hover:text-foreground transition-colors px-3 py-1.5 border border-primary/30 rounded-none"
        >
          [VIEW FULL OUTPUT]
        </button>

        <span className="text-xs text-muted-foreground opacity-60 ml-auto">EXPORT:</span>
        <button
          onClick={() => {
            const escapeCSV = (str: string) =>
              str.includes(",") || str.includes('"') || str.includes("\n")
                ? `"${str.replace(/"/g, '""')}"`
                : str;
            const headers = ["Stage", "Provider", "Model", "Content"];
            const rows = stages.map((s) => [
              s.stage.toString(), s.model.provider, s.model.model, escapeCSV(s.content),
            ]);
            const csv = [`Query,${escapeCSV(query)}`, "", headers.join(","), ...rows.map((r) => r.join(","))].join("\n");
            const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
            const link = document.createElement("a");
            link.href = URL.createObjectURL(blob);
            link.download = `verification-${Date.now()}.csv`;
            link.click();
            URL.revokeObjectURL(link.href);
          }}
          className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 border border-border rounded-none"
        >
          <Download className="w-3 h-3" />
          [CSV]
        </button>
        <button
          onClick={() => {
            const escapeHtml = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            const html = `<!DOCTYPE html><html><head><title>Verification</title><style>body{font-family:'Courier New',monospace;padding:40px;max-width:800px;margin:0 auto}h1{font-size:18px;border-bottom:2px solid #000;padding-bottom:10px}.query{background:#f5f5f5;padding:15px;margin:20px 0}.verified{margin-top:30px;padding:20px;border:2px solid #000}@media print{body{padding:20px}}</style></head><body><h1>ROSIN — VERIFIED ANSWER</h1><div class="query"><strong>QUERY:</strong> ${escapeHtml(query)}</div><div class="verified"><strong>VERIFIED OUTPUT</strong><div style="white-space:pre-wrap;margin-top:10px">${escapeHtml(lastStage?.content || "")}</div></div></body></html>`;
            const w = window.open("", "_blank");
            if (w) { w.document.write(html); w.document.close(); w.onload = () => w.print(); }
          }}
          className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 border border-border rounded-none"
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
          >
            <Share2 className="w-3 h-3" />
            [SHARE]
          </button>
        )}
      </div>
    </motion.div>
  );
}
