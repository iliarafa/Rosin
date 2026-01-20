import { useState } from "react";
import { Link } from "wouter";

type Language = "en" | "gr";

const content = {
  en: {
    title: "LLM SEQUENCE RECOMMENDATIONS",
    problem: {
      title: "> THE PROBLEM",
      paragraphs: [
        "Large Language Models (LLMs) are powerful but prone to \"hallucinations\" - generating plausible-sounding but incorrect or fabricated information. A single LLM has no way to verify its own outputs.",
        "When an LLM makes a mistake, it often does so with complete confidence, making errors difficult to detect. Different LLMs have different training data, architectures, and biases - they make different mistakes.",
        "By chaining multiple LLMs together, we can leverage their differences to cross-validate information, catch errors, and distill a more reliable response.",
      ],
    },
    solution: {
      title: "> THE SOLUTION",
      text: "Multi-model verification works because:",
      points: [
        { highlight: "Different training data", text: " - Each provider trained on different datasets, reducing correlated errors." },
        { highlight: "Different architectures", text: " - Models reason differently, catching each other's blind spots." },
        { highlight: "Cross-validation", text: " - If multiple models agree, confidence increases; disagreements flag potential issues." },
        { highlight: "Iterative refinement", text: " - Each stage can correct and enhance the previous output." },
      ],
    },
    recommendations: {
      title: "> RECOMMENDED CONFIGURATIONS",
      intro: "Optimal model sequences for different use cases:",
      presets: [
        {
          name: "BALANCED (Recommended)",
          stages: [
            { num: "1", model: "gpt-4o", reason: "Fast, capable baseline response" },
            { num: "2", model: "claude-sonnet-4-5", reason: "Cross-provider verification" },
            { num: "3", model: "gemini-2.5-pro", reason: "Deep analysis and synthesis" },
            { num: "4", model: "grok-3", reason: "Final independent check" },
          ],
        },
        {
          name: "SPEED OPTIMIZED",
          stages: [
            { num: "1", model: "gpt-4o-mini", reason: "Fast initial response" },
            { num: "2", model: "gemini-2.5-flash", reason: "Quick cross-check" },
            { num: "3", model: "claude-haiku-4-5", reason: "Rapid synthesis" },
          ],
        },
        {
          name: "MAXIMUM ACCURACY",
          stages: [
            { num: "1", model: "gpt-4-turbo", reason: "Thorough initial analysis" },
            { num: "2", model: "claude-opus-4-5", reason: "Deep verification" },
            { num: "3", model: "gemini-2.5-pro", reason: "Comprehensive cross-check" },
            { num: "4", model: "gpt-4o", reason: "Final synthesis" },
          ],
        },
      ],
    },
    principles: {
      title: "> KEY PRINCIPLES",
      items: [
        { highlight: "Mix providers", text: " - Never use the same provider twice in a row. Cross-provider verification is essential." },
        { highlight: "Start fast, go deep", text: " - Use faster models early, more thorough models for later verification." },
        { highlight: "End with synthesis", text: " - The final stage should be good at summarizing and distilling information." },
        { highlight: "Match to task", text: " - Factual queries benefit from more stages; creative tasks may need fewer." },
      ],
    },
    stageRoles: {
      title: "> STAGE ROLES",
      roleLabel: "Role:",
      recommendedLabel: "Recommended:",
      stages: [
        { stage: "Stage 1 (Initial)", role: "Generate baseline response", recommended: "gpt-4o, gemini-2.5-flash" },
        { stage: "Stage 2 (Verify)", role: "Cross-check claims, flag errors", recommended: "claude-sonnet-4-5, grok-3" },
        { stage: "Stage 3 (Analyze)", role: "Deep analysis, find discrepancies", recommended: "claude-opus-4-5, gpt-4-turbo" },
        { stage: "Stage 4 (Synthesize)", role: "Distill final verified response", recommended: "gemini-2.5-pro, gpt-4o" },
      ],
    },
    footer: "Choose your configuration based on your priority: speed, accuracy, or balance.",
  },
  gr: {
    title: "ΣΥΣΤΑΣΕΙΣ ΑΚΟΛΟΥΘΙΑΣ LLM",
    problem: {
      title: "> ΤΟ ΠΡΟΒΛΗΜΑ",
      paragraphs: [
        "Τα Μεγάλα Γλωσσικά Μοντέλα (LLMs) είναι ισχυρά αλλά επιρρεπή σε \"ψευδαισθήσεις\" - δημιουργία πληροφοριών που ακούγονται πιστευτές αλλά είναι λανθασμένες ή κατασκευασμένες. Ένα μόνο LLM δεν έχει τρόπο να επαληθεύσει τις δικές του εξόδους.",
        "Όταν ένα LLM κάνει λάθος, συχνά το κάνει με απόλυτη σιγουριά, καθιστώντας τα σφάλματα δύσκολα να εντοπιστούν. Διαφορετικά LLMs έχουν διαφορετικά δεδομένα εκπαίδευσης, αρχιτεκτονικές και προκαταλήψεις - κάνουν διαφορετικά λάθη.",
        "Συνδέοντας πολλαπλά LLMs μαζί, μπορούμε να αξιοποιήσουμε τις διαφορές τους για διασταυρούμενη επικύρωση πληροφοριών, εντοπισμό σφαλμάτων και απόσταξη μιας πιο αξιόπιστης απάντησης.",
      ],
    },
    solution: {
      title: "> Η ΛΥΣΗ",
      text: "Η επαλήθευση πολλαπλών μοντέλων λειτουργεί επειδή:",
      points: [
        { highlight: "Διαφορετικά δεδομένα εκπαίδευσης", text: " - Κάθε πάροχος εκπαιδεύτηκε σε διαφορετικά σύνολα δεδομένων, μειώνοντας τα συσχετισμένα σφάλματα." },
        { highlight: "Διαφορετικές αρχιτεκτονικές", text: " - Τα μοντέλα σκέφτονται διαφορετικά, εντοπίζοντας τα τυφλά σημεία του άλλου." },
        { highlight: "Διασταυρούμενη επικύρωση", text: " - Αν πολλαπλά μοντέλα συμφωνούν, η εμπιστοσύνη αυξάνεται· οι διαφωνίες επισημαίνουν πιθανά προβλήματα." },
        { highlight: "Επαναληπτική βελτίωση", text: " - Κάθε στάδιο μπορεί να διορθώσει και να βελτιώσει την προηγούμενη έξοδο." },
      ],
    },
    recommendations: {
      title: "> ΣΥΝΙΣΤΩΜΕΝΕΣ ΔΙΑΜΟΡΦΩΣΕΙΣ",
      intro: "Βέλτιστες ακολουθίες μοντέλων για διαφορετικές περιπτώσεις χρήσης:",
      presets: [
        {
          name: "ΙΣΟΡΡΟΠΗΜΕΝΗ (Συνιστάται)",
          stages: [
            { num: "1", model: "gpt-4o", reason: "Γρήγορη, ικανή αρχική απάντηση" },
            { num: "2", model: "claude-sonnet-4-5", reason: "Επαλήθευση από διαφορετικό πάροχο" },
            { num: "3", model: "gemini-2.5-pro", reason: "Βαθιά ανάλυση και σύνθεση" },
            { num: "4", model: "grok-3", reason: "Τελικός ανεξάρτητος έλεγχος" },
          ],
        },
        {
          name: "ΒΕΛΤΙΣΤΟΠΟΙΗΜΕΝΗ ΓΙΑ ΤΑΧΥΤΗΤΑ",
          stages: [
            { num: "1", model: "gpt-4o-mini", reason: "Γρήγορη αρχική απάντηση" },
            { num: "2", model: "gemini-2.5-flash", reason: "Γρήγορος διασταυρούμενος έλεγχος" },
            { num: "3", model: "claude-haiku-4-5", reason: "Ταχεία σύνθεση" },
          ],
        },
        {
          name: "ΜΕΓΙΣΤΗ ΑΚΡΙΒΕΙΑ",
          stages: [
            { num: "1", model: "gpt-4-turbo", reason: "Ενδελεχής αρχική ανάλυση" },
            { num: "2", model: "claude-opus-4-5", reason: "Βαθιά επαλήθευση" },
            { num: "3", model: "gemini-2.5-pro", reason: "Ολοκληρωμένος διασταυρούμενος έλεγχος" },
            { num: "4", model: "gpt-4o", reason: "Τελική σύνθεση" },
          ],
        },
      ],
    },
    principles: {
      title: "> ΒΑΣΙΚΕΣ ΑΡΧΕΣ",
      items: [
        { highlight: "Ανάμειξη παρόχων", text: " - Ποτέ μην χρησιμοποιείτε τον ίδιο πάροχο δύο φορές στη σειρά. Η διασταυρούμενη επαλήθευση είναι απαραίτητη." },
        { highlight: "Ξεκινήστε γρήγορα, πηγαίνετε βαθιά", text: " - Χρησιμοποιήστε ταχύτερα μοντέλα στην αρχή, πιο ενδελεχή μοντέλα για μετέπειτα επαλήθευση." },
        { highlight: "Τελειώστε με σύνθεση", text: " - Το τελικό στάδιο πρέπει να είναι καλό στη σύνοψη και απόσταξη πληροφοριών." },
        { highlight: "Ταιριάξτε με την εργασία", text: " - Τα πραγματολογικά ερωτήματα επωφελούνται από περισσότερα στάδια· οι δημιουργικές εργασίες μπορεί να χρειάζονται λιγότερα." },
      ],
    },
    stageRoles: {
      title: "> ΡΟΛΟΙ ΣΤΑΔΙΩΝ",
      roleLabel: "Ρόλος:",
      recommendedLabel: "Συνιστώμενα:",
      stages: [
        { stage: "Στάδιο 1 (Αρχικό)", role: "Δημιουργία αρχικής απάντησης", recommended: "gpt-4o, gemini-2.5-flash" },
        { stage: "Στάδιο 2 (Επαλήθευση)", role: "Διασταυρούμενος έλεγχος, επισήμανση σφαλμάτων", recommended: "claude-sonnet-4-5, grok-3" },
        { stage: "Στάδιο 3 (Ανάλυση)", role: "Βαθιά ανάλυση, εύρεση αποκλίσεων", recommended: "claude-opus-4-5, gpt-4-turbo" },
        { stage: "Στάδιο 4 (Σύνθεση)", role: "Απόσταξη τελικής επαληθευμένης απάντησης", recommended: "gemini-2.5-pro, gpt-4o" },
      ],
    },
    footer: "Επιλέξτε τη διαμόρφωσή σας με βάση την προτεραιότητά σας: ταχύτητα, ακρίβεια ή ισορροπία.",
  },
};

