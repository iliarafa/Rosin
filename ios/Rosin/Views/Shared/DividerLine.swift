import SwiftUI

struct DividerLine: View {
    var thick = false

    var body: some View {
        Text(thick ? RosinTheme.thickDivider : RosinTheme.thinDivider)
            .font(RosinTheme.monoCaption2)
            .foregroundColor(RosinTheme.muted.opacity(0.6))
            .lineLimit(1)
    }
}
