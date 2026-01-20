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
}

const providerLabels: Record<LLMProvider, string> = {
  openai: "OpenAI",
  anthropic: "Anthropic",
  gemini: "Gemini",
  xai: "xAI/Grok",
};

export function ModelSelector({
  stageNumber,
  selectedModel,
  onModelChange,
  disabled,
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
    <div className="flex items-center gap-2" data-testid={`model-selector-stage-${stageNumber}`}>
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
          className="w-[200px] text-xs bg-transparent border-border rounded-none"
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
              {m.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
