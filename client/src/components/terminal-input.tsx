import { useRef, useEffect, KeyboardEvent } from "react";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

interface TerminalInputProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  isProcessing: boolean;
}

export function TerminalInput({
  value,
  onChange,
  onSubmit,
  isProcessing,
}: TerminalInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 150)}px`;
    }
  }, [value]);

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      onSubmit();
    }
  };

  return (
    <div className="flex items-end gap-2 terminal-input-glow border border-transparent rounded-none px-1 transition-all">
      {/* Command-line style > prompt */}
      <span className="text-xs sm:text-sm text-primary/70 pb-2 shrink-0 font-bold">{">"}</span>
      <Textarea
        ref={textareaRef}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Enter your query..."
        disabled={isProcessing}
        aria-label="Query input"
        className="flex-1 min-w-0 resize-none bg-transparent border-0 rounded-none text-xs sm:text-sm focus-visible:ring-0 focus-visible:ring-offset-0 placeholder:text-muted-foreground/50"
        data-testid="input-query"
      />
      {/* EXECUTE button with terminal glow on hover */}
      <Button
        onClick={onSubmit}
        disabled={isProcessing || !value.trim()}
        variant="outline"
        size="sm"
        className="execute-btn text-xs rounded-none shrink-0 tracking-wider border-border"
        data-testid="button-submit"
      >
        {isProcessing ? "[...]" : "EXECUTE"}
      </Button>
    </div>
  );
}
