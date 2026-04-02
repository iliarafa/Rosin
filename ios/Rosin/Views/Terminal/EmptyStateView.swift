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
            // CRT scanlines removed — clean background only

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

    // MARK: - Main Idle Content (Bold & Confident)

    private var mainIdleContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // ── Title with typing animation + neon glow (LARGE) ──
            HStack(spacing: 0) {
                let typed = String(fullTitle.prefix(typedCount))
                let parts = typed.split(separator: "—", maxSplits: 1)

                // "ROSIN " part with neon glow — big bold title
                if let rosinPart = parts.first {
                    Text(String(rosinPart))
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundColor(.primary)
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.5 : 0.15), radius: glowPulse ? 8 : 3)
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.25 : 0.05), radius: glowPulse ? 16 : 6)
                }

                // "— PURE OUTPUT" part
                if parts.count > 1 {
                    Text("—" + String(parts[1]))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.5))
                }

                // Typing cursor
                if !titleDone {
                    Text("▎")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(RosinTheme.green)
                        .opacity(cursorVisible ? 1 : 0)
                }
            }

            // ── Subtitle — bigger ──
            Text("Launch a query through multiple LLMs.\nVerify, refine and detect hallucinations.")
                .font(RosinTheme.monoFootnote)
                .foregroundColor(RosinTheme.muted.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .opacity(titleDone ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: titleDone)

            // ── Blinking cursor ──
            HStack(spacing: 2) {
                Text("> ")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.green.opacity(0.5))
                Text("_")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.green)
                    .shadow(color: RosinTheme.green.opacity(0.6), radius: 4)
                    .opacity(cursorVisible ? 1 : 0)
            }
            .padding(.top, 4)

            // ── Example query cards (redesigned: bigger, green left border, horizontal scroll) ──
            if showExamples {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(exampleQueries) { example in
                            exampleCard(example)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .scrollTargetBehavior(.viewAligned)
                .padding(.top, 8)
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

    // MARK: - Example Card (Redesigned: larger, green accent border)

    private func exampleCard(_ example: ExampleQuery) -> some View {
        Button {
            onQuerySelect?(example.query)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("[\(example.label)]")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.green.opacity(0.8))
                    .tracking(2)
                Text(example.query)
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 240, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .overlay(alignment: .leading) {
                // Green left accent border
                Rectangle()
                    .fill(RosinTheme.green.opacity(0.4))
                    .frame(width: 3)
            }
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animations

    private func startBootSequence() {
        for i in 0..<bootMessages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                guard !skippedBoot else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    bootLineCount = i + 1
                }
            }
        }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showExamples = true
                        }
                    }
                }
            }
        }
    }

    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}
