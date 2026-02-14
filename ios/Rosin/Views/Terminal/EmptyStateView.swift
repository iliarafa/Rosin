import SwiftUI

struct EmptyStateView: View {
    @State private var cursorVisible = true

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("ROSIN \u{2013} PURE OUTPUT")
                .font(RosinTheme.monoCaption)
                .foregroundColor(.primary.opacity(0.6))

            Text("Launch a query through multiple LLMs. Verify, refine and detect hallucinations.")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 2) {
                Text("$ ")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted.opacity(0.4))
                Text("_")
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(RosinTheme.muted.opacity(0.4))
                    .opacity(cursorVisible ? 1 : 0)
                    .onAppear {
                        withAnimation(RosinTheme.pulseAnimation) {
                            cursorVisible.toggle()
                        }
                    }
            }
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