export default function RecommendationsPage() {
  const [lang, setLang] = useState<Language>("en");
  const t = content[lang];

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-mono">
      <header
        className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-sm px-3 py-2 sm:px-4 sm:py-3"
        data-testid="header-recommendations"
      >
        <div className="flex items-center justify-between">
          <h1 className="text-sm font-medium">GUIDE.md</h1>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setLang(lang === "en" ? "gr" : "en")}
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
              data-testid="button-language-toggle"
            >
              [{lang === "en" ? "EN" : "GR"}]
            </button>
            <Link
              href="/readme"
              className="text-xs text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border rounded-none"
              data-testid="link-readme"
            >
              [README]
            </Link>
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

      <main className="flex-1 overflow-auto px-3 py-4 sm:px-6 sm:py-6" data-testid="recommendations-content">
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
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.problem.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-3 pl-3 sm:pl-4 border-l border-border">
              {t.problem.paragraphs.map((para, i) => (
                <p key={i} className="leading-relaxed">{para}</p>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.solution.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              <p>{t.solution.text}</p>
              <ul className="space-y-1 pl-3 sm:pl-4">
                {t.solution.points.map((point, i) => (
                  <li key={i}>
                    • <span className="text-foreground">{point.highlight}</span>{point.text}
                  </li>
                ))}
              </ul>
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.recommendations.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-4 pl-3 sm:pl-4 border-l border-border">
              <p>{t.recommendations.intro}</p>
              {t.recommendations.presets.map((preset, i) => (
                <div key={i} className="space-y-2">
                  <p className="text-foreground font-medium">{preset.name}</p>
                  <ul className="space-y-1 pl-3 sm:pl-4">
                    {preset.stages.map((stage, j) => (
                      <li key={j}>
                        <span className="text-foreground">[{stage.num}]</span> {stage.model} - <span className="opacity-80">{stage.reason}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.principles.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              {t.principles.items.map((item, i) => (
                <p key={i}>
                  • <span className="text-foreground">{item.highlight}</span>{item.text}
                </p>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-xs sm:text-sm font-medium mb-2 text-foreground">{t.stageRoles.title}</h3>
            <div className="text-xs sm:text-sm text-muted-foreground space-y-2 pl-3 sm:pl-4 border-l border-border">
              {t.stageRoles.stages.map((item, i) => (
                <div key={i}>
                  <p><span className="text-foreground">{item.stage}</span></p>
                  <p className="pl-3 sm:pl-4 opacity-80">{t.stageRoles.roleLabel} {item.role}</p>
                  <p className="pl-3 sm:pl-4 opacity-80">{t.stageRoles.recommendedLabel} {item.recommended}</p>
                </div>
              ))}
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
