import SwiftUI

struct ReadmeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var language: Language = .english

    enum Language: String, CaseIterable {
        case english = "EN"
        case greek = "GR"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Language toggle
                    HStack {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Button {
                                language = lang
                            } label: {
                                Text("[\(lang.rawValue)]")
                                    .font(RosinTheme.monoCaption)
                                    .foregroundColor(language == lang ? .primary : RosinTheme.muted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .overlay(
                                        Rectangle()
                                            .stroke(
                                                language == lang ? Color.primary : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    }

                    if language == .english {
                        englishContent
                    } else {
                        greekContent
                    }
                }
                .padding()
            }
            .navigationTitle("README")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(RosinTheme.monoCaption)
                }
            }
        }
        .font(RosinTheme.monoCaption)
    }

    private var englishContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("ROSIN \u{2013} PURE OUTPUT")

            bodyText("""
            ROSIN is a multi-LLM verification tool that combats AI hallucinations by \
            running your query through multiple language models in sequence. Each model \
            verifies and refines the previous output, distilling truth through consensus.
            """)

            sectionTitle("HOW IT WORKS")

            bodyText("""
            1. Enter your query in the terminal input
            2. Select 2 or 3 verification stages
            3. Choose which LLM model to use for each stage
            4. Press RUN \u{2013} each stage streams in real-time
            5. The final output represents the verified, consensus answer
            """)

            sectionTitle("SUPPORTED PROVIDERS")

            bodyText("""
            \u{2022} Anthropic (Claude): claude-sonnet-4-5, claude-haiku-4-5, claude-opus-4-5
            \u{2022} Google Gemini: gemini-2.5-flash, gemini-2.5-pro
            \u{2022} xAI (Grok): grok-3, grok-3-fast
            """)

            sectionTitle("API KEYS")

            bodyText("""
            Your API keys are stored securely in the iOS Keychain with the most \
            restrictive access policy (kSecAttrAccessibleWhenUnlockedThisDeviceOnly). \
            Keys never leave your device and are not included in backups.

            Tap [\u{00B7}\u{00B7}\u{00B7}] \u{2192} Settings to manage your API keys.
            """)

            sectionTitle("EXPORT")

            bodyText("""
            After verification completes, you can export results as CSV or PDF \
            using the export buttons below the verified output.
            """)

            sectionTitle("LIVE RESEARCH")

            bodyText("""
            LLMs have a knowledge cutoff \u{2013} they cannot access current information on \
            their own. ROSIN solves this with Live Research, powered by Tavily, a search \
            API purpose-built for AI applications.

            When [LIVE] is enabled, ROSIN searches the web for real-time results before \
            the verification pipeline begins. These results are injected into Stage 1, \
            grounding the response in current facts. Subsequent stages then verify the \
            web-grounded information against their own knowledge \u{2013} giving you multi-LLM \
            verification of fresh, up-to-date data.

            To enable Live Research:
            1. Get a free Tavily API key at tavily.com
            2. Add it in [\u{00B7}\u{00B7}\u{00B7}] \u{2192} Settings \u{2192} Web Search
            3. Toggle [LIVE] in the header before running a query
            """)

            sectionTitle("HEADER CONTROLS")

            bodyText("""
            \u{2022} [LIVE] \u{2013} Toggle live web search (Tavily) for current information
            \u{2022} [ADV] \u{2013} Adversarial mode \u{2013} stages aggressively challenge prior output
            \u{2022} [\u{00B7}\u{00B7}\u{00B7}] \u{2013} Menu: History, Stats, Recommendations, Readme, Settings, Theme
            """)

            sectionTitle("WHY \"ROSIN\"?")

            bodyText("""
            Rosin is a purified form of resin \u{2013} just as rosin extracts pure \
            substance from raw material, this tool extracts verified truth from \
            multiple AI outputs. The name also references the Greek word for "pure flow."
            """)
        }
    }

    private var greekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("ROSIN \u{2013} \u{039A}\u{0391}\u{0398}\u{0391}\u{03A1}\u{0397} \u{0395}\u{039E}\u{039F}\u{0394}\u{039F}\u{03A3}")

            bodyText("""
            \u{03A4}\u{03BF} ROSIN \u{03B5}\u{03AF}\u{03BD}\u{03B1}\u{03B9} \u{03AD}\u{03BD}\u{03B1} \u{03B5}\u{03C1}\u{03B3}\u{03B1}\u{03BB}\u{03B5}\u{03AF}\u{03BF} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03C5}\u{03C3}\u{03B7}\u{03C2} \u{03C0}\u{03BF}\u{03BB}\u{03BB}\u{03B1}\u{03C0}\u{03BB}\u{03CE}\u{03BD} LLM \u{03C0}\u{03BF}\u{03C5} \u{03BA}\u{03B1}\u{03C4}\u{03B1}\u{03C0}\u{03BF}\u{03BB}\u{03B5}\u{03BC}\u{03AC} \u{03C4}\u{03B9}\u{03C2} \u{03C8}\u{03B5}\u{03C5}\u{03B4}\u{03B1}\u{03B9}\u{03C3}\u{03B8}\u{03AE}\u{03C3}\u{03B5}\u{03B9}\u{03C2} \
            \u{03C4}\u{03B7}\u{03C2} \u{03C4}\u{03B5}\u{03C7}\u{03BD}\u{03B7}\u{03C4}\u{03AE}\u{03C2} \u{03BD}\u{03BF}\u{03B7}\u{03BC}\u{03BF}\u{03C3}\u{03CD}\u{03BD}\u{03B7}\u{03C2} \u{03C0}\u{03B5}\u{03C1}\u{03BD}\u{03CE}\u{03BD}\u{03C4}\u{03B1}\u{03C2} \u{03C4}\u{03BF} \u{03B5}\u{03C1}\u{03CE}\u{03C4}\u{03B7}\u{03BC}\u{03AC} \u{03C3}\u{03B1}\u{03C2} \u{03B1}\u{03C0}\u{03CC} \u{03C0}\u{03BF}\u{03BB}\u{03BB}\u{03B1}\u{03C0}\u{03BB}\u{03AC} \u{03B3}\u{03BB}\u{03C9}\u{03C3}\u{03C3}\u{03B9}\u{03BA}\u{03AC} \
            \u{03BC}\u{03BF}\u{03BD}\u{03C4}\u{03AD}\u{03BB}\u{03B1} \u{03B4}\u{03B9}\u{03B1}\u{03B4}\u{03BF}\u{03C7}\u{03B9}\u{03BA}\u{03AC}. \u{039A}\u{03AC}\u{03B8}\u{03B5} \u{03BC}\u{03BF}\u{03BD}\u{03C4}\u{03AD}\u{03BB}\u{03BF} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03B7}\u{03B8}\u{03B5}\u{03CD}\u{03B5}\u{03B9} \u{03BA}\u{03B1}\u{03B9} \u{03B2}\u{03B5}\u{03BB}\u{03C4}\u{03B9}\u{03CE}\u{03BD}\u{03B5}\u{03B9} \u{03C4}\u{03B7}\u{03BD} \u{03C0}\u{03C1}\u{03BF}\u{03B7}\u{03B3}\u{03BF}\u{03CD}\u{03BC}\u{03B5}\u{03BD}\u{03B7} \u{03AD}\u{03BE}\u{03BF}\u{03B4}\u{03BF}.
            """)

            sectionTitle("\u{03A0}\u{03A9}\u{03A3} \u{039B}\u{0395}\u{0399}\u{03A4}\u{039F}\u{03A5}\u{03A1}\u{0393}\u{0395}\u{0399}")

            bodyText("""
            1. \u{0395}\u{03B9}\u{03C3}\u{03AC}\u{03B3}\u{03B5}\u{03C4}\u{03B5} \u{03C4}\u{03BF} \u{03B5}\u{03C1}\u{03CE}\u{03C4}\u{03B7}\u{03BC}\u{03AC} \u{03C3}\u{03B1}\u{03C2}
            2. \u{0395}\u{03C0}\u{03B9}\u{03BB}\u{03AD}\u{03BE}\u{03C4}\u{03B5} 2 \u{03AE} 3 \u{03C3}\u{03C4}\u{03AC}\u{03B4}\u{03B9}\u{03B1} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03C5}\u{03C3}\u{03B7}\u{03C2}
            3. \u{0395}\u{03C0}\u{03B9}\u{03BB}\u{03AD}\u{03BE}\u{03C4}\u{03B5} \u{03BC}\u{03BF}\u{03BD}\u{03C4}\u{03AD}\u{03BB}\u{03BF} \u{03B3}\u{03B9}\u{03B1} \u{03BA}\u{03AC}\u{03B8}\u{03B5} \u{03C3}\u{03C4}\u{03AC}\u{03B4}\u{03B9}\u{03BF}
            4. \u{03A0}\u{03B1}\u{03C4}\u{03AE}\u{03C3}\u{03C4}\u{03B5} RUN
            5. \u{0397} \u{03C4}\u{03B5}\u{03BB}\u{03B9}\u{03BA}\u{03AE} \u{03AD}\u{03BE}\u{03BF}\u{03B4}\u{03BF}\u{03C2} \u{03B5}\u{03AF}\u{03BD}\u{03B1}\u{03B9} \u{03B7} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03B7}\u{03B8}\u{03B5}\u{03C5}\u{03BC}\u{03AD}\u{03BD}\u{03B7} \u{03B1}\u{03C0}\u{03AC}\u{03BD}\u{03C4}\u{03B7}\u{03C3}\u{03B7}
            """)

            sectionTitle("\u{039A}\u{039B}\u{0395}\u{0399}\u{0394}\u{0399}\u{0391} API")

            bodyText("""
            \u{03A4}\u{03B1} \u{03BA}\u{03BB}\u{03B5}\u{03B9}\u{03B4}\u{03B9}\u{03AC} API \u{03B1}\u{03C0}\u{03BF}\u{03B8}\u{03B7}\u{03BA}\u{03B5}\u{03CD}\u{03BF}\u{03BD}\u{03C4}\u{03B1}\u{03B9} \u{03BC}\u{03B5} \u{03B1}\u{03C3}\u{03C6}\u{03AC}\u{03BB}\u{03B5}\u{03B9}\u{03B1} \u{03C3}\u{03C4}\u{03BF} iOS Keychain. \
            \u{0394}\u{03B5}\u{03BD} \u{03C6}\u{03B5}\u{03CD}\u{03B3}\u{03BF}\u{03C5}\u{03BD} \u{03C0}\u{03BF}\u{03C4}\u{03AD} \u{03B1}\u{03C0}\u{03CC} \u{03C4}\u{03B7} \u{03C3}\u{03C5}\u{03C3}\u{03BA}\u{03B5}\u{03C5}\u{03AE} \u{03C3}\u{03B1}\u{03C2} \u{03BA}\u{03B1}\u{03B9} \u{03B4}\u{03B5}\u{03BD} \u{03C3}\u{03C5}\u{03BC}\u{03C0}\u{03B5}\u{03C1}\u{03B9}\u{03BB}\u{03B1}\u{03BC}\u{03B2}\u{03AC}\u{03BD}\u{03BF}\u{03BD}\u{03C4}\u{03B1}\u{03B9} \u{03C3}\u{03C4}\u{03B1} \u{03B1}\u{03BD}\u{03C4}\u{03AF}\u{03B3}\u{03C1}\u{03B1}\u{03C6}\u{03B1} \u{03B1}\u{03C3}\u{03C6}\u{03B1}\u{03BB}\u{03B5}\u{03AF}\u{03B1}\u{03C2}.

            \u{03A0}\u{03B1}\u{03C4}\u{03AE}\u{03C3}\u{03C4}\u{03B5} [\u{00B7}\u{00B7}\u{00B7}] \u{2192} Settings \u{03B3}\u{03B9}\u{03B1} \u{03B4}\u{03B9}\u{03B1}\u{03C7}\u{03B5}\u{03AF}\u{03C1}\u{03B9}\u{03C3}\u{03B7} \u{03C4}\u{03C9}\u{03BD} \u{03BA}\u{03BB}\u{03B5}\u{03B9}\u{03B4}\u{03B9}\u{03CE}\u{03BD} \u{03C3}\u{03B1}\u{03C2}.
            """)

            sectionTitle("\u{0395}\u{039E}\u{0391}\u{0393}\u{03A9}\u{0393}\u{0397}")

            bodyText("""
            \u{039C}\u{03B5}\u{03C4}\u{03AC} \u{03C4}\u{03B7}\u{03BD} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03C5}\u{03C3}\u{03B7}, \u{03BC}\u{03C0}\u{03BF}\u{03C1}\u{03B5}\u{03AF}\u{03C4}\u{03B5} \u{03BD}\u{03B1} \u{03B5}\u{03BE}\u{03AC}\u{03B3}\u{03B5}\u{03C4}\u{03B5} \u{03C4}\u{03B1} \u{03B1}\u{03C0}\u{03BF}\u{03C4}\u{03B5}\u{03BB}\u{03AD}\u{03C3}\u{03BC}\u{03B1}\u{03C4}\u{03B1} \u{03C3}\u{03B5} CSV \u{03AE} PDF.
            """)

            sectionTitle("\u{0391}\u{039D}\u{0391}\u{0396}\u{0397}\u{03A4}\u{0397}\u{03A3}\u{0397} \u{0396}\u{03A9}\u{039D}\u{03A4}\u{0391}\u{039D}\u{0397}")

            bodyText("""
            \u{03A4}\u{03B1} \u{03B3}\u{03BB}\u{03C9}\u{03C3}\u{03C3}\u{03B9}\u{03BA}\u{03AC} \u{03BC}\u{03BF}\u{03BD}\u{03C4}\u{03AD}\u{03BB}\u{03B1} \u{03AD}\u{03C7}\u{03BF}\u{03C5}\u{03BD} \u{03B7}\u{03BC}\u{03B5}\u{03C1}\u{03BF}\u{03BC}\u{03B7}\u{03BD}\u{03AF}\u{03B1} \u{03BB}\u{03AE}\u{03BE}\u{03B7}\u{03C2} \u{03B3}\u{03BD}\u{03CE}\u{03C3}\u{03B7}\u{03C2} \u{2013} \u{03B4}\u{03B5}\u{03BD} \u{03BC}\u{03C0}\u{03BF}\u{03C1}\u{03BF}\u{03CD}\u{03BD} \u{03BD}\u{03B1} \u{03C0}\u{03C1}\u{03BF}\u{03C3}\u{03C0}\u{03B5}\u{03BB}\u{03AC}\u{03C3}\u{03BF}\u{03C5}\u{03BD} \
            \u{03C4}\u{03C1}\u{03AD}\u{03C7}\u{03BF}\u{03C5}\u{03C3}\u{03B5}\u{03C2} \u{03C0}\u{03BB}\u{03B7}\u{03C1}\u{03BF}\u{03C6}\u{03BF}\u{03C1}\u{03AF}\u{03B5}\u{03C2} \u{03B1}\u{03C0}\u{03CC} \u{03BC}\u{03CC}\u{03BD}\u{03B1} \u{03C4}\u{03BF}\u{03C5}\u{03C2}. \u{03A4}\u{03BF} ROSIN \u{03BB}\u{03CD}\u{03BD}\u{03B5}\u{03B9} \u{03B1}\u{03C5}\u{03C4}\u{03CC} \u{03C4}\u{03BF} \u{03C0}\u{03C1}\u{03CC}\u{03B2}\u{03BB}\u{03B7}\u{03BC}\u{03B1} \u{03BC}\u{03B5} \u{03C4}\u{03B7}\u{03BD} \
            \u{0391}\u{03BD}\u{03B1}\u{03B6}\u{03AE}\u{03C4}\u{03B7}\u{03C3}\u{03B7} \u{0396}\u{03C9}\u{03BD}\u{03C4}\u{03B1}\u{03BD}\u{03AC}, \u{03BC}\u{03B5} \u{03C4}\u{03B7} \u{03C7}\u{03C1}\u{03AE}\u{03C3}\u{03B7} \u{03C4}\u{03BF}\u{03C5} Tavily \u{2013} \u{03B5}\u{03BD}\u{03CC}\u{03C2} API \u{03B1}\u{03BD}\u{03B1}\u{03B6}\u{03AE}\u{03C4}\u{03B7}\u{03C3}\u{03B7}\u{03C2} \
            \u{03C3}\u{03C7}\u{03B5}\u{03B4}\u{03B9}\u{03B1}\u{03C3}\u{03BC}\u{03AD}\u{03BD}\u{03BF}\u{03C5} \u{03B5}\u{03B9}\u{03B4}\u{03B9}\u{03BA}\u{03AC} \u{03B3}\u{03B9}\u{03B1} \u{03B5}\u{03C6}\u{03B1}\u{03C1}\u{03BC}\u{03BF}\u{03B3}\u{03AD}\u{03C2} AI.

            \u{038C}\u{03C4}\u{03B1}\u{03BD} \u{03C4}\u{03BF} [LIVE] \u{03B5}\u{03AF}\u{03BD}\u{03B1}\u{03B9} \u{03B5}\u{03BD}\u{03B5}\u{03C1}\u{03B3}\u{03CC}, \u{03C4}\u{03BF} ROSIN \u{03B1}\u{03BD}\u{03B1}\u{03B6}\u{03B7}\u{03C4}\u{03AC} \u{03C3}\u{03C4}\u{03BF} \u{03B4}\u{03B9}\u{03B1}\u{03B4}\u{03AF}\u{03BA}\u{03C4}\u{03C5}\u{03BF} \u{03C0}\u{03C1}\u{03B9}\u{03BD} \u{03BE}\u{03B5}\u{03BA}\u{03B9}\u{03BD}\u{03AE}\u{03C3}\u{03B5}\u{03B9} \
            \u{03B7} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03C5}\u{03C3}\u{03B7}. \u{03A4}\u{03B1} \u{03B1}\u{03C0}\u{03BF}\u{03C4}\u{03B5}\u{03BB}\u{03AD}\u{03C3}\u{03BC}\u{03B1}\u{03C4}\u{03B1} \u{03B5}\u{03B9}\u{03C3}\u{03AC}\u{03B3}\u{03BF}\u{03BD}\u{03C4}\u{03B1}\u{03B9} \u{03C3}\u{03C4}\u{03BF} \u{03A3}\u{03C4}\u{03AC}\u{03B4}\u{03B9}\u{03BF} 1, \u{03B8}\u{03B5}\u{03BC}\u{03B5}\u{03BB}\u{03B9}\u{03CE}\u{03BD}\u{03BF}\u{03BD}\u{03C4}\u{03B1}\u{03C2} \
            \u{03C4}\u{03B7}\u{03BD} \u{03B1}\u{03C0}\u{03AC}\u{03BD}\u{03C4}\u{03B7}\u{03C3}\u{03B7} \u{03C3}\u{03B5} \u{03C4}\u{03C1}\u{03AD}\u{03C7}\u{03BF}\u{03BD}\u{03C4}\u{03B1} \u{03B4}\u{03B5}\u{03B4}\u{03BF}\u{03BC}\u{03AD}\u{03BD}\u{03B1}. \u{03A4}\u{03B1} \u{03B5}\u{03C0}\u{03CC}\u{03BC}\u{03B5}\u{03BD}\u{03B1} \u{03C3}\u{03C4}\u{03AC}\u{03B4}\u{03B9}\u{03B1} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03B7}\u{03B8}\u{03B5}\u{03CD}\u{03BF}\u{03C5}\u{03BD} \
            \u{03C4}\u{03B9}\u{03C2} \u{03C0}\u{03BB}\u{03B7}\u{03C1}\u{03BF}\u{03C6}\u{03BF}\u{03C1}\u{03AF}\u{03B5}\u{03C2} \u{03B1}\u{03C0}\u{03CC} \u{03C4}\u{03BF} \u{03B4}\u{03B9}\u{03B1}\u{03B4}\u{03AF}\u{03BA}\u{03C4}\u{03C5}\u{03BF}.

            \u{0393}\u{03B9}\u{03B1} \u{03B5}\u{03BD}\u{03B5}\u{03C1}\u{03B3}\u{03BF}\u{03C0}\u{03BF}\u{03AF}\u{03B7}\u{03C3}\u{03B7}:
            1. \u{0391}\u{03C0}\u{03BF}\u{03BA}\u{03C4}\u{03AE}\u{03C3}\u{03C4}\u{03B5} \u{03B4}\u{03C9}\u{03C1}\u{03B5}\u{03AC}\u{03BD} \u{03BA}\u{03BB}\u{03B5}\u{03B9}\u{03B4}\u{03AF} Tavily API \u{03B1}\u{03C0}\u{03CC} \u{03C4}\u{03BF} tavily.com
            2. \u{03A0}\u{03C1}\u{03BF}\u{03C3}\u{03B8}\u{03AD}\u{03C3}\u{03C4}\u{03B5} \u{03C4}\u{03BF} \u{03C3}\u{03C4}\u{03BF} [\u{00B7}\u{00B7}\u{00B7}] \u{2192} Settings \u{2192} Web Search
            3. \u{0395}\u{03BD}\u{03B5}\u{03C1}\u{03B3}\u{03BF}\u{03C0}\u{03BF}\u{03B9}\u{03AE}\u{03C3}\u{03C4}\u{03B5} \u{03C4}\u{03BF} [LIVE] \u{03C0}\u{03C1}\u{03B9}\u{03BD} \u{03C4}\u{03B7}\u{03BD} \u{03B1}\u{03BD}\u{03B1}\u{03B6}\u{03AE}\u{03C4}\u{03B7}\u{03C3}\u{03B7}
            """)

            sectionTitle("\u{0393}\u{0399}\u{0391}\u{03A4}\u{0399} \"ROSIN\";")

            bodyText("""
            \u{03A4}\u{03BF} rosin (\u{03C1}\u{03BF}\u{03C3}\u{03AF}\u{03BD}\u{03B9}) \u{03B5}\u{03AF}\u{03BD}\u{03B1}\u{03B9} \u{03BA}\u{03B1}\u{03B8}\u{03B1}\u{03C1}\u{03B9}\u{03C3}\u{03BC}\u{03AD}\u{03BD}\u{03B7} \u{03C1}\u{03B7}\u{03C4}\u{03AF}\u{03BD}\u{03B7} \u{2013} \u{03CC}\u{03C0}\u{03C9}\u{03C2} \u{03C4}\u{03BF} rosin \u{03B5}\u{03BE}\u{03AC}\u{03B3}\u{03B5}\u{03B9} \u{03BA}\u{03B1}\u{03B8}\u{03B1}\u{03C1}\u{03AE} \u{03BF}\u{03C5}\u{03C3}\u{03AF}\u{03B1} \
            \u{03B1}\u{03C0}\u{03CC} \u{03B1}\u{03BA}\u{03B1}\u{03C4}\u{03AD}\u{03C1}\u{03B3}\u{03B1}\u{03C3}\u{03C4}\u{03BF} \u{03C5}\u{03BB}\u{03B9}\u{03BA}\u{03CC}, \u{03AD}\u{03C4}\u{03C3}\u{03B9} \u{03BA}\u{03B1}\u{03B9} \u{03B1}\u{03C5}\u{03C4}\u{03CC} \u{03C4}\u{03BF} \u{03B5}\u{03C1}\u{03B3}\u{03B1}\u{03BB}\u{03B5}\u{03AF}\u{03BF} \u{03B5}\u{03BE}\u{03AC}\u{03B3}\u{03B5}\u{03B9} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03B7}\u{03B8}\u{03B5}\u{03C5}\u{03BC}\u{03AD}\u{03BD}\u{03B7} \u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03B9}\u{03B1} \
            \u{03B1}\u{03C0}\u{03CC} \u{03C0}\u{03BF}\u{03BB}\u{03BB}\u{03B1}\u{03C0}\u{03BB}\u{03AD}\u{03C2} \u{03B5}\u{03BE}\u{03CC}\u{03B4}\u{03BF}\u{03C5}\u{03C2} AI.
            """)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RosinTheme.monoCaption)
                .fontWeight(.bold)
            DividerLine()
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(RosinTheme.monoCaption2)
            .lineSpacing(4)
    }
}
