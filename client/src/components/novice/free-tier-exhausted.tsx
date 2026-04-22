export function FreeTierExhausted() {
  return (
    <div className="max-w-md mx-auto text-center mt-16 space-y-4">
      <div className="text-xs text-amber-500 uppercase tracking-widest">[ FREE TIER EXHAUSTED ]</div>
      <p className="text-sm text-zinc-300">
        You've used your 3 free verifications. Add your own API keys in Pro mode to keep going.
      </p>
      <div className="flex flex-col items-center gap-2 text-xs text-zinc-400 pt-2">
        <a href="https://console.anthropic.com/settings/keys" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get an Anthropic key
        </a>
        <a href="https://aistudio.google.com/app/apikey" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get a Gemini key
        </a>
        <a href="https://console.x.ai/" target="_blank" rel="noreferrer" className="underline hover:text-zinc-100">
          Get an xAI key
        </a>
      </div>
      <a
        href="/pro"
        className="inline-block border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-6 py-3 text-sm mt-4"
      >
        Open Pro mode
      </a>
    </div>
  );
}
