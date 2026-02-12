import SwiftUI

struct RecommendationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionTitle("LLM PAIRING STRATEGIES")

                    bodyText("""
                    For best results, use models from different providers. Cross-provider \
                    verification is more effective because each model has different training \
                    data and different failure modes.
                    """)

                    sectionTitle("RECOMMENDED 3-STAGE CHAINS")

                    chainCard(
                        name: "Balanced (Default)",
                        chain: "Claude Sonnet 4.5 \u{2192} Gemini 2.5 Pro \u{2192} Grok 3",
                        description: "Best all-around chain. Three different providers give maximum diversity for consensus verification."
                    )

                    chainCard(
                        name: "Speed Priority",
                        chain: "Claude Haiku 4.5 \u{2192} Gemini 2.5 Flash \u{2192} Grok 3 Fast",
                        description: "Fastest chain using the lighter model from each provider. Good for simple factual queries."
                    )

                    chainCard(
                        name: "Maximum Accuracy",
                        chain: "Claude Opus 4.5 \u{2192} Gemini 2.5 Pro \u{2192} Grok 3",
                        description: "Uses the most capable model from each provider. Best for complex or high-stakes queries."
                    )

                    sectionTitle("RECOMMENDED 2-STAGE CHAINS")

                    chainCard(
                        name: "Quick Verification",
                        chain: "Claude Sonnet 4.5 \u{2192} Gemini 2.5 Pro",
                        description: "Fast dual verification with two strong models from different providers."
                    )

                    chainCard(
                        name: "Deep Check",
                        chain: "Claude Opus 4.5 \u{2192} Grok 3",
                        description: "Thorough initial response verified by a completely different architecture."
                    )

                    sectionTitle("TIPS")

                    bodyText("""
                    \u{2022} Always use models from different providers for best results
                    \u{2022} 3 stages provides a "tiebreaker" effect \u{2013} if two models agree, the answer is likely correct
                    \u{2022} 2 stages is faster but provides less confidence
                    \u{2022} Faster models (Haiku, Flash, Grok Fast) work well for simple factual queries
                    \u{2022} Use premium models (Opus, Pro, Grok 3) for nuanced or technical topics
                    \u{2022} The order matters: stage 1 generates, middle stages verify, final stage synthesizes
                    """)
                }
                .padding()
            }
            .navigationTitle("Recommendations")
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

    private func chainCard(name: String, chain: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(RosinTheme.monoCaption)
                .fontWeight(.medium)
            Text(chain)
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.green)
            Text(description)
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted)
                .lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
