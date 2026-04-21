import SwiftUI

struct TrustScoreBannerView: View {
    let score: Int?
    let aiCount: Int
    let sourceCount: Int

    var body: some View {
        Group {
            if let s = score {
                let b = TrustScoreCalculator.band(s)
                VStack(alignment: .leading, spacing: 6) {
                    Text("[ VERIFIED ]")
                        .font(.system(.caption, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(color(b).opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(s)%")
                            .font(.system(size: 44, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color(b))
                        Text(label(b))
                            .font(.system(.footnote, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(color(b))
                    }
                    Text("\(aiCount) AIs agreed · \(sourceCount) sources confirmed")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(color(b).opacity(0.7))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color(b).opacity(0.4), lineWidth: 1)
                )
            } else {
                Text("[ COULD NOT VERIFY ]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.red.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private func label(_ band: TrustBand) -> String {
        switch band {
        case .high: return "Highly verified"
        case .partial: return "Partially verified"
        case .low: return "Low confidence — treat with skepticism"
        }
    }

    private func color(_ band: TrustBand) -> Color {
        switch band {
        case .high: return Color("RosinGreen")
        case .partial: return .yellow
        case .low: return Color("RosinDestructive")
        }
    }
}
