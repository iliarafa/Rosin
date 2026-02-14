import { useQuery } from "@tanstack/react-query";
import { Link } from "wouter";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from "recharts";

interface ProviderPairStat {
  providerA: string;
  providerB: string;
  totalPairings: number;
  disagreements: number;
  rate: number;
}

interface DisagreementStats {
  totalVerifications: number;
  averageConfidence: number | null;
  pairsAnalyzed: number;
  providerPairs: ProviderPairStat[];
}

function getBarColor(rate: number): string {
  if (rate > 0.2) return "#ef4444";
  if (rate > 0.1) return "#eab308";
  return "#22c55e";
}

export default function HeatmapPage() {
  const { data: stats, isLoading } = useQuery<DisagreementStats>({
    queryKey: ["/api/disagreement-stats"],
    queryFn: async () => {
      const res = await fetch("/api/disagreement-stats");
      if (!res.ok) throw new Error("Failed to load stats");
      return res.json();
    },
  });

  const chartData = stats?.providerPairs.map((p) => ({
    name: `${p.providerA} / ${p.providerB}`,
    rate: Math.round(p.rate * 100),
    rawRate: p.rate,
    totalPairings: p.totalPairings,
    disagreements: p.disagreements,
  })) || [];

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex items-center justify-between max-w-4xl mx-auto">
          <div className="text-sm font-medium">DISAGREEMENT HEATMAP</div>
          <Link
            href="/terminal"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
          >
            [TERMINAL]
          </Link>
        </div>
      </header>

      <main className="flex-1 overflow-auto px-4 py-6 sm:px-8 sm:py-8">
        <div className="max-w-4xl mx-auto space-y-8">
          {isLoading && (
            <div className="text-sm text-muted-foreground animate-pulse">[...] Loading stats</div>
          )}

          {stats && stats.totalVerifications === 0 && (
            <div className="text-center text-sm text-muted-foreground py-20">
              <div className="opacity-60">No data yet.</div>
              <div className="opacity-40 mt-2">Run multiple verifications to see disagreement patterns.</div>
            </div>
          )}

          {stats && stats.totalVerifications > 0 && (
            <>
              {/* Stats cards */}
              <div className="grid grid-cols-3 gap-4">
                <div className="border border-border p-4">
                  <div className="text-xs text-muted-foreground">TOTAL VERIFICATIONS</div>
                  <div className="text-2xl mt-1">{stats.totalVerifications}</div>
                </div>
                <div className="border border-border p-4">
                  <div className="text-xs text-muted-foreground">AVG CONFIDENCE</div>
                  <div className="text-2xl mt-1">
                    {stats.averageConfidence !== null
                      ? `${Math.round(stats.averageConfidence * 100)}%`
                      : "N/A"}
                  </div>
                </div>
                <div className="border border-border p-4">
                  <div className="text-xs text-muted-foreground">PAIRS ANALYZED</div>
                  <div className="text-2xl mt-1">{stats.pairsAnalyzed}</div>
                </div>
              </div>

              {/* Chart */}
              {chartData.length > 0 && (
                <div className="border border-border p-4">
                  <div className="text-xs text-muted-foreground mb-4">DISAGREEMENT RATE BY PROVIDER PAIR</div>
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={chartData}>
                      <XAxis
                        dataKey="name"
                        tick={{ fontSize: 11, fontFamily: "monospace" }}
                        axisLine={{ stroke: "hsl(var(--border))" }}
                        tickLine={false}
                      />
                      <YAxis
                        tick={{ fontSize: 11, fontFamily: "monospace" }}
                        axisLine={{ stroke: "hsl(var(--border))" }}
                        tickLine={false}
                        tickFormatter={(v) => `${v}%`}
                      />
                      <Tooltip
                        contentStyle={{
                          fontFamily: "monospace",
                          fontSize: 12,
                          background: "hsl(var(--background))",
                          border: "1px solid hsl(var(--border))",
                        }}
                        formatter={(value: number) => [`${value}%`, "Disagreement Rate"]}
                      />
                      <Bar dataKey="rate">
                        {chartData.map((entry, index) => (
                          <Cell key={index} fill={getBarColor(entry.rawRate)} />
                        ))}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}

              {/* Table */}
              {stats.providerPairs.length > 0 && (
                <div className="border border-border">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-border">
                        <th className="text-left px-4 py-2 text-xs text-muted-foreground font-normal">PROVIDER PAIR</th>
                        <th className="text-right px-4 py-2 text-xs text-muted-foreground font-normal">PAIRINGS</th>
                        <th className="text-right px-4 py-2 text-xs text-muted-foreground font-normal">DISAGREEMENTS</th>
                        <th className="text-right px-4 py-2 text-xs text-muted-foreground font-normal">RATE</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stats.providerPairs.map((p, i) => (
                        <tr key={i} className="border-b border-border last:border-b-0">
                          <td className="px-4 py-2">{p.providerA} / {p.providerB}</td>
                          <td className="text-right px-4 py-2">{p.totalPairings}</td>
                          <td className="text-right px-4 py-2">{p.disagreements}</td>
                          <td className={`text-right px-4 py-2 ${
                            p.rate > 0.2 ? "text-red-500" : p.rate > 0.1 ? "text-yellow-500" : "text-green-500"
                          }`}>
                            {Math.round(p.rate * 100)}%
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
        </div>
      </main>
    </div>
  );
}
