import { Link } from "wouter";

export default function ReadmePage() {
  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header
        className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-3 py-2 sm:px-4 sm:py-3"
        data-testid="header-readme"
      >
        <div className="flex items-center justify-between">
          <h1 className="text-sm font-medium">README.md</h1>
          <Link
            href="/"
            className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
            data-testid="link-terminal"
          >
            [TERMINAL]
          </Link>
        </div>
      </header>

      <main className="flex-1 overflow-auto px-3 py-4 sm:px-6 sm:py-6" data-testid="readme-content">
        <div className="max-w-3xl mx-auto space-y-6">
          <section>
            <h2 className="text-base font-medium mb-3 text-foreground">
              ═══════════════════════════════════════
            </h2>
            <h2 className="text-base font-medium mb-3 text-foreground">
              MULTI-LLM VERIFICATION TERMINAL
            </h2>
            <h2 className="text-base font-medium mb-4 text-foreground">
              ═══════════════════════════════════════
            </h2>
            <p className="text-sm text-muted-foreground leading-relaxed">
              A terminal-style verification system that runs your queries through multiple AI models 
              in sequence to detect hallucinations and distill truth from AI responses.
            </p>
          </section>

          <section>
            <h3 className="text-sm font-medium mb-2 text-foreground">&gt; HOW IT WORKS</h3>
            <div className="text-sm text-muted-foreground space-y-2 pl-4 border-l border-border">
              <p>
                <span className="text-foreground">1.</span> Your query enters <span className="text-foreground">Stage 1</span> - 
                the first LLM provides an initial response.
              </p>
              <p>
                <span className="text-foreground">2.</span> Each subsequent stage receives the previous output and is asked to:
              </p>
              <ul className="pl-4 space-y-1">
                <li>• Verify the accuracy of claims</li>
                <li>• Identify potential hallucinations</li>
                <li>• Correct any inaccuracies</li>
                <li>• Add missing information</li>
              </ul>
              <p>
                <span className="text-foreground">3.</span> The <span className="text-foreground">final stage</span> synthesizes 
                all inputs into a verified, refined response.
              </p>
              <p>
                <span className="text-foreground">4.</span> A <span className="text-foreground">verification summary</span> shows 
                the confidence level and cross-validation status.
              </p>
            </div>
          </section>

          <section>
            <h3 className="text-sm font-medium mb-2 text-foreground">&gt; AVAILABLE MODELS</h3>
            <div className="text-sm text-muted-foreground space-y-2 pl-4 border-l border-border">
              <p><span className="text-foreground">OpenAI:</span> gpt-4o, gpt-4o-mini, gpt-4-turbo</p>
              <p><span className="text-foreground">Anthropic:</span> claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5</p>
              <p><span className="text-foreground">Gemini:</span> gemini-2.5-flash, gemini-2.5-pro</p>
              <p><span className="text-foreground">xAI/Grok:</span> grok-3, grok-3-fast</p>
            </div>
          </section>

          <section>
            <h3 className="text-sm font-medium mb-2 text-foreground">&gt; USAGE INSTRUCTIONS</h3>
            <div className="text-sm text-muted-foreground space-y-2 pl-4 border-l border-border">
              <p>
                <span className="text-foreground">Step 1:</span> Select the number of verification stages (2-4) using the STAGES dropdown.
              </p>
              <p>
                <span className="text-foreground">Step 2:</span> Choose which LLM to use at each stage. Mixing different providers 
                (e.g., OpenAI → Anthropic → Gemini) provides better cross-validation.
              </p>
              <p>
                <span className="text-foreground">Step 3:</span> Enter your query in the input field at the bottom.
              </p>
              <p>
                <span className="text-foreground">Step 4:</span> Press Enter or click RUN to start the verification pipeline.
              </p>
              <p>
                <span className="text-foreground">Step 5:</span> Watch as each stage processes and streams its response in real-time.
              </p>
            </div>
          </section>

          <section>
            <h3 className="text-sm font-medium mb-2 text-foreground">&gt; VERIFICATION SUMMARY</h3>
            <div className="text-sm text-muted-foreground space-y-2 pl-4 border-l border-border">
              <p>After all stages complete, you'll see:</p>
              <ul className="pl-4 space-y-1">
                <li>• <span className="text-foreground">VERIFIED OUTPUT</span> - The final distilled response</li>
                <li>• <span className="text-foreground">Consistency</span> - Cross-verification status across LLMs</li>
                <li>• <span className="text-foreground">Hallucinations</span> - Whether potential issues were flagged</li>
                <li>• <span className="text-foreground">Confidence</span> - Overall verification confidence level</li>
              </ul>
            </div>
          </section>

          <section>
            <h3 className="text-sm font-medium mb-2 text-foreground">&gt; TIPS</h3>
            <div className="text-sm text-muted-foreground space-y-2 pl-4 border-l border-border">
              <p>
                • Use <span className="text-foreground">different providers</span> at each stage for maximum cross-validation.
              </p>
              <p>
                • <span className="text-foreground">More stages</span> = higher confidence but longer processing time.
              </p>
              <p>
                • For <span className="text-foreground">factual queries</span>, this system works best at catching errors.
              </p>
              <p>
                • <span className="text-foreground">Shift+Enter</span> allows multi-line input in the query field.
              </p>
            </div>
          </section>

          <section className="pt-4">
            <p className="text-xs text-muted-foreground opacity-60">
              ─────────────────────────────────────────────────
            </p>
            <p className="text-xs text-muted-foreground opacity-60 mt-2">
              Built with OpenAI, Anthropic, Google Gemini, and xAI APIs
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
