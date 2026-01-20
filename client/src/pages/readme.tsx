import { useState } from "react";
import { Link } from "wouter";

type Language = "en" | "gr";

const content = {
  en: {
    title: "MULTI-LLM VERIFICATION TERMINAL",
    description: "A terminal-style verification system that runs your queries through multiple AI models in sequence to detect hallucinations and distill truth from AI responses.",
    howItWorks: {
      title: "> HOW IT WORKS",
      steps: [
        { num: "1.", text: "Your query enters", highlight: "Stage 1", after: " - the first LLM provides an initial response." },
        { num: "2.", text: "Each subsequent stage receives the previous output and is asked to:", highlight: "", after: "" },
      ],
      bullets: [
        "Verify the accuracy of claims",
        "Identify potential hallucinations",
        "Correct any inaccuracies",
        "Add missing information",
      ],
      step3: { num: "3.", text: "The", highlight: "final stage", after: " synthesizes all inputs into a verified, refined response." },
      step4: { num: "4.", text: "A", highlight: "verification summary", after: " shows the confidence level and cross-validation status." },
    },
    models: {
      title: "> AVAILABLE MODELS",
      openai: "gpt-4o, gpt-4o-mini, gpt-4-turbo",
      anthropic: "claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5",
      gemini: "gemini-2.5-flash, gemini-2.5-pro",
      xai: "grok-3, grok-3-fast",
    },
    usage: {
      title: "> USAGE INSTRUCTIONS",
      steps: [
        { step: "Step 1:", text: "Select the number of verification stages (2-4) using the STAGES dropdown." },
        { step: "Step 2:", text: "Choose which LLM to use at each stage. Mixing different providers (e.g., OpenAI → Anthropic → Gemini) provides better cross-validation." },
        { step: "Step 3:", text: "Enter your query in the input field at the bottom." },
        { step: "Step 4:", text: "Press Enter or click RUN to start the verification pipeline." },
        { step: "Step 5:", text: "Watch as each stage processes and streams its response in real-time." },
      ],
    },
    summary: {
      title: "> VERIFICATION SUMMARY",
      intro: "After all stages complete, you'll see:",
      items: [
        { label: "VERIFIED OUTPUT", text: " - The final distilled response" },
        { label: "Consistency", text: " - Cross-verification status across LLMs" },
        { label: "Hallucinations", text: " - Whether potential issues were flagged" },
        { label: "Confidence", text: " - Overall verification confidence level" },
      ],
    },
    homeScreen: {
      title: "> ADD TO HOME SCREEN",
      iphone: {
        label: "iPhone / iPad:",
        steps: [
          { num: "1.", text: "Tap the", highlight: "Share", after: " button (square with arrow)" },
          { num: "2.", text: "Scroll down and tap", highlight: '"Add to Home Screen"', after: "" },
          { num: "3.", text: "Tap", highlight: '"Add"', after: " in the top right" },
        ],
      },
      android: {
        label: "Android (Chrome):",
        steps: [
          { num: "1.", text: "Tap the", highlight: "menu", after: " button (three dots)" },
          { num: "2.", text: "Tap", highlight: '"Add to Home screen"', after: "" },
          { num: "3.", text: "Tap", highlight: '"Add"', after: " to confirm" },
        ],
      },
      note: "The app will appear on your home screen with the ROSIN icon for quick access.",
    },
    tips: {
      title: "> TIPS",
      items: [
        { text: "Use", highlight: "different providers", after: " at each stage for maximum cross-validation." },
        { highlight: "More stages", after: " = higher confidence but longer processing time." },
        { text: "For", highlight: "factual queries", after: ", this system works best at catching errors." },
        { highlight: "Shift+Enter", after: " allows multi-line input in the query field." },
      ],
    },
    footer: "Built with OpenAI, Anthropic, Google Gemini, and xAI APIs",
  },
  gr: {
    title: "ΤΕΡΜΑΤΙΚΟ ΕΠΑΛΗΘΕΥΣΗΣ ΠΟΛΛΑΠΛΩΝ LLM",
    description: "Ένα σύστημα επαλήθευσης τύπου τερματικού που εκτελεί τα ερωτήματά σας μέσω πολλαπλών μοντέλων AI σε σειρά για να ανιχνεύσει ψευδαισθήσεις και να εξαγάγει την αλήθεια από τις απαντήσεις AI.",
    howItWorks: {
      title: "> ΠΩΣ ΛΕΙΤΟΥΡΓΕΙ",
      steps: [
        { num: "1.", text: "Το ερώτημά σας εισέρχεται στο", highlight: "Στάδιο 1", after: " - το πρώτο LLM παρέχει μια αρχική απάντηση." },
        { num: "2.", text: "Κάθε επόμενο στάδιο λαμβάνει την προηγούμενη έξοδο και καλείται να:", highlight: "", after: "" },
      ],
      bullets: [
        "Επαληθεύσει την ακρίβεια των ισχυρισμών",
        "Εντοπίσει πιθανές ψευδαισθήσεις",
        "Διορθώσει τυχόν ανακρίβειες",
        "Προσθέσει πληροφορίες που λείπουν",
      ],
      step3: { num: "3.", text: "Το", highlight: "τελικό στάδιο", after: " συνθέτει όλες τις εισόδους σε μια επαληθευμένη, βελτιωμένη απάντηση." },
      step4: { num: "4.", text: "Μια", highlight: "σύνοψη επαλήθευσης", after: " δείχνει το επίπεδο εμπιστοσύνης και την κατάσταση διασταυρούμενης επικύρωσης." },
    },
    models: {
      title: "> ΔΙΑΘΕΣΙΜΑ ΜΟΝΤΕΛΑ",
      openai: "gpt-4o, gpt-4o-mini, gpt-4-turbo",
      anthropic: "claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5",
      gemini: "gemini-2.5-flash, gemini-2.5-pro",
      xai: "grok-3, grok-3-fast",
    },
    usage: {
      title: "> ΟΔΗΓΙΕΣ ΧΡΗΣΗΣ",
      steps: [
        { step: "Βήμα 1:", text: "Επιλέξτε τον αριθμό σταδίων επαλήθευσης (2-4) χρησιμοποιώντας το αναπτυσσόμενο μενού ΣΤΑΔΙΑ." },
        { step: "Βήμα 2:", text: "Επιλέξτε ποιο LLM θα χρησιμοποιήσετε σε κάθε στάδιο. Η ανάμειξη διαφορετικών παρόχων (π.χ., OpenAI → Anthropic → Gemini) παρέχει καλύτερη διασταυρούμενη επικύρωση." },
        { step: "Βήμα 3:", text: "Εισάγετε το ερώτημά σας στο πεδίο εισόδου στο κάτω μέρος." },
        { step: "Βήμα 4:", text: "Πατήστε Enter ή κάντε κλικ στο ΕΚΤΕΛΕΣΗ για να ξεκινήσει η διαδικασία επαλήθευσης." },
        { step: "Βήμα 5:", text: "Παρακολουθήστε καθώς κάθε στάδιο επεξεργάζεται και μεταδίδει την απάντησή του σε πραγματικό χρόνο." },
      ],
    },
    summary: {
      title: "> ΣΥΝΟΨΗ ΕΠΑΛΗΘΕΥΣΗΣ",
      intro: "Μετά την ολοκλήρωση όλων των σταδίων, θα δείτε:",
      items: [
        { label: "ΕΠΑΛΗΘΕΥΜΕΝΗ ΕΞΟΔΟΣ", text: " - Η τελική αποσταγμένη απάντηση" },
        { label: "Συνέπεια", text: " - Κατάσταση διασταυρούμενης επικύρωσης μεταξύ LLMs" },
        { label: "Ψευδαισθήσεις", text: " - Αν επισημάνθηκαν πιθανά προβλήματα" },
        { label: "Εμπιστοσύνη", text: " - Συνολικό επίπεδο εμπιστοσύνης επαλήθευσης" },
      ],
    },
    homeScreen: {
      title: "> ΠΡΟΣΘΗΚΗ ΣΤΗΝ ΑΡΧΙΚΗ ΟΘΟΝΗ",
      iphone: {
        label: "iPhone / iPad:",
        steps: [
          { num: "1.", text: "Πατήστε το κουμπί", highlight: "Κοινοποίηση", after: " (τετράγωνο με βέλος)" },
          { num: "2.", text: "Κάντε κύλιση προς τα κάτω και πατήστε", highlight: '"Προσθήκη στην Αρχική Οθόνη"', after: "" },
          { num: "3.", text: "Πατήστε", highlight: '"Προσθήκη"', after: " πάνω δεξιά" },
        ],
      },
      android: {
        label: "Android (Chrome):",
        steps: [
          { num: "1.", text: "Πατήστε το κουμπί", highlight: "μενού", after: " (τρεις τελείες)" },
          { num: "2.", text: "Πατήστε", highlight: '"Προσθήκη στην αρχική οθόνη"', after: "" },
          { num: "3.", text: "Πατήστε", highlight: '"Προσθήκη"', after: " για επιβεβαίωση" },
        ],
      },
      note: "Η εφαρμογή θα εμφανιστεί στην αρχική σας οθόνη με το εικονίδιο ROSIN για γρήγορη πρόσβαση.",
    },
    tips: {
      title: "> ΣΥΜΒΟΥΛΕΣ",
      items: [
        { text: "Χρησιμοποιήστε", highlight: "διαφορετικούς παρόχους", after: " σε κάθε στάδιο για μέγιστη διασταυρούμενη επικύρωση." },
        { highlight: "Περισσότερα στάδια", after: " = υψηλότερη εμπιστοσύνη αλλά μεγαλύτερος χρόνος επεξεργασίας." },
        { text: "Για", highlight: "πραγματολογικά ερωτήματα", after: ", αυτό το σύστημα λειτουργεί καλύτερα στον εντοπισμό σφαλμάτων." },
        { highlight: "Shift+Enter", after: " επιτρέπει εισαγωγή πολλαπλών γραμμών στο πεδίο ερωτήματος." },
      ],
    },
    footer: "Κατασκευασμένο με OpenAI, Anthropic, Google Gemini και xAI APIs",
  },
};

