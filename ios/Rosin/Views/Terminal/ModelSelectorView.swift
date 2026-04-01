import SwiftUI

struct ModelSelectorView: View {
    let stageNumber: Int
    let selectedModel: LLMModel
    let onModelChange: (LLMModel) -> Void
    let disabled: Bool
    /// When true, the pill gets a glowing green ring + soft pulse
    var isActive: Bool = false

    @State private var activePulse = false

    var body: some View {
        HStack(spacing: 4) {
            Text("[\(stageNumber)]")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted.opacity(0.8))

            // Provider icon
            ProviderIconView(provider: selectedModel.provider)
                .frame(width: 12, height: 12)
                .foregroundColor(.primary.opacity(0.6))

            Menu {
                ForEach(LLMProvider.allCases) { provider in
                    Section(provider.displayName) {
                        ForEach(provider.models, id: \.self) { model in
                            Button {
                                onModelChange(LLMModel(provider: provider, model: model))
                            } label: {
                                HStack {
                                    // Icon in dropdown too
                                    ProviderIconView(provider: provider)
                                        .frame(width: 10, height: 10)
                                    Text(model)
                                    if selectedModel.provider == provider && selectedModel.model == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                Text(selectedModel.provider.shortName)
                    .font(RosinTheme.monoCaption2)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        Rectangle()
                            .stroke(
                                isActive ? RosinTheme.green.opacity(activePulse ? 0.7 : 0.4) : Color.primary.opacity(0.2),
                                lineWidth: isActive ? 1.5 : 1
                            )
                    )
                    // Active stage gets a green glow
                    .shadow(
                        color: isActive ? RosinTheme.green.opacity(activePulse ? 0.35 : 0.15) : .clear,
                        radius: isActive ? 6 : 0
                    )
            }
            .disabled(disabled)
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    activePulse = true
                }
            } else {
                activePulse = false
            }
        }
    }
}

// MARK: - Provider Icons (SwiftUI shape-based, no external assets)

/// Renders a small recognizable icon for each LLM provider
struct ProviderIconView: View {
    let provider: LLMProvider

    var body: some View {
        switch provider {
        case .anthropic:
            // Claude sunburst logo — original colors
            Image("ClaudeIcon")
                .resizable()
                .scaledToFit()

        case .gemini:
            // Gemini four-pointed star logo — original colors
            Image("GeminiIcon")
                .resizable()
                .scaledToFit()

        case .xai:
            // Grok logo — thick ring with a diagonal spike slash
            // Rendered as a single filled Path for crisp display at small sizes
            Image("GrokIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }
}
