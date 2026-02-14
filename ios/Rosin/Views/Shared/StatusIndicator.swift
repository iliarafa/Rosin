import SwiftUI

struct StatusIndicator: View {
    let status: StageStatus

    @State private var isPulsing = false

    private var shouldPulse: Bool {
        status == .streaming || status == .retrying
    }

    var body: some View {
        Text(label)
            .font(RosinTheme.monoCaption)
            .foregroundColor(color)
            .opacity(shouldPulse ? (isPulsing ? 1.0 : 0.4) : 1.0)
            .onAppear {
                if shouldPulse {
                    withAnimation(RosinTheme.pulseAnimation) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: status) { _, newValue in
                if newValue != .streaming && newValue != .retrying {
                    isPulsing = false
                } else if !isPulsing {
                    withAnimation(RosinTheme.pulseAnimation) {
                        isPulsing = true
                    }
                }
            }
    }

    private var label: String {
        switch status {
        case .pending: return "[...]"
        case .streaming: return "[RUN]"
        case .complete: return "[OK]"
        case .error: return "[ERR]"
        case .skipped: return "[SKIP]"
        case .retrying: return "[RETRY]"
        }
    }

    private var color: Color {
        switch status {
        case .pending: return RosinTheme.muted
        case .streaming: return RosinTheme.muted
        case .complete: return .primary
        case .error: return RosinTheme.destructive
        case .skipped: return RosinTheme.muted
        case .retrying: return RosinTheme.green
        }
    }
}
