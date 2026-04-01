import SwiftUI

// MARK: - Example queries shown on the idle screen
private struct ExampleQuery: Identifiable {
    let id = UUID()
    let label: String
    let query: String
}

private let exampleQueries: [ExampleQuery] = [
    ExampleQuery(
        label: "SCIENCE",
        query: "What are the latest breakthroughs in nuclear fusion energy in 2026?"
    ),
    ExampleQuery(
        label: "POLICY",
        query: "Analyze the current state of worldwide AI regulation"
    ),
    ExampleQuery(
        label: "TECH",
        query: "What is the most reliable information on Grok 4 capabilities right now?"
    ),
]

// MARK: - Boot sequence messages
private let bootMessages: [String] = [
    "> ROSIN v1.0 — multi-LLM verification engine",
    "> Loading provider modules...",
    "> Anthropic ✓  Gemini ✓  xAI ✓",
    "> Pipeline ready. Awaiting query.",
]

struct EmptyStateView: View {
    /// Callback when user taps an example query card
    var onQuerySelect: ((String) -> Void)?

    // MARK: - Boot sequence state
    @State private var bootLineCount = 0
    @State private var booted = false
    @State private var skippedBoot = false

    // MARK: - Typing animation state
    private let fullTitle = "ROSIN — PURE OUTPUT"
    @State private var typedCount = 0
    @State private var titleDone = false

    // MARK: - Cursor & glow
    @State private var cursorVisible = true
    @State private var glowPulse = false

    // MARK: - Example cards fade-in
    @State private var showExamples = false

    var body: some View {
        ZStack {
            // ── CRT scanlines background (very subtle) ──
            CRTScanlinesView()

            if !booted && !skippedBoot {
                // ── Boot sequence overlay ──
                bootSequenceView
                    .transition(.opacity)
            } else {
                // ── Main idle content ──
                mainIdleContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startBootSequence() }
    }

    // MARK: - Boot Sequence

    private var bootSequenceView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()

            ForEach(0..<bootLineCount, id: \.self) { index in
                Text(bootMessages[index])
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.green.opacity(0.7))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            // "Tap to skip" hint
            Text("Tap to skip")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture { skipBoot() }
    }

    // MARK: - Main Idle Content

    private var mainIdleContent: some View {
        VStack(spacing: 16) {
            Spacer()

            // ── Title with typing animation + neon glow ──
            HStack(spacing: 0) {
                let typed = String(fullTitle.prefix(typedCount))
                let parts = typed.split(separator: "—", maxSplits: 1)

                // "ROSIN " part with neon glow
                if let rosinPart = parts.first {
                    Text(String(rosinPart))
                        .font(RosinTheme.monoCaption)
                        .foregroundColor(.primary)
                        // Neon green glow effect
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.5 : 0.15), radius: glowPulse ? 8 : 3)
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.25 : 0.05), radius: glowPulse ? 16 : 6)
                }

                // "— PURE OUTPUT" part (dimmer)
                if parts.count > 1 {
                    Text("—" + String(parts[1]))
                        .font(RosinTheme.monoCaption)
                        .foregroundColor(.primary.opacity(0.6))
                }

                // Typing cursor (visible while typing)
                if !titleDone {
                    Text("▎")
                        .font(RosinTheme.monoCaption)
                        .foregroundColor(RosinTheme.green)
                        .opacity(cursorVisible ? 1 : 0)
                }
            }

            // ── Subtitle ──
            Text("Launch a query through multiple LLMs. Verify, refine and detect hallucinations.")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .opacity(titleDone ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: titleDone)

            // ── Blinking cursor with green glow ──
            HStack(spacing: 2) {
                Text("> ")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.green.opacity(0.5))
                Text("_")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.green)
                    .shadow(color: RosinTheme.green.opacity(0.6), radius: 4)
                    .opacity(cursorVisible ? 1 : 0)
            }
            .padding(.top, 8)

            // ── Example query cards ──
            if showExamples {
                VStack(spacing: 10) {
                    ForEach(exampleQueries) { example in
                        exampleCard(example)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
        .onAppear {
            startTypingAnimation()
            startGlowPulse()
            startCursorBlink()
        }
    }

    // MARK: - Example Card

    private func exampleCard(_ example: ExampleQuery) -> some View {
        Button {
            onQuerySelect?(example.query)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("[\(example.label)]")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.green.opacity(0.7))
                    .tracking(2)
                Text(example.query)
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animations

    private func startBootSequence() {
        // Show boot lines one at a time
        for i in 0..<bootMessages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                guard !skippedBoot else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    bootLineCount = i + 1
                }
            }
        }
        // Transition to main content after boot
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(bootMessages.count) * 0.25 + 0.3) {
            guard !skippedBoot else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                booted = true
            }
        }
    }

    private func skipBoot() {
        skippedBoot = true
        withAnimation(.easeInOut(duration: 0.2)) {
            booted = true
        }
    }

    private func startTypingAnimation() {
        let delay: Double = skippedBoot ? 0 : 0.3
        for i in 0...fullTitle.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i) * 0.05) {
                typedCount = i
                if i == fullTitle.count {
                    titleDone = true
                    // Show example cards after title finishes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showExamples = true
                        }
                    }
                }
            }
        }
    }

    /// Subtle neon glow pulse on "ROSIN"
    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    /// Block cursor blink (step-style, not smooth fade)
    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

// MARK: - CRT Scanlines Background

/// Very faint horizontal lines simulating a CRT monitor effect
struct CRTScanlinesView: View {
    var body: some View {
        Canvas { context, size in
            // Draw horizontal lines every 4 points at very low opacity
            let lineSpacing: CGFloat = 4
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.primary.opacity(0.025)))
                y += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}
