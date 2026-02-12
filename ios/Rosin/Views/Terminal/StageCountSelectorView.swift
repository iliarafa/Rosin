import SwiftUI

struct StageCountSelectorView: View {
    let value: Int
    let onChange: (Int) -> Void
    let disabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("STAGES:")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted)

            Menu {
                Button { onChange(2) } label: {
                    HStack {
                        Text("2")
                        if value == 2 { Image(systemName: "checkmark") }
                    }
                }
                Button { onChange(3) } label: {
                    HStack {
                        Text("3")
                        if value == 3 { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                Text("\(value)")
                    .font(RosinTheme.monoCaption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(disabled)
        }
    }
}
