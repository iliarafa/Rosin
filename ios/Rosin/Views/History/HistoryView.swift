import SwiftUI

struct HistoryView: View {
    @State private var items: [VerificationHistoryItem] = []
    @State private var selectedItem: VerificationHistoryItem?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No verifications yet.")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                        Text("Run a verification to see history here.")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.query)
                                        .font(RosinTheme.monoCaption)
                                        .lineLimit(2)

                                    HStack(spacing: 10) {
                                        Text(item.chainSummary)
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted)
                                            .lineLimit(1)

                                        if item.adversarialMode {
                                            Text("[ADV]")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(RosinTheme.destructive)
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        if let score = item.confidenceScore {
                                            Text("\(Int(score * 100))%")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(confidenceColor(score))
                                        }

                                        if item.contradictionCount > 0 {
                                            Text("\(item.contradictionCount) disagreement\(item.contradictionCount == 1 ? "" : "s")")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(RosinTheme.destructive)
                                        }

                                        Spacer()

                                        Text(relativeTime(item.createdAt))
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted.opacity(0.6))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .background(RosinTheme.background)
            .onAppear { items = HistoryManager.loadAll() }
            .sheet(item: $selectedItem) { item in
                HistoryDetailView(item: item)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            HistoryManager.delete(items[index].id)
        }
        items.remove(atOffsets: offsets)
    }

    private func confidenceColor(_ score: Double) -> Color {
        if score >= 0.8 { return RosinTheme.green }
        if score >= 0.5 { return .yellow }
        return RosinTheme.destructive
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        let mins = Int(diff / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
