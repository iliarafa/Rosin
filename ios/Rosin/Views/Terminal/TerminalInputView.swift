import SwiftUI

struct TerminalInputView: View {
    @Binding var query: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Command-line style > prompt
            Text(">")
                .font(RosinTheme.monoFootnote.bold())
                .foregroundColor(RosinTheme.green.opacity(0.7))
                .padding(.bottom, 10)

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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .stroke(RosinTheme.destructive, lineWidth: 1)
                        )
                }
            } else {
                let isEmpty = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button(action: onSubmit) {
                    Text("EXECUTE")
                        .font(RosinTheme.monoCaption)
                        .tracking(1)
                        .foregroundColor(isEmpty ? RosinTheme.muted : RosinTheme.green)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    isEmpty ? Color.primary.opacity(0.3) : RosinTheme.green.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isEmpty ? .clear : RosinTheme.green.opacity(0.2),
                            radius: isEmpty ? 0 : 6
                        )
                }
                .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
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
