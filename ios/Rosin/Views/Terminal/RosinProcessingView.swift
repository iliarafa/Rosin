import SwiftUI

struct RosinProcessingView: View {
    let stages: [StageOutput]
    let expectedStageCount: Int

    @State private var pulsePhase = false
    @State private var dotPhases: [Bool] = [false, false, false]

    private var completedStages: Int {
        stages.filter { $0.status == .complete }.count
    }

    private var currentStage: StageOutput? {
        stages.first { $0.status == .streaming }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pulsing glow ring
            Circle()
                .stroke(RosinTheme.green.opacity(pulsePhase ? 0.7 : 0.25), lineWidth: 2)
                .frame(width: 80, height: 80)
                .shadow(color: RosinTheme.green.opacity(pulsePhase ? 0.4 : 0.1), radius: pulsePhase ? 30 : 15)
                .scaleEffect(pulsePhase ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulsePhase)
                .padding(.bottom, 40)

            // PROCESSING text
            Text("PROCESSING")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .tracking(6)
                .foregroundColor(RosinTheme.green)
                .shadow(color: RosinTheme.green.opacity(0.5), radius: 8)
                .padding(.bottom, 12)

            // Pulsing dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(RosinTheme.green)
                        .frame(width: 6, height: 6)
                        .opacity(dotPhases[i] ? 1.0 : 0.2)
                        .animation(
                            .easeInOut(duration: 1.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: dotPhases[i]
                        )
                }
            }
            .padding(.bottom, 32)

            // Stage progress
            VStack(spacing: 8) {
                if let current = currentStage {
                    HStack(spacing: 6) {
                        Text("STAGE \(completedStages + 1) OF \(expectedStageCount)")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                        Text(current.model.provider.shortName.uppercased())
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.green.opacity(0.5))
                    }
                } else if completedStages == expectedStageCount {
                    Text("ANALYZING...")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.green.opacity(0.7))
                } else {
                    Text("INITIALIZING...")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted.opacity(0.6))
                }

                // Minimal progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                        Rectangle()
                            .fill(RosinTheme.green.opacity(0.6))
                            .frame(
                                width: geo.size.width * progressFraction,
                                height: 1
                            )
                            .animation(.easeOut(duration: 0.5), value: progressFraction)
                    }
                }
                .frame(width: 180, height: 1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RosinTheme.background)
        .onAppear {
            pulsePhase = true
            dotPhases = [true, true, true]
        }
    }

    private var progressFraction: CGFloat {
        let progress = Double(completedStages) + (currentStage != nil ? 0.5 : 0)
        return CGFloat(progress / Double(max(expectedStageCount, 1)))
    }
}
