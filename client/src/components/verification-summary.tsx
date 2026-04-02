import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { type VerificationSummary as VerificationSummaryType } from "@shared/schema";

interface VerificationSummaryProps {
  summary: VerificationSummaryType;
}

function getConfidenceBarColor(score?: number): string {
  if (score === undefined) return "bg-muted-foreground";
  if (score >= 0.8) return "bg-green-500";
  if (score >= 0.5) return "bg-yellow-500";
  return "bg-red-500";
}

/** Color for the overall score number */
function scoreTextColor(score: number): string {
  if (score >= 80) return "text-green-500";
  if (score >= 50) return "text-yellow-500";
  return "text-red-500";
}

export function VerificationSummary({ summary }: VerificationSummaryProps) {
  const [isVisible, setIsVisible] = useState(false);
  const jv = summary.judgeVerdict;

  useEffect(() => {
    const timer = setTimeout(() => setIsVisible(true), 50);
    return () => clearTimeout(timer);
  }, []);

  return (
    <motion.div
      className="mt-10 pt-6 border-t-2 border-primary/30 space-y-3"
      data-testid="verification-summary"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium text-primary">VERIFICATION SUMMARY</span>
        {summary.isAnalyzed && (
          <span className="text-xs text-primary opacity-70">[ANALYZED]</span>
        )}
        {/* Judge badge — indicates the dedicated Judge stage produced this verdict */}
        {jv && (
          <span className="text-xs text-primary opacity-70">[JUDGE]</span>
        )}
        {/* Overall score badge when Judge verdict is available */}
        {jv && (
          <span className={`ml-auto text-sm font-medium tabular-nums ${scoreTextColor(jv.overallScore)}`}>
            {jv.overallScore}/100
          </span>
        )}
      </div>

      {/* Judge verdict — expert summary sentence(s) */}
      {jv && (
        <motion.div
          className="text-sm text-foreground/90 leading-relaxed py-2"
          initial={{ opacity: 0, y: 4 }}
          animate={isVisible ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.4, delay: 0.1 }}
        >
          {jv.verdict}
        </motion.div>
      )}

      <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-3 text-sm py-3">
        <span className="text-muted-foreground whitespace-nowrap">Consistency:</span>
        <span className="text-foreground">{summary.consistency}</span>

        <span className="text-muted-foreground whitespace-nowrap">Hallucinations:</span>
        <span className="text-foreground">{summary.hallucinations}</span>

        <span className="text-muted-foreground whitespace-nowrap">Confidence:</span>
        <span className="text-foreground">{summary.confidence}</span>

        {summary.confidenceScore !== undefined && (
          <div className="mt-1 col-span-2">
            <div className="h-1.5 bg-muted rounded-sm overflow-hidden">
              <div
                className={`h-full ${getConfidenceBarColor(summary.confidenceScore)} transition-all duration-500`}
                style={{ width: `${Math.round(summary.confidenceScore * 100)}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Key findings / analyst-style bullet points from the Judge */}
      {summary.analysisBullets && summary.analysisBullets.length > 0 && (
        <div className="space-y-2.5 pt-1">
          {summary.analysisBullets.map((bullet, index) => (
            <motion.div
              key={index}
              className="flex items-start gap-2.5 text-sm"
              initial={{ opacity: 0, y: 6 }}
              animate={isVisible ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.4, delay: index * 0.12 }}
            >
              <span className="text-primary/60 shrink-0">&rsaquo;</span>
              <span className="text-foreground/85">{bullet}</span>
            </motion.div>
          ))}
        </div>
      )}

      {/* Per-stage agreement scores overview from the Judge */}
      {jv && jv.stageAnalyses.length > 0 && (
        <div className="flex items-center gap-3 pt-2 text-xs">
          <span className="text-muted-foreground">STAGES:</span>
          {jv.stageAnalyses.map((sa) => (
            <span
              key={sa.stage}
              className={`border px-1.5 py-0.5 rounded-none tabular-nums ${
                sa.agreementScore >= 80 ? "text-green-500 border-green-500/40" :
                sa.agreementScore >= 50 ? "text-yellow-500 border-yellow-500/40" :
                "text-red-500 border-red-500/40"
              }`}
              title={`Stage ${sa.stage}: ${sa.agreementScore}/100 agreement`}
            >
              S{sa.stage}:{sa.agreementScore}
            </span>
          ))}
        </div>
      )}

      {summary.contradictions && summary.contradictions.length > 0 && (
        <div className="space-y-2 pt-2">
          <div className="text-xs font-medium text-destructive">
            DISAGREEMENTS ({summary.contradictions.length})
          </div>
          {summary.contradictions.map((c, i) => (
            <div key={i} className="text-xs space-y-0.5">
              <span className="text-destructive/80">{c.topic}</span>
              <span className="text-muted-foreground ml-1">
                (Stage {c.stageA}{c.stageB > 0 ? ` vs ${c.stageB}` : ""})
              </span>
              <div className="text-muted-foreground">{c.description}</div>
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}
