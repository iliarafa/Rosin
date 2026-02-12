import SwiftUI

struct APIKeyGuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Each LLM provider requires its own API key. Follow the steps below to obtain one.")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted)

                ForEach(LLMProvider.allCases) { provider in
                    providerSection(provider)
                }
            }
            .padding()
        }
        .navigationTitle("How to Get Keys")
        .navigationBarTitleDisplayMode(.inline)
        .font(RosinTheme.monoCaption)
    }

    @ViewBuilder
    private func providerSection(_ provider: LLMProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DividerLine()

            Text(provider.displayName)
                .font(RosinTheme.monoCaption)
                .fontWeight(.bold)

            Text(providerDescription(provider))
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted)

            VStack(alignment: .leading, spacing: 4) {
                step(1, "Create an account or sign in")
                step(2, "Navigate to the API keys page")
                step(3, "Create a new API key")
                step(4, "Copy the key and paste it in Settings")
            }

            Button {
                openURL(provider.apiKeyURL)
            } label: {
                Text("[OPEN \(provider.displayName.uppercased()) CONSOLE]")
                    .font(RosinTheme.monoCaption2)
                    .fontWeight(.medium)
                    .foregroundColor(RosinTheme.green)
            }
            .padding(.top, 4)
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
