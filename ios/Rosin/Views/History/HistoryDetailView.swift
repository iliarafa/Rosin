import SwiftUI

struct HistoryDetailView: View {
    let item: VerificationHistoryItem
    @State private var shareItem: ShareItem?

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

                    // Privacy footer
                    Text("Stored locally on this device • Private")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(RosinTheme.muted.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Verification Detail")
            .navigationBarTitleDisplayMode(.inline)
            .background(RosinTheme.background)
            .toolbar {
                // Export PDF button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportPDF()
                    } label: {
                        Text("[PDF]")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheetRepresentable(items: item.items)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Generate a full verification report PDF and present the share sheet.
    /// 100% local — no data leaves the device.
    private func exportPDF() {
        let pdfData = ExportService.generatePDF(
            query: item.query,
            stages: item.stages,
            summary: item.summary
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rosin-report-\(Int(Date().timeIntervalSince1970)).pdf")
        try? pdfData.write(to: tempURL)
        shareItem = ShareItem(items: [tempURL])
    }
}
