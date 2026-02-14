import SwiftUI

struct HistoryDetailView: View {
    let item: VerificationHistoryItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Query
                    HStack(spacing: 6) {
                        Text("QUERY:")
                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                        Text(item.query)
                    }
                    .font(RosinTheme.monoCaption)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                    // Stages
                    ForEach(item.stages) { stage in
                        StageBlockView(stage: stage)
                    }

                    // Contradictions
                    if let summary = item.summary, !summary.contradictions.isEmpty {
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
                    if let lastContent = item.stages.last?.content {
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
                    if let summary = item.summary {
                        VerificationSummaryView(summary: summary)
                    }
                }
            }
            .navigationTitle("Verification Detail")
            .navigationBarTitleDisplayMode(.inline)
            .background(RosinTheme.background)
        }
    }
}
