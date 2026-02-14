import SwiftUI

struct APIKeyGuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Each LLM provider requires its own API key. The steps are the same for all three:")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted)

                VStack(alignment: .leading, spacing: 4) {
                    step(1, "Create an account or sign in")
                    step(2, "Navigate to the API keys page")
                    step(3, "Create a new API key")
                    step(4, "Copy the key and paste it in Settings")
                }

                DividerLine()

                Text("Open a provider console to get started:")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted)

                ForEach(LLMProvider.allCases) { provider in
                    providerLink(provider)
                }
            }
            .padding()
        }
        .navigationTitle("How to Get Keys")
        .navigationBarTitleDisplayMode(.inline)
        .font(RosinTheme.monoCaption)
    }

    private func providerLink(_ provider: LLMProvider) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(RosinTheme.monoCaption)
                    .fontWeight(.bold)
                Text(providerDescription(provider))
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted)
            }

            Spacer()

            Button {
                openURL(provider.apiKeyURL)
            } label: {
                Text("[OPEN]")
                    .font(RosinTheme.monoCaption2)
                    .fontWeight(.medium)
                    .foregroundColor(RosinTheme.green)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Text("\(number). \(text)")
            .font(RosinTheme.monoCaption2)
    }

    private func providerDescription(_ provider: LLMProvider) -> String {
        switch provider {
        case .anthropic: return "Claude models by Anthropic"
        case .gemini: return "Gemini models by Google"
        case .xai: return "Grok models by xAI"
        }
    }
}
