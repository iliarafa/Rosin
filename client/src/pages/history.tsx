import { useQuery } from "@tanstack/react-query";
import { Link } from "wouter";

interface HistoryItem {
  id: string;
  query: string;
  chainSummary: string;
  stageCount: number;
  confidenceScore?: number;
  contradictionCount: number;
  adversarialMode: boolean;
  createdAt: string;
}

function getConfidenceColor(score?: number): string {
  if (score === undefined) return "text-muted-foreground";
  if (score >= 0.8) return "text-green-500";
  if (score >= 0.5) return "text-yellow-500";
  return "text-red-500";
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
  const { data: items, isLoading } = useQuery<HistoryItem[]>({
    queryKey: ["/api/history"],
    queryFn: async () => {
      const res = await fetch("/api/history");
      if (!res.ok) throw new Error("Failed to load history");
      return res.json();
    },
  });

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex items-center justify-between max-w-4xl mx-auto">
          <div className="text-sm font-medium">VERIFICATION HISTORY</div>
          <Link
            href="/terminal"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
          >
            [TERMINAL]
          </Link>
        </div>
      </header>

      <main className="flex-1 overflow-auto px-4 py-6 sm:px-8 sm:py-8">
        <div className="max-w-4xl mx-auto space-y-4">
          {isLoading && (
            <div className="text-sm text-muted-foreground animate-pulse">[...] Loading history</div>
          )}

          {!isLoading && (!items || items.length === 0) && (
            <div className="text-center text-sm text-muted-foreground py-20">
              <div className="opacity-60">No verifications yet.</div>
              <div className="opacity-40 mt-2">Run a verification to see history here.</div>
            </div>
          )}

          {items?.map((item) => (
            <Link
              key={item.id}
              href={`/report/${item.id}`}
              className="block border border-border p-4 hover:border-foreground/30 transition-colors"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="text-sm truncate">{item.query}</div>
                  <div className="text-xs text-muted-foreground mt-1.5">
                    {item.chainSummary}
                    {item.adversarialMode && (
                      <span className="text-destructive ml-2">[ADV]</span>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-4 text-xs text-muted-foreground shrink-0">
                  {item.confidenceScore !== undefined && (
                    <span className={getConfidenceColor(item.confidenceScore)}>
                      {Math.round(item.confidenceScore * 100)}%
                    </span>
                  )}
                  {item.contradictionCount > 0 && (
                    <span className="text-destructive">
                      {item.contradictionCount} disagreement{item.contradictionCount !== 1 ? "s" : ""}
                    </span>
                  )}
                  <span>{item.stageCount} stages</span>
                  <span className="opacity-60">{relativeTime(item.createdAt)}</span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </main>
    </div>
  );
}
