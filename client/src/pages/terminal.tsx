import { useState, useRef, useEffect, useCallback } from "react";
import { Link } from "wouter";
import { useMutation } from "@tanstack/react-query";
import { apiRequest, queryClient } from "@/lib/queryClient";
import { ModelSelector } from "@/components/model-selector";
import { StageCountSelector } from "@/components/stage-count-selector";
import { TerminalOutput } from "@/components/terminal-output";
import { TerminalInput } from "@/components/terminal-input";
import { type LLMModel, type StageOutput, type VerificationSummary } from "@shared/schema";

const allModels: LLMModel[] = [
  { provider: "openai", model: "gpt-4o" },
  { provider: "anthropic", model: "claude-sonnet-4-5" },
  { provider: "gemini", model: "gemini-2.5-flash" },
  { provider: "xai", model: "grok-3" },
];

interface VerificationInput {
  query: string;
  chain: LLMModel[];
}

export default function Terminal() {
  const [stageCount, setStageCount] = useState(4);
  const [chain, setChain] = useState<LLMModel[]>(allModels);
  const [query, setQuery] = useState("");
  const [stages, setStages] = useState<StageOutput[]>([]);
  const [finalSummary, setFinalSummary] = useState<VerificationSummary | null>(null);
  const outputRef = useRef<HTMLDivElement>(null);

  const activeChain = chain.slice(0, stageCount);

  const updateModel = (index: number, model: LLMModel) => {
    setChain((prev) => {
      const updated = [...prev];
      updated[index] = model;
      return updated;
    });
  };

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
          
          if (event.type === "stage_start") {
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
      const response = await apiRequest("POST", "/api/verify", { query, chain });
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

    setStages([]);
    setFinalSummary(null);
    verifyMutation.mutate({ query, chain: activeChain });
  };

  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [stages]);

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header
        className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3 sm:px-6 sm:py-4"
        data-testid="header-model-selection"
      >
        <div className="flex items-center justify-between mb-2 sm:hidden">
          <StageCountSelector
            value={stageCount}
            onChange={setStageCount}
            disabled={verifyMutation.isPending}
          />
          <Link
            href="/readme"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            data-testid="link-readme-mobile"
          >
            [README]
          </Link>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:flex sm:flex-wrap sm:items-center sm:gap-6">
          <div className="hidden sm:flex sm:items-center sm:gap-5">
            <StageCountSelector
              value={stageCount}
              onChange={setStageCount}
              disabled={verifyMutation.isPending}
            />
            <span className="text-muted-foreground opacity-40">|</span>
          </div>
          {activeChain.map((model, index) => (
            <ModelSelector
              key={index}
              stageNumber={index + 1}
              selectedModel={model}
              onModelChange={(m) => updateModel(index, m)}
              disabled={verifyMutation.isPending}
            />
          ))}
          <div className="hidden sm:flex sm:items-center sm:ml-auto">
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

      <main
        ref={outputRef}
        className="flex-1 overflow-auto px-4 py-6 sm:px-8 sm:py-8"
        data-testid="terminal-output-area"
      >
        <div className="max-w-4xl mx-auto">
          <TerminalOutput
            query={query}
            stages={stages}
            summary={finalSummary}
            isProcessing={verifyMutation.isPending}
            expectedStageCount={stageCount}
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
    </div>
  );
}
