import SwiftUI

struct TerminalInputView: View {
    @Binding var query: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("$")
                .font(RosinTheme.monoCaption)
                .foregroundColor(RosinTheme.muted)
                .padding(.bottom, 8)

            TextField("Enter your query...", text: $query, axis: .vertical)
                .font(RosinTheme.monoCaption)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .disabled(isProcessing)
                .focused($isFocused)
                .onSubmit {
                    onSubmit()
                }

            if isProcessing {
                Button(action: onCancel) {
                    Text("STOP")
                        .font(RosinTheme.monoCaption)
                        .foregroundColor(RosinTheme.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .stroke(RosinTheme.destructive, lineWidth: 1)
                        )
                }
            } else {
                Button(action: onSubmit) {
                    Text("RUN")
                        .font(RosinTheme.monoCaption)
                        .foregroundColor(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? RosinTheme.muted : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
