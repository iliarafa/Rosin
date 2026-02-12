import SwiftUI

struct VerificationSummaryView: View {
    let summary: VerificationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DividerLine(thick: true)

            Text("VERIFICATION SUMMARY")
                .font(RosinTheme.monoCaption)
                .fontWeight(.medium)
                .foregroundColor(RosinTheme.green)

            DividerLine(thick: true)

            VStack(alignment: .leading, spacing: 6) {
                summaryRow(label: "Consistency:", value: summary.consistency)
                summaryRow(label: "Hallucinations:", value: summary.hallucinations)
                summaryRow(label: "Confidence:", value: summary.confidence)
            }
            .padding(.vertical, 4)

            DividerLine(thick: true)
        }
        .padding(12)
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
}
