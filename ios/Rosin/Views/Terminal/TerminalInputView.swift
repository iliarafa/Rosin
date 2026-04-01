import SwiftUI

struct TerminalInputView: View {
    @Binding var query: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Command-line style > prompt with green tint
            Text(">")
                .font(RosinTheme.monoCaption.bold())
                .foregroundColor(RosinTheme.green.opacity(0.7))
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
                // EXECUTE button with green glow on enabled state
                let isEmpty = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button(action: onSubmit) {
                    Text("EXECUTE")
                        .font(RosinTheme.monoCaption)
                        .tracking(1)
                        .foregroundColor(isEmpty ? RosinTheme.muted : RosinTheme.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    isEmpty ? Color.primary.opacity(0.3) : RosinTheme.green.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                        // Subtle glow when enabled
                        .shadow(
                            color: isEmpty ? .clear : RosinTheme.green.opacity(0.2),
                            radius: isEmpty ? 0 : 6
                        )
                }
                .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        // Green glow border when input is focused
        .overlay(
            Rectangle()
                .stroke(
                    isFocused ? RosinTheme.green.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
                .shadow(color: isFocused ? RosinTheme.green.opacity(0.15) : .clear, radius: 8)
        )
        .animation(.easeInOut(duration: 0.3), value: isFocused)
    }
}
