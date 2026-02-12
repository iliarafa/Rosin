import SwiftUI

struct TerminalOutputView: View {
    let query: String
    let stages: [StageOutput]
    let summary: VerificationSummary?
    let isProcessing: Bool
    let expectedStageCount: Int
    let onExportCSV: () -> Void
    let onExportPDF: () -> Void

    private var allComplete: Bool {
        stages.count == expectedStageCount && stages.allSatisfy { $0.status == .complete }
    }

    var body: some View {
        if stages.isEmpty && !isProcessing {
            EmptyStateView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Query display
                if !query.isEmpty && !stages.isEmpty {
                    HStack(spacing: 4) {
                        Text("QUERY:")
                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                        Text(query)
                    }
                    .font(RosinTheme.monoCaption)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }

                // Stage blocks
                ForEach(stages) { stage in
                    StageBlockView(stage: stage)
                }

                // Verified output
                if allComplete, let lastContent = stages.last?.content {
                    VStack(alignment: .leading, spacing: 8) {
                        DividerLine(thick: true)
                        Text("VERIFIED OUTPUT")
                            .font(RosinTheme.monoCaption)
                            .fontWeight(.medium)
                        DividerLine(thick: true)
                        Text(lastContent)
                            .font(RosinTheme.monoCaption)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                        DividerLine(thick: true)
                    }
                    .padding(12)
                }

                // Summary
                if let summary, allComplete {
                    VerificationSummaryView(summary: summary)
                }

                // Export buttons
                if allComplete && !stages.isEmpty {
                    HStack(spacing: 12) {
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}
