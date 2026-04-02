import SwiftUI

struct StageBlockView: View {
    let stage: StageOutput

    @EnvironmentObject private var fontSizeManager: FontSizeManager
    @State private var cursorVisible = true
    @State private var showDetails = false

    private var responseFont: Font {
        RosinTheme.responseFont(for: fontSizeManager.sizeCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Stage header with optional agreement score badge
            HStack(spacing: 6) {
                Text(">")
                    .foregroundColor(RosinTheme.muted)
                Text("STAGE [\(stage.stage)]:")
                    .fontWeight(.medium)
                Text("\(stage.model.provider.displayName) / \(stage.model.model)")
                    .foregroundColor(RosinTheme.muted)
                StatusIndicator(status: stage.status)

                // Agreement score badge — shown after Judge analysis is available
                if let analysis = stage.analysis {
                    Spacer()
                    Text("\(analysis.agreementScore)")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(scoreColor(analysis.agreementScore))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            Rectangle()
                                .stroke(scoreColor(analysis.agreementScore).opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .font(RosinTheme.monoCaption)

            // Content
            HStack(alignment: .bottom, spacing: 0) {
                Text(stage.content)
                    .font(responseFont)
                    .lineSpacing(fontSizeManager.sizeCategory.lineSpacing)
                    .textSelection(.enabled)

                if stage.status == .streaming {
                    Text("_")
                        .font(responseFont)
                        .foregroundColor(RosinTheme.muted)
                        .opacity(cursorVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(RosinTheme.pulseAnimation) {
                                cursorVisible.toggle()
                            }
                        }
                }
            }

            // Error message
            if let error = stage.error {
                Text("ERROR: \(error)")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.destructive)
            }

            // Expandable Judge analysis details (claims + hallucination flags)
            if let analysis = stage.analysis,
               (!analysis.hallucinationFlags.isEmpty || !analysis.claims.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showDetails.toggle() }) {
                        Text(showDetails
                             ? "[-] Hide analysis"
                             : "[+] \(analysis.claims.count) claims, \(analysis.hallucinationFlags.count) flags")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                    }
                    .buttonStyle(.plain)

                    if showDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            // Key claims with confidence + provenance trail
                            ForEach(Array(analysis.claims.enumerated()), id: \.offset) { _, claim in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("[\(claim.confidence)]")
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(scoreColor(claim.confidence))
                                        Text(claim.text)
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    // Provenance trail — shows which model added/modified/corrected this claim
                                    if let provenance = claim.provenance, !provenance.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(Array(provenance.enumerated()), id: \.offset) { _, entry in
                                                HStack(spacing: 4) {
                                                    Text("S\(entry.stage)")
                                                        .foregroundColor(changeTypeColor(entry.changeType))
                                                    Text(entry.model)
                                                        .foregroundColor(.primary.opacity(0.5))
                                                    Text(entry.changeType.rawValue.uppercased())
                                                        .foregroundColor(changeTypeColor(entry.changeType))
                                                    Text(entry.reason)
                                                        .foregroundColor(RosinTheme.muted.opacity(0.6))
                                                        .lineLimit(1)
                                                }
                                                .font(.system(size: 9, design: .monospaced))
                                            }
                                        }
                                        .padding(.leading, 30)
                                    }
                                }
                            }

                            // Hallucination flags
                            if !analysis.hallucinationFlags.isEmpty {
                                Text("FLAGGED:")
                                    .font(RosinTheme.monoCaption2)
                                    .foregroundColor(RosinTheme.destructive.opacity(0.8))
                                    .fontWeight(.medium)
                                ForEach(Array(analysis.hallucinationFlags.enumerated()), id: \.offset) { _, flag in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("[\(flag.severity.rawValue.uppercased())]")
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(severityColor(flag.severity))
                                        Text("\(flag.claim) — \(flag.reason)")
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            // Corrections
                            if !analysis.corrections.isEmpty {
                                Text("CORRECTIONS:")
                                    .font(RosinTheme.monoCaption2)
                                    .foregroundColor(RosinTheme.green.opacity(0.8))
                                    .fontWeight(.medium)
                                ForEach(Array(analysis.corrections.enumerated()), id: \.offset) { _, correction in
                                    Text("• \(correction)")
                                        .font(RosinTheme.monoCaption2)
                                        .foregroundColor(RosinTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.leading, 8)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.15))
                                .frame(width: 2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            stage.status == .streaming
                ? Color.primary.opacity(0.03)
                : Color.clear
        )
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    /// Color for an agreement/confidence score (0–100)
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return RosinTheme.green }
        if score >= 50 { return .yellow }
        return RosinTheme.destructive
    }

    /// Color for hallucination flag severity
    private func severityColor(_ severity: HallucinationFlag.HallucinationSeverity) -> Color {
        switch severity {
        case .high: return RosinTheme.destructive
        case .medium: return .yellow
        case .low: return RosinTheme.muted
        }
    }

    /// Color for provenance change type badges
    private func changeTypeColor(_ changeType: ProvenanceEntry.ChangeType) -> Color {
        switch changeType {
        case .added: return RosinTheme.green
        case .modified: return .blue
        case .corrected: return .yellow
        case .flagged: return RosinTheme.destructive
        }
    }
}
