import SwiftUI

struct APIKeyRowView: View {
    let provider: LLMProvider

    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @State private var isEditing = false
    @State private var keyInput = ""
    @State private var errorMessage: String?

    private var hasKey: Bool {
        apiKeyManager.hasKey[provider] ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(RosinTheme.monoCaption)
                        .fontWeight(.medium)
                    Text(provider.models.joined(separator: ", "))
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)
                }

                Spacer()

                if hasKey {
                    Text("[SET]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.green)
                } else {
                    Text("[MISSING]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.destructive)
                }
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Paste API key...", text: $keyInput)
                        .font(RosinTheme.monoCaption2)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack(spacing: 12) {
                        Button("Save") { saveKey() }
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.green)

                        Button("Cancel") {
                            isEditing = false
                            keyInput = ""
                            errorMessage = nil
                        }
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)

                        if hasKey {
                            Button("Delete") { deleteKey() }
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.destructive)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.destructive)
                    }
                }
            } else {
                Button(hasKey ? "Edit Key" : "Add Key") {
                    isEditing = true
                    keyInput = ""
                    errorMessage = nil
                }
                .font(RosinTheme.monoCaption2)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveKey() {
        do {
            try apiKeyManager.saveKey(keyInput, for: provider)
            isEditing = false
            keyInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKey() {
        do {
            try apiKeyManager.deleteKey(for: provider)
            isEditing = false
            keyInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
