import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @EnvironmentObject private var fontSizeManager: FontSizeManager
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

                    // Web Search section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Web Search")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        TavilyKeyRowView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(cardBackground)
                            .cornerRadius(10)
                    }

                    // Response font size
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Response Font Size")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        VStack(spacing: 12) {
                            HStack(spacing: 0) {
                                ForEach(FontSizeCategory.allCases) { size in
                                    Button {
                                        fontSizeManager.sizeCategory = size
                                    } label: {
                                        Text(size.label)
                                            .font(RosinTheme.monoCaption)
                                            .fontWeight(fontSizeManager.sizeCategory == size ? .bold : .regular)
                                            .foregroundColor(fontSizeManager.sizeCategory == size ? RosinTheme.green : RosinTheme.muted)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                fontSizeManager.sizeCategory == size
                                                    ? RosinTheme.green.opacity(0.1)
                                                    : Color.clear
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .overlay(
                                Rectangle()
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )

                            // Preview
                            Text("A true account of the actual.")
                                .font(RosinTheme.responseFont(for: fontSizeManager.sizeCategory))
                                .lineSpacing(fontSizeManager.sizeCategory.lineSpacing)
                                .foregroundColor(RosinTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(cardBackground)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
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
