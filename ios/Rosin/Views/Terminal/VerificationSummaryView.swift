import SwiftUI

struct VerificationSummaryView: View {
    let summary: VerificationSummary

    /// Controls the fade-in animation when the summary appears
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with JUDGE badge and overall score
            HStack(spacing: 8) {
                Text("VERIFICATION SUMMARY")
                    .font(RosinTheme.monoCaption)
                    .fontWeight(.medium)
                    .foregroundColor(RosinTheme.green)

                if summary.isAnalyzed {
                    Text("[ANALYZED]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.green)
                }

                // Judge badge — indicates the dedicated Judge stage produced this verdict
                if summary.judgeVerdict != nil {
                    Text("[JUDGE]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.green)
                }

                Spacer()

                // Overall score from the Judge (0-100)
                if let jv = summary.judgeVerdict {
                    Text("\(jv.overallScore)/100")
                        .font(RosinTheme.monoCaption)
                        .fontWeight(.medium)
                        .foregroundColor(scoreColor(jv.overallScore))
                }
            }

            // Judge verdict — expert summary sentence(s)
            if let jv = summary.judgeVerdict {
                Text(jv.verdict)
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 4)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: isVisible)
            }

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(label: "Consistency:", value: summary.consistency)
                summaryRow(label: "Hallucinations:", value: summary.hallucinations)
                summaryRow(label: "Confidence:", value: summary.confidence)

                if let score = summary.confidenceScore {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 6)
                            Rectangle()
                                .fill(confidenceColor(score))
                                .frame(width: geo.size.width * score, height: 6)
                        }
                    }
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.vertical, 8)

            // Key findings / analyst-style bullet points from the Judge
            if !summary.analysisBullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(summary.analysisBullets.enumerated()), id: \.offset) { index, bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("›")
                                .font(RosinTheme.monoCaption)
                                .foregroundColor(RosinTheme.green.opacity(0.6))
                            Text(bullet)
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 6)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(index) * 0.12),
                            value: isVisible
                        )
                    }
                }
                .padding(.top, 4)
            }

            // Per-stage agreement scores overview from the Judge
            if let jv = summary.judgeVerdict, !jv.stageAnalyses.isEmpty {
                HStack(spacing: 10) {
                    Text("STAGES:")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)

                    ForEach(jv.stageAnalyses, id: \.stage) { sa in
                        Text("S\(sa.stage):\(sa.agreementScore)")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(scoreColor(sa.agreementScore))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                Rectangle()
                                    .stroke(scoreColor(sa.agreementScore).opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 4)
            }

            if !summary.contradictions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DISAGREEMENTS DETECTED")
                        .font(RosinTheme.monoCaption)
                        .fontWeight(.medium)
                        .foregroundColor(RosinTheme.destructive)

                    ForEach(summary.contradictions) { contradiction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("\(contradiction.topic)")
                                    .font(RosinTheme.monoCaption)
                                    .foregroundColor(RosinTheme.destructive.opacity(0.8))
                                if contradiction.stageB > 0 {
                                    Text("(Stage \(contradiction.stageA) vs \(contradiction.stageB))")
                                        .font(RosinTheme.monoCaption2)
                                        .foregroundColor(RosinTheme.muted)
                                } else {
                                    Text("(Stage \(contradiction.stageA))")
                                        .font(RosinTheme.monoCaption2)
                                        .foregroundColor(RosinTheme.muted)
                                }
                            }
                            Text(contradiction.description)
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.muted)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RosinTheme.green.opacity(0.3))
                .frame(height: 2)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: isVisible)
        .onAppear { isVisible = true }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(RosinTheme.monoCaption)
                .foregroundColor(RosinTheme.muted)
            Text(value)
                .font(RosinTheme.monoCaption)
        }
    }

    private func confidenceColor(_ score: Double) -> Color {
        if score >= 0.8 { return RosinTheme.green }
        if score >= 0.5 { return .yellow }
        return RosinTheme.destructive
    }

    /// Color for an agreement/overall score (0–100)
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return RosinTheme.green }
        if score >= 50 { return .yellow }
        return RosinTheme.destructive
    }
}
