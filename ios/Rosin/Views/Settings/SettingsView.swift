import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(.systemGray6)
            : Color(.systemBackground)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)
                    .cornerRadius(10)

                    // Providers section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("LLM Providers")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(LLMProvider.allCases.enumerated()), id: \.element) { index, provider in
                                APIKeyRowView(provider: provider)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)

                                if index < LLMProvider.allCases.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(cardBackground)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
