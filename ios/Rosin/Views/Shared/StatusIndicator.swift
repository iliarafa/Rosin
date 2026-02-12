import SwiftUI

struct StatusIndicator: View {
    let status: StageStatus

    @State private var isPulsing = false

    var body: some View {
        Text(label)
            .font(RosinTheme.monoCaption)
            .foregroundColor(color)
            .opacity(status == .streaming ? (isPulsing ? 1.0 : 0.4) : 1.0)
            .onAppear {
                if status == .streaming {
                    withAnimation(RosinTheme.pulseAnimation) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: status) { _, newValue in
                if newValue != .streaming {
                    isPulsing = false
                }
            }
    }

    private var label: String {
        switch status {
        case .pending: return "[...]"
        case .streaming: return "[RUN]"
        case .complete: return "[OK]"
        case .error: return "[ERR]"
        }
    }

    private var color: Color {
        switch status {
        case .pending: return RosinTheme.muted
        case .streaming: return RosinTheme.muted
        case .complete: return .primary
        case .error: return RosinTheme.destructive
        }
    }
}
