import SwiftUI

struct LandingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showTerminal: Bool

    var body: some View {
        ZStack {
            Color("RosinBackground")
                .ignoresSafeArea()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTerminal = true
                }
            } label: {
                Image("RosinLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .colorInvert(colorScheme == .dark)
            }
            .buttonStyle(.plain)
        }
    }
}

private extension View {
    @ViewBuilder
    func colorInvert(_ active: Bool) -> some View {
        if active {
            self.colorInvert()
        } else {
            self
        }
    }
}
