import SwiftUI

/// Fixed bottom navigation bar with LIVE toggle, ADV toggle, and Keys button.
struct BottomNavBar: View {
    @Binding var isLiveResearch: Bool
    @Binding var isAdversarialMode: Bool
    let onKeysTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // LIVE toggle
            Button {
                isLiveResearch.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, design: .monospaced))
                    Text("LIVE")
                        .font(RosinTheme.monoCaption2)
                }
                .foregroundColor(isLiveResearch ? RosinTheme.green : RosinTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ADV toggle
            Button {
                isAdversarialMode.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bolt")
                        .font(.system(size: 16, design: .monospaced))
                    Text("ADV")
                        .font(RosinTheme.monoCaption2)
                }
                .foregroundColor(isAdversarialMode ? RosinTheme.destructive : RosinTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Keys
            Button(action: onKeysTap) {
                VStack(spacing: 4) {
                    Image(systemName: "key")
                        .font(.system(size: 16, design: .monospaced))
                    Text("Keys")
                        .font(RosinTheme.monoCaption2)
                }
                .foregroundColor(RosinTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}
