import UIKit

// ── Export Service ──────────────────────────────────────────────────
// 100% local — generates PDF and CSV on-device. No data leaves the device.

enum ExportService {
    // MARK: - CSV

    static func generateCSV(query: String, stages: [StageOutput]) -> String {
        var lines: [String] = []
        lines.append("Query,\(escapeCSV(query))")
        lines.append("")
        lines.append("Stage,Provider,Model,Content")

        for stage in stages {
            let row = [
                "\(stage.stage)",
                stage.model.provider.rawValue,
                stage.model.model,
                escapeCSV(stage.content)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private static func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }

    // MARK: - PDF (Full Verification Report)
    // Generates a professional "ROSIN AI — VERIFICATION REPORT" with
    // Judge verdict, per-stage claims with provenance, hallucination flags,
    // and the final verified answer. Uses monospace fonts and green accents.

    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 40
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    // Color palette matching the terminal aesthetic
    private static let green = UIColor(red: 0.13, green: 0.76, blue: 0.37, alpha: 1)    // #22c55e
    private static let mutedGray = UIColor(red: 0.53, green: 0.53, blue: 0.53, alpha: 1) // #888
    private static let bgDark = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)    // #0f0f0f
    private static let cardBg = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)    // #1a1a1a
    private static let textLight = UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1) // #ddd

    // Font helpers
    private static func monoFont(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// Score color matching the terminal aesthetic (0–100 scale)
    private static func scoreColor(_ score: Int) -> UIColor {
        if score >= 80 { return green }
        if score >= 50 { return UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1) } // yellow
        return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1) // red
    }

    /// Change type color for provenance entries
    private static func changeTypeColor(_ ct: ProvenanceEntry.ChangeType) -> UIColor {
        switch ct {
        case .added: return green
        case .modified: return UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1) // blue
        case .corrected: return UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1) // yellow
        case .flagged: return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1) // red
        }
    }

    /// Change type icon glyph
    private static func changeTypeIcon(_ ct: ProvenanceEntry.ChangeType) -> String {
        switch ct {
        case .added: return "+"
        case .modified: return "↔"
        case .corrected: return "✓"
        case .flagged: return "⚠"
        }
    }

    static func generatePDF(
        query: String,
        stages: [StageOutput],
        summary: VerificationSummary? = nil
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    context.beginPage()
                    y = margin
                    // Draw dark background on new page
                    bgDark.setFill()
                    UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                }
            }

            func beginNewPage() {
                context.beginPage()
                y = margin
                bgDark.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            }

            /// Draw text at current y, advancing y. Returns height drawn.
            @discardableResult
            func drawText(_ text: String, attrs: [NSAttributedString.Key: Any], indent: CGFloat = 0, maxWidth: CGFloat? = nil) -> CGFloat {
                let w = (maxWidth ?? contentWidth) - indent
                let rect = CGRect(x: margin + indent, y: y, width: w, height: .greatestFiniteMagnitude)
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: w, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attrs,
                    context: nil
                )
                let h = ceil(size.height) + 2
                ensureSpace(h)
                (text as NSString).draw(in: CGRect(x: margin + indent, y: y, width: w, height: h), withAttributes: attrs)
                y += h
                return h
            }

            /// Draw a thin horizontal divider
            func drawDivider(color: UIColor = mutedGray.withAlphaComponent(0.3)) {
                ensureSpace(8)
                color.setFill()
                UIRectFill(CGRect(x: margin, y: y + 3, width: contentWidth, height: 1))
                y += 8
            }

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(14, weight: .bold),
                .foregroundColor: green
            ]
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(8),
                .foregroundColor: mutedGray
            ]
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(10, weight: .bold),
                .foregroundColor: textLight
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(9),
                .foregroundColor: textLight
            ]
            let mutedBodyAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(9),
                .foregroundColor: mutedGray
            ]
            let greenBodyAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont(9),
                .foregroundColor: green
            ]

            // ── Page 1: Header ──
            beginNewPage()

            drawText("ROSIN AI — VERIFICATION REPORT", attrs: titleAttrs)
            y += 4
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            drawText("\(dateStr) • \(stages.count) stages • Generated 100% locally", attrs: metaAttrs)
            y += 4
            drawDivider(color: green.withAlphaComponent(0.3))
            y += 8

            // ── Query ──
            drawText("QUERY", attrs: [.font: monoFont(8), .foregroundColor: mutedGray])
            y += 2
            drawText(query, attrs: bodyAttrs)
            y += 12

            // ── Judge Verdict ──
            if let jv = summary?.judgeVerdict {
                ensureSpace(60)

                // Box background
                cardBg.setFill()
                let boxTop = y
                // We'll draw content first, then fill background below

                drawText("JUDGE VERDICT", attrs: [.font: monoFont(10, weight: .bold), .foregroundColor: green])
                y += 2

                let scoreAttrs: [NSAttributedString.Key: Any] = [
                    .font: monoFont(12, weight: .bold),
                    .foregroundColor: scoreColor(jv.overallScore)
                ]
                drawText("\(jv.overallScore)/100 — \(jv.confidence.capitalized) confidence", attrs: scoreAttrs)
                y += 4

                drawText(jv.verdict, attrs: bodyAttrs)
                y += 6

                for finding in jv.keyFindings {
                    drawText("› \(finding)", attrs: greenBodyAttrs, indent: 8)
                    y += 1
                }

                // Stage scores row
                let scoreRow = jv.stageAnalyses.map { "S\($0.stage):\($0.agreementScore)" }.joined(separator: "  ")
                y += 4
                drawText("STAGES: \(scoreRow)", attrs: mutedBodyAttrs)
                y += 12

                drawDivider()
            }

            // ── Pipeline Stages ──
            for stage in stages {
                ensureSpace(30)

                // Stage header with optional score
                var stageTitle = "STAGE \(stage.stage): \(stage.model.provider.displayName.uppercased()) / \(stage.model.model)"
                if let analysis = stage.analysis {
                    stageTitle += "  [\(analysis.agreementScore)]"
                }
                drawText(stageTitle, attrs: headerAttrs)
                y += 4

                // Stage content (line by line for pagination)
                for line in stage.content.components(separatedBy: "\n") {
                    drawText(line.isEmpty ? " " : line, attrs: bodyAttrs)
                }
                y += 4

                // Claims with provenance
                if let analysis = stage.analysis {
                    for claim in analysis.claims {
                        let claimColor = scoreColor(claim.confidence)
                        let claimAttrs: [NSAttributedString.Key: Any] = [
                            .font: monoFont(8),
                            .foregroundColor: claimColor
                        ]
                        drawText("[\(claim.confidence)] \(claim.text)", attrs: claimAttrs, indent: 8)

                        // Provenance trail
                        if let provenance = claim.provenance {
                            for entry in provenance {
                                let icon = changeTypeIcon(entry.changeType)
                                let color = changeTypeColor(entry.changeType)
                                let provAttrs: [NSAttributedString.Key: Any] = [
                                    .font: monoFont(7),
                                    .foregroundColor: color
                                ]
                                drawText("\(icon) S\(entry.stage) \(entry.model) \(entry.changeType.rawValue.uppercased())", attrs: provAttrs, indent: 20)

                                if let original = entry.originalText, !original.isEmpty {
                                    let strikeAttrs: [NSAttributedString.Key: Any] = [
                                        .font: monoFont(7),
                                        .foregroundColor: mutedGray.withAlphaComponent(0.5),
                                        .strikethroughStyle: NSUnderlineStyle.single.rawValue
                                    ]
                                    drawText(original, attrs: strikeAttrs, indent: 28)
                                    drawText(entry.newText, attrs: [.font: monoFont(7), .foregroundColor: green.withAlphaComponent(0.8)], indent: 28)
                                }

                                let reasonAttrs: [NSAttributedString.Key: Any] = [
                                    .font: UIFont.italicSystemFont(ofSize: 7),
                                    .foregroundColor: mutedGray.withAlphaComponent(0.6)
                                ]
                                drawText(entry.reason, attrs: reasonAttrs, indent: 28)
                            }
                        }
                    }

                    // Hallucination flags
                    for flag in analysis.hallucinationFlags {
                        let sevColor: UIColor = flag.severity == .high
                            ? UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
                            : flag.severity == .medium
                                ? UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1)
                                : mutedGray
                        let flagAttrs: [NSAttributedString.Key: Any] = [
                            .font: monoFont(8),
                            .foregroundColor: sevColor
                        ]
                        drawText("[\(flag.severity.rawValue.uppercased())] \(flag.claim) — \(flag.reason)", attrs: flagAttrs, indent: 8)
                    }
                }

                y += 4
                drawDivider()
            }

            // ── Final Verified Answer ──
            if let lastContent = stages.last?.content {
                ensureSpace(30)
                drawText("FINAL VERIFIED ANSWER", attrs: [.font: monoFont(10, weight: .bold), .foregroundColor: green])
                y += 4
                for line in lastContent.components(separatedBy: "\n") {
                    drawText(line.isEmpty ? " " : line, attrs: bodyAttrs)
                }
                y += 8
            }

            // ── Summary ──
            if let summary {
                drawDivider(color: green.withAlphaComponent(0.3))
                ensureSpace(20)
                drawText("VERIFICATION SUMMARY", attrs: [.font: monoFont(9, weight: .bold), .foregroundColor: green])
                y += 4
                drawText("Consistency: \(summary.consistency)", attrs: mutedBodyAttrs)
                drawText("Hallucinations: \(summary.hallucinations)", attrs: mutedBodyAttrs)
                drawText("Confidence: \(summary.confidence)", attrs: mutedBodyAttrs)
                y += 8
            }

            // ── Footer ──
            ensureSpace(30)
            drawDivider()
            drawText("Generated 100% locally on device • No data was collected or sent • Private", attrs: metaAttrs)
        }
    }
}
