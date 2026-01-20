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
    <div className="flex items-end gap-2">
      <span className="text-sm text-muted-foreground pb-2">$</span>
      <Textarea
        ref={textareaRef}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Enter your query here..."
        disabled={isProcessing}
        aria-label="Query input"
        className="flex-1 resize-none bg-transparent border-0 rounded-none text-sm focus-visible:ring-0 focus-visible:ring-offset-0 placeholder:text-muted-foreground/50"
        data-testid="input-query"
      />
      <Button
        onClick={onSubmit}
        disabled={isProcessing || !value.trim()}
        variant="outline"
        size="sm"
        className="text-xs rounded-none"
        data-testid="button-submit"
      >
        {isProcessing ? "PROCESSING..." : "RUN"}
      </Button>
    </div>
  );
}
