import SwiftUI

struct TavilyKeyRowView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @State private var isEditing = false
    @State private var keyInput = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tavily")
                        .font(RosinTheme.monoCaption)
                        .fontWeight(.medium)
                    Text("Live web search for [LIVE] mode")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)
                }

                Spacer()

                if apiKeyManager.hasTavilyKey {
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
                    PastableTextField(placeholder: "Enter Tavily API key...", text: $keyInput)
                        .frame(height: 36)

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

                        if apiKeyManager.hasTavilyKey {
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
                Button(apiKeyManager.hasTavilyKey ? "Edit Key" : "Add Key") {
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
            try apiKeyManager.saveTavilyKey(keyInput)
            isEditing = false
            keyInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKey() {
        do {
            try apiKeyManager.deleteTavilyKey()
            isEditing = false
            keyInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
