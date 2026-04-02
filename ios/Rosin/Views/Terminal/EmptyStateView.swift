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

    @Environment(\.colorScheme) private var colorScheme

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

    // MARK: - Futuristic scanning cursor
    @State private var scanProgress: CGFloat = 0
    @State private var scanComplete = false

    // MARK: - Animated grid background
    @State private var gridOffset: CGFloat = 0

    // MARK: - Title breathing
    @State private var titleBreathing = false

    /// Adaptive opacity — effects need to be much stronger in light mode
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            // ── Animated circuit grid background ──
            animatedGridBackground

            if !booted && !skippedBoot {
                bootSequenceView
                    .transition(.opacity)
            } else {
                mainIdleContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startBootSequence() }
    }

    // MARK: - Animated Circuit Grid Background
    // Visible grid of lines that drifts diagonally. Opacity adapts to color scheme.

    private var animatedGridBackground: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 36
            let extra = spacing * 2

            // Grid lines
            Path { path in
                var x: CGFloat = -extra
                while x <= geo.size.width + extra {
                    path.move(to: CGPoint(x: x, y: -extra))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height + extra))
                    x += spacing
                }
                var y: CGFloat = -extra
                while y <= geo.size.height + extra {
                    path.move(to: CGPoint(x: -extra, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width + extra, y: y))
                    y += spacing
                }
            }
            .stroke(RosinTheme.green.opacity(isDark ? 0.06 : 0.10), lineWidth: 0.5)
            .offset(x: gridOffset, y: gridOffset)

            // Accent nodes at intersections (small dots for "circuit" feel)
            Path { path in
                var x: CGFloat = -extra
                while x <= geo.size.width + extra {
                    var y: CGFloat = -extra
                    while y <= geo.size.height + extra {
                        path.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                        y += spacing
                    }
                    x += spacing
                }
            }
            .fill(RosinTheme.green.opacity(isDark ? 0.08 : 0.12))
            .offset(x: gridOffset, y: gridOffset)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                gridOffset = 36
            }
        }
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
        VStack(spacing: 20) {
            Spacer()

            // ── Title with holographic neon glow + breathing ──
            HStack(spacing: 0) {
                let typed = String(fullTitle.prefix(typedCount))
                let parts = typed.split(separator: "—", maxSplits: 1)

                // "ROSIN " — holographic glow with green + cyan layers
                if let rosinPart = parts.first {
                    Text(String(rosinPart))
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundColor(RosinTheme.green)
                        // Strong green neon glow — visible in both themes
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.9 : 0.4), radius: glowPulse ? 12 : 4)
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.5 : 0.1), radius: glowPulse ? 24 : 8)
                        // Cyan holographic shift
                        .shadow(color: Color.cyan.opacity(glowPulse ? 0.3 : 0.05), radius: glowPulse ? 16 : 0)
                }

                // "— PURE OUTPUT"
                if parts.count > 1 {
                    Text("—" + String(parts[1]))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.5))
                        .shadow(color: RosinTheme.green.opacity(glowPulse ? 0.15 : 0.0), radius: glowPulse ? 8 : 0)
                }

                // Typing cursor
                if !titleDone {
                    Text("▎")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(RosinTheme.green)
                        .opacity(cursorVisible ? 1 : 0)
                }
            }
            // Breathing scale: 0.98–1.02 over 3s
            .scaleEffect(titleBreathing ? 1.02 : 0.98)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: titleBreathing)

            // ── Subtitle ──
            Text("Launch a query through multiple LLMs.\nVerify, refine and detect hallucinations.")
                .font(RosinTheme.monoFootnote)
                .foregroundColor(RosinTheme.muted.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .opacity(titleDone ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: titleDone)

            // ── Futuristic scanning cursor ──
            // Neon beam sweeps left→right, then reveals blinking prompt
            ZStack {
                if !scanComplete {
                    GeometryReader { geo in
                        // Scan beam with trailing glow
                        ZStack {
                            // Wide trailing glow behind the beam
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            RosinTheme.green.opacity(0),
                                            RosinTheme.green.opacity(0.3),
                                            RosinTheme.green.opacity(0),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 2)

                            // The actual bright scan line
                            Rectangle()
                                .fill(RosinTheme.green)
                                .frame(width: 2, height: 22)
                                .shadow(color: RosinTheme.green.opacity(0.9), radius: 10)
                                .shadow(color: RosinTheme.green.opacity(0.6), radius: 20)
                                .shadow(color: Color.cyan.opacity(0.3), radius: 14)
                        }
                        .position(
                            x: scanProgress * geo.size.width,
                            y: geo.size.height / 2
                        )
                    }
                    .transition(.opacity)
                }

                // Blinking cursor (fades in after scan)
                if scanComplete {
                    HStack(spacing: 2) {
                        Text("> ")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.green.opacity(0.5))
                        Text("_")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.green)
                            .shadow(color: RosinTheme.green.opacity(0.8), radius: 6)
                            .opacity(cursorVisible ? 1 : 0)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: 120, height: 26)
            .padding(.top, 4)

            // ── Glassmorphic example query cards ──
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
            startScanAnimation()
            titleBreathing = true
        }
    }

    // MARK: - Glassmorphic Example Card
    // Frosted glass backdrop + green neon border + ambient glow

    private func exampleCard(_ example: ExampleQuery) -> some View {
        Button {
            onQuerySelect?(example.query)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("[\(example.label)]")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.green)
                    .tracking(2)
                    // Glow on the label text
                    .shadow(color: RosinTheme.green.opacity(0.5), radius: 4)
                Text(example.query)
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 240, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            // Frosted glass backdrop with green tint
            .background(
                ZStack {
                    // Base frosted material
                    Rectangle().fill(.ultraThinMaterial)
                    // Green tint overlay for glassmorphic color
                    Rectangle().fill(RosinTheme.green.opacity(isDark ? 0.05 : 0.04))
                }
            )
            .overlay(alignment: .leading) {
                // Bright green left accent
                Rectangle()
                    .fill(RosinTheme.green.opacity(0.7))
                    .frame(width: 3)
                    .shadow(color: RosinTheme.green.opacity(0.5), radius: 6)
            }
            .overlay(
                // Green neon border — clearly visible
                Rectangle()
                    .stroke(RosinTheme.green.opacity(isDark ? 0.25 : 0.20), lineWidth: 1)
            )
            // Ambient glow around the card
            .shadow(color: RosinTheme.green.opacity(isDark ? 0.15 : 0.12), radius: 12)
        }
        .buttonStyle(GlassmorphicCardStyle())
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

    /// Sweeps scan beam left→right over 1.2s, then reveals blinking cursor
    private func startScanAnimation() {
        let baseDelay: Double = skippedBoot ? 0.2 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay) {
            withAnimation(.easeInOut(duration: 1.2)) {
                scanProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeIn(duration: 0.3)) {
                    scanComplete = true
                }
            }
        }
    }
}

// MARK: - Glassmorphic Card Button Style
// Scale-up + amplified glow on press
private struct GlassmorphicCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.04 : 1.0)
            .shadow(
                color: RosinTheme.green.opacity(configuration.isPressed ? 0.35 : 0.0),
                radius: configuration.isPressed ? 16 : 0
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
