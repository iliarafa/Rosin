import { motion } from "framer-motion";

type TrustBand = "high" | "partial" | "low";

function band(score: number): TrustBand {
  if (score >= 85) return "high";
  if (score >= 60) return "partial";
  return "low";
}

const LABELS: Record<TrustBand, string> = {
  high: "Highly verified",
  partial: "Partially verified",
  low: "Low confidence — treat with skepticism",
};

const COLORS: Record<TrustBand, string> = {
  high: "text-green-500 border-green-500/40",
  partial: "text-yellow-500 border-yellow-500/40",
  low: "text-red-500 border-red-500/40",
};

interface TrustScoreBannerProps {
  score: number | null;
  aiCount: number;
  sourceCount: number;
}

export function TrustScoreBanner({ score, aiCount, sourceCount }: TrustScoreBannerProps) {
  if (score === null) {
    return (
      <div className="font-mono text-red-500 border border-red-500/40 px-4 py-3 rounded">
        [ COULD NOT VERIFY ]
      </div>
    );
  }

  const b = band(score);

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={`font-mono border rounded px-5 py-4 ${COLORS[b]}`}
      data-testid="trust-score-banner"
    >
      <div className="text-xs uppercase tracking-widest opacity-70">[ VERIFIED ]</div>
      <div className="flex items-baseline gap-3 mt-1">
        <span className="text-5xl font-semibold tabular-nums">{score}%</span>
        <span className="text-sm uppercase tracking-wide">{LABELS[b]}</span>
      </div>
      <div className="text-xs opacity-70 mt-2">
        {aiCount} AIs agreed · {sourceCount} sources confirmed
      </div>
    </motion.div>
  );
}
