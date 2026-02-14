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

                // Stage blocks
                ForEach(stages) { stage in
                    StageBlockView(stage: stage)
                }

                // Contradictions (before verified output)
                if allComplete, let summary, !summary.contradictions.isEmpty {
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
                                        .fontWeight(.medium)
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

                // Verified output
                if allComplete, let lastContent = stages.last?.content {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("VERIFIED OUTPUT")
                            .font(RosinTheme.monoCaption)
                            .fontWeight(.medium)
                        Text(lastContent)
                            .font(RosinTheme.monoCaption)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 2)
                    }
                }

                // Summary
                if let summary, allComplete {
                    VerificationSummaryView(summary: summary)
                }

                // Export buttons
                if allComplete && !stages.isEmpty {
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
            }
        }
    }
}
