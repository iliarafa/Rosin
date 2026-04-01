import { useState } from "react";
import { CheckCircle2, ChevronDown, ChevronUp, Loader2 } from "lucide-react";
import { apiRequest } from "@/lib/queryClient";

interface FinalVerifiedAnswerProps {
  content: string;
  confidenceScore?: number;
}

function getAccentColor(score?: number): string {
  if (score === undefined) return "border-foreground/20";
  if (score >= 0.8) return "border-green-500";
  if (score >= 0.5) return "border-yellow-500";
  return "border-red-500";
}

function getGlowColor(score?: number): string {
  if (score === undefined) return "shadow-foreground/5";
  if (score >= 0.8) return "shadow-green-500/10";
  if (score >= 0.5) return "shadow-yellow-500/10";
  return "shadow-red-500/10";
}

export function FinalVerifiedAnswer({ content, confidenceScore }: FinalVerifiedAnswerProps) {
  const [showConcise, setShowConcise] = useState(false);
  const [conciseSummary, setConciseSummary] = useState<string | null>(null);
  const [isLoadingSummary, setIsLoadingSummary] = useState(false);
  const [summaryError, setSummaryError] = useState<string | null>(null);

  const accentColor = getAccentColor(confidenceScore);
  const glowColor = getGlowColor(confidenceScore);

  // Fetch concise summary from server on first toggle
  const handleToggle = async () => {
    if (showConcise) {
      // Switch back to full answer — instant
      setShowConcise(false);
      return;
    }

    // Switch to concise view
    setShowConcise(true);

    // Only fetch if we haven't already
    if (conciseSummary) return;

    setIsLoadingSummary(true);
    setSummaryError(null);

    try {
      const res = await apiRequest("POST", "/api/summarize", { text: content });
      const data = await res.json();
      setConciseSummary(data.summary);
    } catch (err) {
      setSummaryError("Failed to generate summary");
      console.error("Summarize error:", err);
    } finally {
      setIsLoadingSummary(false);
    }
  };

  return (
    <div
      className={`mt-10 border ${accentColor} shadow-lg ${glowColor} bg-background`}
      data-testid="final-verified-answer"
    >
      {/* Header bar */}
      <div className={`flex items-center justify-between px-4 py-3 sm:px-5 border-b ${accentColor}`}>
        <div className="flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 text-green-500" />
          <span className="text-sm font-medium tracking-wide">FINAL VERIFIED ANSWER</span>
        </div>

        <button
          onClick={handleToggle}
          className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors px-2.5 py-1 border border-border rounded-none"
          data-testid="toggle-concise-summary"
        >
          {showConcise ? (
            <>
              <ChevronDown className="w-3 h-3" />
              Show Full Answer
            </>
          ) : (
            <>
              <ChevronUp className="w-3 h-3" />
              Show Concise Summary
            </>
          )}
        </button>
      </div>

      {/* Content area */}
      <div className="px-4 py-5 sm:px-5 sm:py-6">
        {showConcise ? (
          <div data-testid="concise-summary">
            {isLoadingSummary ? (
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                <span>Generating concise summary...</span>
              </div>
            ) : summaryError ? (
              <div className="text-sm text-destructive">{summaryError}</div>
            ) : (
              <div className="text-sm leading-relaxed whitespace-pre-wrap">
                {conciseSummary}
              </div>
            )}
          </div>
        ) : (
          <div
            className="text-sm leading-relaxed whitespace-pre-wrap"
            data-testid="full-answer"
          >
            {content}
          </div>
        )}
      </div>
    </div>
  );
}
