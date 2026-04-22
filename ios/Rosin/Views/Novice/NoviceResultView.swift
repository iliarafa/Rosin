import SwiftUI

struct NoviceResultView: View {
    let result: NoviceTerminalViewModel.Result
    let onAskAnother: () -> Void

    @State private var showAllSources = false
    @State private var showVerification = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TrustScoreBannerView(
                    score: result.trustScore,
                    aiCount: result.aiCount,
                    sourceCount: result.verifiedSourceCount
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("YOU ASKED")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("\"\(result.question)\"")
                        .font(.system(.footnote, design: .monospaced))
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Text(result.answer)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color("RosinGreen").opacity(0.4))
                            .frame(width: 2)
                    }

                sourcesSection

                HStack(spacing: 16) {
                    Button {
                        onAskAnother()
                    } label: {
                        Text("[ ASK ANOTHER ]")
                            .tracking(2)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    }
                    .accessibilityIdentifier("novice-ask-another")

                    Button {
                        showVerification.toggle()
                    } label: {
                        Text("see how it was verified")
                            .underline()
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if showVerification {
                    Text("For the full per-stage scoring, claim provenance, and Judge details, switch to Pro mode from Settings.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var sourcesSection: some View {
        let previewCount = min(2, result.sources.count)
        let previews = Array(result.sources.prefix(previewCount))
        let rest = Array(result.sources.dropFirst(previewCount))

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                showAllSources.toggle()
            } label: {
                Text("[ sources \(showAllSources ? "▲" : "▼") ]")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            ForEach(previews) { sourceRow($0) }
            if showAllSources {
                ForEach(rest) { sourceRow($0) }
            }
        }
    }

    private func sourceRow(_ source: NoviceTerminalViewModel.Source) -> some View {
        HStack(spacing: 8) {
            Text(source.status.hasPrefix("VERIFIED") ? "✓" : "✗")
                .foregroundStyle(source.status.hasPrefix("VERIFIED") ? Color("RosinGreen") : .red)
            if let url = URL(string: source.url) {
                Link(source.title, destination: url)
                    .foregroundStyle(.primary)
            } else {
                Text(source.title)
            }
        }
        .font(.system(.caption2, design: .monospaced))
    }
}
