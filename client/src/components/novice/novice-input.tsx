import { useState, useRef, KeyboardEvent } from "react";

interface NoviceInputProps {
  onSubmit: (query: string) => void;
  disabled?: boolean;
}

export function NoviceInput({ onSubmit, disabled }: NoviceInputProps) {
  const [value, setValue] = useState("");
  const inputRef = useRef<HTMLTextAreaElement>(null);

  function handleKey(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }

  function submit() {
    const trimmed = value.trim();
    if (!trimmed || disabled) return;
    onSubmit(trimmed);
  }

  return (
    <div className="w-full max-w-2xl mx-auto font-mono">
      <div className="text-center text-sm text-zinc-400 mb-3">
        Ask a question. We'll verify it across multiple AIs.
      </div>
      <div className="border border-zinc-800 rounded bg-black px-4 py-3 flex items-start gap-2 focus-within:border-green-500/60 transition-colors">
        <span className="text-green-500 shrink-0 mt-0.5">&gt;</span>
        <textarea
          ref={inputRef}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={handleKey}
          disabled={disabled}
          autoFocus
          rows={2}
          className="flex-1 bg-transparent outline-none resize-none text-zinc-100 placeholder:text-zinc-600"
          placeholder="e.g. Is creatine safe for teenagers?"
          data-testid="novice-input"
        />
      </div>
      <div className="flex justify-center mt-4">
        <button
          onClick={submit}
          disabled={disabled || !value.trim()}
          className="border border-green-500 text-green-500 px-6 py-2 text-sm tracking-widest disabled:opacity-40 hover:bg-green-500/10 transition-colors"
          data-testid="novice-verify"
        >
          [ VERIFY ]
        </button>
      </div>
    </div>
  );
}
