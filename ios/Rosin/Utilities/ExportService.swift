import UIKit

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

    // MARK: - PDF

    static func generatePDF(query: String, stages: [StageOutput]) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let mutedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func beginNewPage() {
                context.beginPage()
                y = margin
            }

            beginNewPage()

            // Title
            let title = "MULTI-LLM VERIFICATION RESULTS"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 24

            // Divider
            let divider = String(repeating: "\u{2500}", count: 70)
            divider.draw(at: CGPoint(x: margin, y: y), withAttributes: mutedAttrs)
            y += 18

            // Query
            let queryLabel = "QUERY: \(query)"
            let queryRect = CGRect(x: margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude)
            let querySize = (queryLabel as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: bodyAttrs,
                context: nil
            )
            ensureSpace(querySize.height + 20)
            (queryLabel as NSString).draw(in: queryRect, withAttributes: bodyAttrs)
            y += querySize.height + 20

            // Stages
            for stage in stages {
                let stageHeader = "STAGE \(stage.stage): \(stage.model.provider.displayName.uppercased()) / \(stage.model.model)"
                ensureSpace(40)
                stageHeader.draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
                y += 18

                let contentRect = CGRect(x: margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude)
                let contentSize = (stage.content as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: bodyAttrs,
                    context: nil
                )

                // Split long content across pages
                let lines = stage.content.components(separatedBy: "\n")
                for line in lines {
                    let lineSize = (line as NSString).boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: bodyAttrs,
                        context: nil
                    )
                    ensureSpace(lineSize.height + 4)
                    let lineRect = CGRect(x: margin, y: y, width: contentWidth, height: lineSize.height + 4)
                    (line as NSString).draw(in: lineRect, withAttributes: bodyAttrs)
                    y += lineSize.height + 4
                }

                y += 12
                ensureSpace(14)
                divider.draw(at: CGPoint(x: margin, y: y), withAttributes: mutedAttrs)
                y += 18
            }

            // Verified output
            if let lastStage = stages.last {
                ensureSpace(30)
                "VERIFIED OUTPUT".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
                y += 20

                let verifiedLines = lastStage.content.components(separatedBy: "\n")
                for line in verifiedLines {
                    let lineSize = (line as NSString).boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: bodyAttrs,
                        context: nil
                    )
                    ensureSpace(lineSize.height + 4)
                    let lineRect = CGRect(x: margin, y: y, width: contentWidth, height: lineSize.height + 4)
                    (line as NSString).draw(in: lineRect, withAttributes: bodyAttrs)
                    y += lineSize.height + 4
                }
            }
        }
    }
}
