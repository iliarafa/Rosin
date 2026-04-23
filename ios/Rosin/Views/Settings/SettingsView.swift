import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @EnvironmentObject private var fontSizeManager: FontSizeManager
    @EnvironmentObject private var modeManager: RosinModeManager
    @EnvironmentObject var auth: AuthViewModel
    @AppStorage("auto_tie_breaker") private var isAutoTieBreaker = true
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

                        VStack(spacing: 0) {
                            ExaKeyRowView()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)

                            Divider().padding(.leading, 16)

                            TavilyKeyRowView()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        }
                        .background(cardBackground)
                        .cornerRadius(10)
                    }

                    // Rosin Mode
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Mode")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pro Mode")
                                        .font(RosinTheme.monoCaption)
                                    Text("Full multi-stage verification UI with per-stage scoring, provenance, and Judge details.")
                                        .font(RosinTheme.monoCaption2)
                                        .foregroundColor(RosinTheme.muted)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { modeManager.mode == .pro },
                                    set: { modeManager.mode = $0 ? .pro : .novice }
                                ))
                                    .labelsHidden()
                                    .tint(RosinTheme.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .accessibilityIdentifier("pro-mode-toggle")

                            Divider().padding(.leading, 16)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto Tie-Breaker")
                                        .font(RosinTheme.monoCaption)
                                    Text("Run an extra verification round when models strongly disagree.")
                                        .font(RosinTheme.monoCaption2)
                                        .foregroundColor(RosinTheme.muted)
                                }

                                Spacer()

                                Toggle("", isOn: $isAutoTieBreaker)
                                    .labelsHidden()
                                    .tint(RosinTheme.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
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

                    if auth.isSignedIn {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Account")
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.muted)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                if let email = auth.account?.email {
                                    HStack {
                                        Text(email)
                                            .font(RosinTheme.monoCaption)
                                            .foregroundColor(RosinTheme.muted)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    Divider().padding(.leading, 16)
                                }
                                Button {
                                    Task { await auth.signOut() }
                                } label: {
                                    HStack {
                                        Text("Sign out")
                                            .font(RosinTheme.monoCaption)
                                            .foregroundColor(Color("RosinDestructive"))
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(cardBackground)
                            .cornerRadius(10)
                        }
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
