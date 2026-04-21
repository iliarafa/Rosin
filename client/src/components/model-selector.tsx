import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { type LLMModel, type LLMProvider, llmModels, llmProviders } from "@shared/schema";

interface ModelSelectorProps {
  stageNumber: number;
  selectedModel: LLMModel;
  onModelChange: (model: LLMModel) => void;
  disabled?: boolean;
  isActive?: boolean;
}

const providerLabels: Record<LLMProvider, string> = {
  anthropic: "Anthropic",
  gemini: "Gemini",
  xai: "xAI/Grok",
};

/* ── Tiny SVG icons for each provider (14x14) ── */
function ProviderIcon({ provider }: { provider: LLMProvider }) {
  const cls = "w-3.5 h-3.5 shrink-0 opacity-70";
  switch (provider) {
    case "anthropic":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="currentColor">
          <path d="M17.304 3.541l-5.304 16.359-5.304-16.359h-3.396l7.2 20.459h3l7.2-20.459z" />
        </svg>
      );
    case "gemini":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 24A14.304 14.304 0 000 12 14.304 14.304 0 0012 0a14.304 14.304 0 0012 12 14.304 14.304 0 00-12 12z" />
        </svg>
      );
    case "xai":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="currentColor">
          <path d="M2.2 2l7.5 10.5L2 22h1.7l6.9-8.5L17.2 22H22l-7.8-11L21.7 2H20l-6.6 8.1L7 2z" />
        </svg>
      );
  }
}

export function ModelSelector({
  stageNumber,
  selectedModel,
  onModelChange,
  disabled,
  isActive,
}: ModelSelectorProps) {
  const allModels = llmProviders.flatMap((provider) =>
    llmModels[provider].map((model) => ({
      provider,
      model,
      label: `${providerLabels[provider]} - ${model}`,
    }))
  );

  const currentValue = `${selectedModel.provider}:${selectedModel.model}`;

  return (
    <div
      className={`flex items-center gap-1 sm:gap-2 transition-all duration-300 ${
        isActive
          ? "ring-1 ring-primary/40 shadow-[0_0_8px_hsl(var(--primary)/0.2)]"
          : ""
      }`}
      data-testid={`model-selector-stage-${stageNumber}`}
    >
      <span className="text-xs text-muted-foreground opacity-80">[{stageNumber}]</span>
      <Select
        value={currentValue}
        onValueChange={(val) => {
          const [provider, model] = val.split(":") as [LLMProvider, string];
          onModelChange({ provider, model });
        }}
        disabled={disabled}
      >
        <SelectTrigger
          className="w-full min-w-[120px] sm:w-[200px] text-xs bg-transparent border-border rounded-none"
          aria-label={`Select LLM for Stage ${stageNumber}`}
          data-testid={`select-trigger-stage-${stageNumber}`}
        >
          <SelectValue />
        </SelectTrigger>
        <SelectContent className="font-mono text-xs rounded-none">
          {allModels.map((m) => (
            <SelectItem
              key={`${m.provider}:${m.model}`}
              value={`${m.provider}:${m.model}`}
              className="text-xs rounded-none"
              data-testid={`select-option-${m.provider}-${m.model}`}
            >
              <span className="inline-flex items-center gap-1.5">
                <ProviderIcon provider={m.provider} />
                {m.label}
              </span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
