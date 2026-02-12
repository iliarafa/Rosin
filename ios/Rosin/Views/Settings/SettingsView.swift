import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("API keys are stored securely in the device Keychain and never leave this device.")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)

                    NavigationLink {
                        APIKeyGuideView()
                    } label: {
                        Text("[HOW TO GET KEYS]")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.green)
                    }
                }

                Section("LLM Providers") {
                    ForEach(LLMProvider.allCases) { provider in
                        APIKeyRowView(provider: provider)
                    }
                }
            }
            .navigationTitle("API Keys")
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
}
