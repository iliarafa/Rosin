import SwiftUI

// MARK: - Boot sequence messages
private let bootMessages: [String] = [
    "> ROSIN v1.0 — multi-LLM verification engine",
    "> Loading provider modules...",
    "> Anthropic ✓  Gemini ✓  xAI ✓",
    "> Pipeline ready. Awaiting query.",
]

/// Single-line boot animation: each message replaces the previous on the top line,
/// ending with a blinking cursor before transitioning to the input screen.
struct BootSequenceView: View {
    var onComplete: (() -> Void)?

    /// Index of the currently visible message (-1 = nothing yet, count = show cursor)
    @State private var currentIndex = -1
    @State private var finished = false
    @State private var cursorVisible = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Single line at the top — cycles through messages then cursor
            Group {
                if currentIndex >= 0 && currentIndex < bootMessages.count {
                    Text(bootMessages[currentIndex])
                        .font(RosinTheme.monoBody)
                        .foregroundColor(RosinTheme.green.opacity(0.7))
                        .id(currentIndex) // forces SwiftUI to treat each as a new view
                        .transition(.opacity)
                } else if currentIndex >= bootMessages.count {
                    HStack(spacing: 0) {
                        Text("> ")
                            .font(RosinTheme.monoBody)
                            .foregroundColor(RosinTheme.green.opacity(0.5))
                        Text("_")
                            .font(RosinTheme.monoBody)
                            .foregroundColor(RosinTheme.green)
                            .opacity(cursorVisible ? 1 : 0)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: currentIndex)
            .padding(.top, 8)

            Spacer()

            if !finished {
                Text("Tap to skip")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .onAppear {
            startBootSequence()
            startCursorBlink()
        }
    }

    private func startBootSequence() {
        // Cycle through each message, replacing the previous
        for i in 0..<bootMessages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                guard !finished else { return }
                withAnimation {
                    currentIndex = i
                }
            }
        }
        // Show cursor after last message
        let cursorDelay = Double(bootMessages.count) * 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + cursorDelay) {
            guard !finished else { return }
            withAnimation {
                currentIndex = bootMessages.count
            }
        }
        // Complete after brief cursor pause
        DispatchQueue.main.asyncAfter(deadline: .now() + cursorDelay + 0.8) {
            guard !finished else { return }
            complete()
        }
    }

    private func skip() {
        guard !finished else { return }
        complete()
    }

    private func complete() {
        finished = true
        withAnimation(.easeInOut(duration: 0.3)) {
            onComplete?()
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}
