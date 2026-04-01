import SwiftUI

struct ResearchStatusView: View {
    let status: ResearchStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(">")
                    .foregroundColor(RosinTheme.muted)
                Text("LIVE RESEARCH")
                    .fontWeight(.medium)
                    .foregroundColor(RosinTheme.green)

                switch status {
                case .searching:
                    Text("[RUN]")
                        .foregroundColor(RosinTheme.muted)
                        .opacity(0.8)
                        .modifier(PulseModifier())
                case .complete:
                    Text("[OK]")
                        .foregroundColor(.primary)
                case .error:
                    Text("[ERR]")
                        .foregroundColor(RosinTheme.destructive)
                }
            }
            .font(RosinTheme.monoCaption)

            switch status {
            case .searching:
                HStack(spacing: 0) {
                    Text("Searching the web for current information")
                        .foregroundColor(RosinTheme.muted)
                    Text("...")
                        .foregroundColor(RosinTheme.muted)
                        .modifier(PulseModifier())
                }
                .font(RosinTheme.monoCaption2)

            case .complete(let sourceCount, let sources):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(sourceCount) source\(sourceCount != 1 ? "s" : ""):")
                        .foregroundColor(RosinTheme.muted)
                    Text(sources)
                        .foregroundColor(RosinTheme.muted.opacity(0.8))
                }
                .font(RosinTheme.monoCaption2)

            case .error(let error):
                Text(error)
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.destructive.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
        }
    }
}

private struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
