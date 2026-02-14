import SwiftUI

struct DisagreementStatsView: View {
    @State private var totalVerifications = 0
    @State private var averageConfidence: Double?
    @State private var pairs: [HistoryManager.ProviderPairStat] = []

    var body: some View {
        NavigationStack {
            Group {
                if totalVerifications == 0 {
                    VStack(spacing: 8) {
                        Text("Not enough data.")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                        Text("Run multiple verifications to see disagreement patterns.")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Stats row
                            HStack(spacing: 0) {
                                statCard(label: "VERIFICATIONS", value: "\(totalVerifications)")
                                Divider().frame(height: 50)
                                statCard(
                                    label: "AVG CONFIDENCE",
                                    value: averageConfidence.map { "\(Int($0 * 100))%" } ?? "N/A"
                                )
                                Divider().frame(height: 50)
                                statCard(label: "PAIRS", value: "\(pairs.count)")
                            }
                            .padding(.horizontal, 20)

                            // Provider pair list
                            if !pairs.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("DISAGREEMENT RATES")
                                        .font(RosinTheme.monoCaption)
                                        .fontWeight(.medium)
                                        .foregroundColor(RosinTheme.muted)
                                        .padding(.horizontal, 20)

                                    ForEach(pairs) { pair in
                                        HStack {
                                            Text("\(pair.providerA) / \(pair.providerB)")
                                                .font(RosinTheme.monoCaption)

                                            Spacer()

                                            Text("\(pair.disagreements)/\(pair.totalPairings)")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(RosinTheme.muted)

                                            Text("\(Int(pair.rate * 100))%")
                                                .font(RosinTheme.monoCaption)
                                                .fontWeight(.medium)
                                                .foregroundColor(rateColor(pair.rate))
                                                .frame(width: 44, alignment: .trailing)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)

                                        if pair.id != pairs.last?.id {
                                            Divider().padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Disagreement Stats")
            .navigationBarTitleDisplayMode(.inline)
            .background(RosinTheme.background)
            .onAppear {
                let stats = HistoryManager.disagreementStats()
                totalVerifications = stats.totalVerifications
                averageConfidence = stats.averageConfidence
                pairs = stats.pairs
            }
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted)
            Text(value)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate > 0.2 { return RosinTheme.destructive }
        if rate > 0.1 { return .yellow }
        return RosinTheme.green
    }
}
