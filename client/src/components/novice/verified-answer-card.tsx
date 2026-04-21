import { useState } from "react";

export interface VerifiedSource {
  title: string;
  url: string;
  status: "VERIFIED" | "BROKEN" | "TIMEOUT" | "UNCHECKED";
}

interface VerifiedAnswerCardProps {
  question: string;
  answer: string;
  sources: VerifiedSource[];
  onAskAnother: () => void;
  onShowVerification: () => void;
}

export function VerifiedAnswerCard({
  question,
  answer,
  sources,
  onAskAnother,
  onShowVerification,
}: VerifiedAnswerCardProps) {
  const [showAllSources, setShowAllSources] = useState(false);
  const previewSources = sources.slice(0, 2);
  const restSources = sources.slice(2);

  return (
    <div className="w-full max-w-2xl mx-auto font-mono text-zinc-200" data-testid="verified-answer-card">
      <div className="text-xs text-zinc-500 mb-1 uppercase tracking-wide">You asked</div>
      <div className="text-sm text-zinc-400 mb-6 italic">"{question}"</div>

      <div className="text-sm leading-relaxed whitespace-pre-wrap border-l-2 border-green-500/40 pl-4 py-1">
        {answer}
      </div>

      <div className="mt-6">
        <button
          onClick={() => setShowAllSources((v) => !v)}
          className="text-xs text-zinc-400 hover:text-zinc-200 uppercase tracking-wide"
          data-testid="novice-sources-toggle"
        >
          [ sources {showAllSources ? "▲" : "▼"} ]
        </button>
        <ul className="mt-2 space-y-1 text-xs">
          {previewSources.map((s, i) => (
            <li key={i}>
              <span className={s.status === "VERIFIED" ? "text-green-500" : "text-red-500"}>
                {s.status === "VERIFIED" ? "✓" : "✗"}
              </span>
              <a href={s.url} target="_blank" rel="noreferrer" className="ml-2 text-zinc-300 hover:underline">
                {s.title}
              </a>
            </li>
          ))}
          {showAllSources &&
            restSources.map((s, i) => (
              <li key={i + 2}>
                <span className={s.status === "VERIFIED" ? "text-green-500" : "text-red-500"}>
                  {s.status === "VERIFIED" ? "✓" : "✗"}
                </span>
                <a href={s.url} target="_blank" rel="noreferrer" className="ml-2 text-zinc-300 hover:underline">
                  {s.title}
                </a>
              </li>
            ))}
        </ul>
      </div>

      <div className="flex items-center gap-4 mt-8">
        <button
          onClick={onAskAnother}
          className="border border-zinc-500 text-zinc-300 px-5 py-2 text-sm tracking-widest hover:bg-zinc-500/10"
          data-testid="novice-ask-another"
        >
          [ ASK ANOTHER ]
        </button>
        <button
          onClick={onShowVerification}
          className="text-xs text-zinc-500 hover:text-zinc-300 underline underline-offset-4"
          data-testid="novice-show-verification"
        >
          see how it was verified
        </button>
      </div>
    </div>
  );
}
