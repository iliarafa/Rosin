import SwiftUI

// ── Local-only verification history ────────────────────────────────
// All data is stored in UserDefaults on the user's device.
// No server calls, no cloud sync, no data collection.

struct HistoryView: View {
    @State private var items: [VerificationHistoryItem] = []
    @State private var selectedItem: VerificationHistoryItem?
    @State private var confirmClear = false

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
                        Text("100% LOCAL — stored on this device only")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(RosinTheme.muted.opacity(0.3))
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Privacy notice at top
                        Text("100% LOCAL — stored on this device only")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(RosinTheme.muted.opacity(0.3))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

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
                                        // Judge overall score badge (preferred over raw confidence %)
                                        if let jv = item.summary?.judgeVerdict {
                                            Text("\(jv.overallScore)")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(judgeScoreColor(jv.overallScore))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(judgeScoreColor(jv.overallScore).opacity(0.4), lineWidth: 1)
                                                )
                                        } else if let score = item.confidenceScore {
                                            // Fallback: raw confidence % when no Judge verdict
                                            Text("\(Int(score * 100))%")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(confidenceColor(score))
                                        }

                                        if item.contradictionCount > 0 {
                                            Text("\(item.contradictionCount) disagreement\(item.contradictionCount == 1 ? "" : "s")")
                                                .font(RosinTheme.monoCaption2)
                                                .foregroundColor(RosinTheme.destructive)
                                        }

                                        Text("\(item.stages.count) stage\(item.stages.count == 1 ? "" : "s")")
                                            .font(RosinTheme.monoCaption2)
                                            .foregroundColor(RosinTheme.muted)

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
            .toolbar {
                // "Clear All" button with confirmation
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            confirmClear = true
                        } label: {
                            Text("[CLEAR]")
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.muted)
                        }
                    }
                }
            }
            .alert("Clear All History?", isPresented: $confirmClear) {
                Button("Clear All", role: .destructive) {
                    HistoryManager.clearAll()
                    withAnimation { items = [] }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all saved verifications from this device.")
            }
            .sheet(item: $selectedItem) { item in
                HistoryDetailView(item: item)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            HistoryManager.delete(items[index].id)
        }
        withAnimation { items.remove(atOffsets: offsets) }
    }

    private func confidenceColor(_ score: Double) -> Color {
        if score >= 0.8 { return RosinTheme.green }
        if score >= 0.5 { return .yellow }
        return RosinTheme.destructive
    }

    /// Color for the Judge overall score badge (0–100)
    private func judgeScoreColor(_ score: Int) -> Color {
        if score >= 80 { return RosinTheme.green }
        if score >= 50 { return .yellow }
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
