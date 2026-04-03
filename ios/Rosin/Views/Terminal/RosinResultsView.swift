import SwiftUI

struct RosinResultsView: View {
    let query: String
    let stages: [StageOutput]
    let summary: VerificationSummary?
    let onExportCSV: () -> Void
    let onExportPDF: () -> Void
    @EnvironmentObject private var fontSizeManager: FontSizeManager

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Query reminder
            if !query.isEmpty {
                HStack(spacing: 6) {
                    Text("QUERY:")
                        .foregroundColor(RosinTheme.muted.opacity(0.6))
                    Text(query)
                }
                .font(RosinTheme.monoCaption)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            // Final Verified Answer
            if let lastContent = stages.last?.content {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(RosinTheme.green)
                        Text("FINAL VERIFIED ANSWER")
                            .font(RosinTheme.monoCaption)
                            .fontWeight(.medium)
                    }

                    markdownText(lastContent)
                        .font(RosinTheme.responseFont(for: fontSizeManager.sizeCategory))
                        .lineSpacing(fontSizeManager.sizeCategory.lineSpacing)
                        .textSelection(.enabled)
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

            // Contradictions
            if let summary, !summary.contradictions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DISAGREEMENTS DETECTED (\(summary.contradictions.count))")
                        .font(RosinTheme.monoCaption)
                        .fontWeight(.medium)
                        .foregroundColor(RosinTheme.destructive)

                    ForEach(summary.contradictions) { contradiction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(contradiction.topic)
                                    .font(RosinTheme.monoCaption)
                                    .foregroundColor(RosinTheme.destructive.opacity(0.8))
                                Text("Stage \(contradiction.stageA) vs \(contradiction.stageB)")
                                    .font(RosinTheme.monoCaption2)
                                    .foregroundColor(RosinTheme.muted)
                            }
                            Text(contradiction.description)
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.muted)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RosinTheme.destructive.opacity(0.3))
                        .frame(height: 2)
                }
            }

            // Verification Summary
            if let summary {
                VerificationSummaryView(summary: summary)
            }

            // Export buttons
            HStack(spacing: 16) {
                Text("EXPORT:")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted.opacity(0.6))

                Button(action: onExportCSV) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                        Text("[CSV]")
                            .font(RosinTheme.monoCaption2)
                    }
                    .foregroundColor(RosinTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                }

                Button(action: onExportPDF) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                        Text("[PDF]")
                            .font(RosinTheme.monoCaption2)
                    }
                    .foregroundColor(RosinTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.5), value: isVisible)
        .onAppear { isVisible = true }
    }

    private func markdownText(_ string: String) -> Text {
        if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(string)
    }
}
