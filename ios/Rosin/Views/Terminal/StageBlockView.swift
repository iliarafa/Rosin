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
                        VStack(alignment: .leading, spacing: 10) {
                            // Key claims with confidence + collapsible provenance history
                            ForEach(Array(analysis.claims.enumerated()), id: \.offset) { _, claim in
                                VStack(alignment: .leading, spacing: 4) {
                                    // Claim text with confidence badge
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("[\(claim.confidence)]")
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(scoreColor(claim.confidence))
                                        Text(claim.text)
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    // Provenance — collapsed-by-default "Change History" accordion
                                    if let provenance = claim.provenance, !provenance.isEmpty {
                                        ProvenanceDisclosure(provenance: provenance)
                                            .padding(.leading, 24)
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

// MARK: - Provenance Change History (collapsed-by-default DisclosureGroup)

/// A self-contained disclosure view for a claim's provenance trail.
/// Uses DisclosureGroup for native collapse/expand, matching the terminal aesthetic.
private struct ProvenanceDisclosure: View {
    let provenance: [ProvenanceEntry]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(provenance.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 3) {
                        // Header: icon + model badge + change type
                        HStack(spacing: 6) {
                            Text(changeTypeIcon(entry.changeType))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(changeTypeColor(entry.changeType))

                            // Model + stage badge
                            Text("S\(entry.stage) \(entry.model)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(changeTypeColor(entry.changeType))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .overlay(
                                    Rectangle()
                                        .stroke(changeTypeColor(entry.changeType).opacity(0.3), lineWidth: 1)
                                )

                            Text(entry.changeType.rawValue.uppercased())
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(changeTypeColor(entry.changeType))
                                .tracking(0.5)
                        }

                        // Before → after diff (shown when originalText exists)
                        if let original = entry.originalText, !original.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(original)
                                    .font(.system(size: 12, design: .monospaced))
                                    .strikethrough()
                                    .foregroundColor(RosinTheme.muted.opacity(0.35))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(entry.newText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(RosinTheme.green.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 20)
                        }

                        // Reason in italics
                        Text(entry.reason)
                            .font(.system(size: 11, design: .monospaced))
                            .italic()
                            .foregroundColor(RosinTheme.muted.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.leading, 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
            }
        } label: {
            Text(isExpanded
                 ? "[-] Change History"
                 : "[+] \(provenance.count) change\(provenance.count > 1 ? "s" : "")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(RosinTheme.muted.opacity(0.45))
        }
        .accentColor(RosinTheme.muted.opacity(0.3))
    }

    /// Icon glyph for each provenance change type
    private func changeTypeIcon(_ changeType: ProvenanceEntry.ChangeType) -> String {
        switch changeType {
        case .added: return "+"
        case .modified: return "↔"
        case .corrected: return "✓"
        case .flagged: return "⚠"
        }
    }

    /// Color for provenance change type
    private func changeTypeColor(_ changeType: ProvenanceEntry.ChangeType) -> Color {
        switch changeType {
        case .added: return RosinTheme.green
        case .modified: return .blue
        case .corrected: return .yellow
        case .flagged: return RosinTheme.destructive
        }
    }
}