export default function ReadmePage() {
  const [lang, setLang] = useState<Language>("en");
  const t = content[lang];

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header
        className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-3 py-2 sm:px-4 sm:py-3"
        data-testid="header-readme"
      >
        <div className="flex items-center justify-between">
          <h1 className="text-sm font-medium">README.md</h1>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setLang(lang === "en" ? "gr" : "en")}
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
              data-testid="button-language-toggle"
            >
              [{lang === "en" ? "EN" : "GR"}]
            </button>
            <Link
              href="/"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
              data-testid="link-terminal"
            >
              [TERMINAL]
            </Link>
          </div>
        </div>
      </header>

      <main className="flex-1 overflow-auto px-3 py-4 sm:px-6 sm:py-6" data-testid="readme-content">
        <div className="max-w-3xl mx-auto space-y-4 sm:space-y-6">
          <section>
            <h2 className="text-xs sm:text-base font-medium mb-2 sm:mb-3 text-foreground">
              ═══════════════════════════════════════
            </h2>
            <h2 className="text-xs sm:text-base font-medium mb-2 sm:mb-3 text-foreground">
              {t.title}
            </h2>
            <h2 className="text-xs sm:text-base font-medium mb-3 sm:mb-4 text-foreground">
              ═══════════════════════════════════════
            </h2>
            <p className="text-xs sm:text-sm text-muted-foreground leading-relaxed">
              {t.description}
            </p>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.howItWorks.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              {t.howItWorks.steps.map((step, i) => (
                <p key={i}>
                  <span className="text-foreground">{step.num}</span> {step.text}{" "}
                  {step.highlight && <span className="text-foreground">{step.highlight}</span>}
                  {step.after}
                </p>
              ))}
              <ul className="pl-4 space-y-1">
                {t.howItWorks.bullets.map((bullet, i) => (
                  <li key={i}>• {bullet}</li>
                ))}
              </ul>
              <p>
                <span className="text-foreground">{t.howItWorks.step3.num}</span> {t.howItWorks.step3.text}{" "}
                <span className="text-foreground">{t.howItWorks.step3.highlight}</span>
                {t.howItWorks.step3.after}
              </p>
              <p>
                <span className="text-foreground">{t.howItWorks.step4.num}</span> {t.howItWorks.step4.text}{" "}
                <span className="text-foreground">{t.howItWorks.step4.highlight}</span>
                {t.howItWorks.step4.after}
              </p>
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.models.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              <p><span className="text-foreground">OpenAI:</span> {t.models.openai}</p>
              <p><span className="text-foreground">Anthropic:</span> {t.models.anthropic}</p>
              <p><span className="text-foreground">Gemini:</span> {t.models.gemini}</p>
              <p><span className="text-foreground">xAI/Grok:</span> {t.models.xai}</p>
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.usage.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              {t.usage.steps.map((step, i) => (
                <p key={i}>
                  <span className="text-foreground">{step.step}</span> {step.text}
                </p>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.summary.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              <p>{t.summary.intro}</p>
              <ul className="pl-3 sm:pl-4 space-y-1">
                {t.summary.items.map((item, i) => (
                  <li key={i}>• <span className="text-foreground">{item.label}</span>{item.text}</li>
                ))}
              </ul>
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.homeScreen.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-3 pl-3 sm:pl-4 border-l border-border">
              <div>
                <p className="text-foreground mb-1">{t.homeScreen.iphone.label}</p>
                <ul className="pl-3 sm:pl-4 space-y-1">
                  {t.homeScreen.iphone.steps.map((step, i) => (
                    <li key={i}>
                      {step.num} {step.text} <span className="text-foreground">{step.highlight}</span>{step.after}
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <p className="text-foreground mb-1">{t.homeScreen.android.label}</p>
                <ul className="pl-3 sm:pl-4 space-y-1">
                  {t.homeScreen.android.steps.map((step, i) => (
                    <li key={i}>
                      {step.num} {step.text} <span className="text-foreground">{step.highlight}</span>{step.after}
                    </li>
                  ))}
                </ul>
              </div>
              <p className="opacity-80">{t.homeScreen.note}</p>
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.tips.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              {t.tips.items.map((tip, i) => (
                <p key={i}>
                  • {tip.text && <>{tip.text} </>}
                  <span className="text-foreground">{tip.highlight}</span>
                  {tip.after}
                </p>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{lang === "en" ? "> MODEL RECOMMENDATIONS" : "> ΣΥΣΤΑΣΕΙΣ ΜΟΝΤΕΛΩΝ"}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              <p>
                {lang === "en" 
                  ? "Learn which LLM sequences work best for different use cases."
                  : "Μάθετε ποιες ακολουθίες LLM λειτουργούν καλύτερα για διαφορετικές περιπτώσεις χρήσης."}
              </p>
              <Link
                href="/recommendations"
                className="inline-block mt-2 text-xs text-foreground hover:text-muted-foreground transition-colors px-3 py-2 border border-border rounded-none"
                data-testid="link-recommendations"
              >
                [{lang === "en" ? "VIEW RECOMMENDATIONS" : "ΔΕΙΤΕ ΣΥΣΤΑΣΕΙΣ"}]
              </Link>
            </div>
          </section>

          <section className="pt-4">
            <p className="text-xs text-muted-foreground opacity-60">
              ─────────────────────────────────────────────────
            </p>
            <p className="text-xs text-muted-foreground opacity-60 mt-2">
              {t.footer}
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
