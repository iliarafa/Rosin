import SwiftUI

struct VerificationSummaryView: View {
    let summary: VerificationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VERIFICATION SUMMARY")
                .font(RosinTheme.monoCaption)
                .fontWeight(.medium)
                .foregroundColor(RosinTheme.green)

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(label: "Consistency:", value: summary.consistency)
                summaryRow(label: "Hallucinations:", value: summary.hallucinations)
                summaryRow(label: "Confidence:", value: summary.confidence)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RosinTheme.green.opacity(0.3))
                .frame(height: 2)
        }
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
