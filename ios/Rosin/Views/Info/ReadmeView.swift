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

            Tap [KEYS] in the header to manage your API keys.
            """)

            sectionTitle("EXPORT")

            bodyText("""
            After verification completes, you can export results as CSV or PDF \
            using the export buttons below the verified output.
            """)

            sectionTitle("HEADER CONTROLS")

            bodyText("""
            \u{2022} [THEME:SYS/LHT/DRK] \u{2013} Toggle between system, light, and dark theme
            \u{2022} [REC] \u{2013} Recommended model chains and pairing strategies
            \u{2022} [README] \u{2013} This page
            \u{2022} [KEYS] \u{2013} Manage your API keys
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

            \u{03A0}\u{03B1}\u{03C4}\u{03AE}\u{03C3}\u{03C4}\u{03B5} [KEYS] \u{03B3}\u{03B9}\u{03B1} \u{03B4}\u{03B9}\u{03B1}\u{03C7}\u{03B5}\u{03AF}\u{03C1}\u{03B9}\u{03C3}\u{03B7} \u{03C4}\u{03C9}\u{03BD} \u{03BA}\u{03BB}\u{03B5}\u{03B9}\u{03B4}\u{03B9}\u{03CE}\u{03BD} \u{03C3}\u{03B1}\u{03C2}.
            """)

            sectionTitle("\u{0395}\u{039E}\u{0391}\u{0393}\u{03A9}\u{0393}\u{0397}")

            bodyText("""
            \u{039C}\u{03B5}\u{03C4}\u{03AC} \u{03C4}\u{03B7}\u{03BD} \u{03B5}\u{03C0}\u{03B1}\u{03BB}\u{03AE}\u{03B8}\u{03B5}\u{03C5}\u{03C3}\u{03B7}, \u{03BC}\u{03C0}\u{03BF}\u{03C1}\u{03B5}\u{03AF}\u{03C4}\u{03B5} \u{03BD}\u{03B1} \u{03B5}\u{03BE}\u{03AC}\u{03B3}\u{03B5}\u{03C4}\u{03B5} \u{03C4}\u{03B1} \u{03B1}\u{03C0}\u{03BF}\u{03C4}\u{03B5}\u{03BB}\u{03AD}\u{03C3}\u{03BC}\u{03B1}\u{03C4}\u{03B1} \u{03C3}\u{03B5} CSV \u{03AE} PDF.
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
