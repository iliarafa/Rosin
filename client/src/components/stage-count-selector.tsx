import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

interface StageCountSelectorProps {
  value: number;
  onChange: (count: number) => void;
  disabled?: boolean;
}

export function StageCountSelector({
  value,
  onChange,
  disabled,
}: StageCountSelectorProps) {
  return (
    <div className="flex items-center gap-2" data-testid="stage-count-selector">
      <span className="text-xs text-muted-foreground">STAGES:</span>
      <Select
        value={String(value)}
        onValueChange={(val) => onChange(Number(val))}
        disabled={disabled}
      >
        <SelectTrigger
          className="w-[70px] text-xs bg-transparent border-border rounded-none"
          aria-label="Select number of verification stages"
          data-testid="select-trigger-stage-count"
        >
          <SelectValue />
        </SelectTrigger>
        <SelectContent className="font-mono text-xs rounded-none">
          <SelectItem value="2" className="text-xs rounded-none" data-testid="select-option-stages-2">
            2
          </SelectItem>
          <SelectItem value="3" className="text-xs rounded-none" data-testid="select-option-stages-3">
            3
          </SelectItem>
          <SelectItem value="4" className="text-xs rounded-none" data-testid="select-option-stages-4">
            4
          </SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
