import SwiftUI

struct FreeGateView: View {
    let onOpenProvider: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("[ FREE TIER EXHAUSTED ]")
                .foregroundColor(.orange)
                .font(.system(.caption, design: .monospaced)).tracking(2)
            Text("You've used your 3 free verifications.\nAdd your own API keys to keep going.")
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                providerButton("Get an Anthropic key", url: URL(string: "https://console.anthropic.com/settings/keys")!)
                providerButton("Get a Gemini key", url: URL(string: "https://aistudio.google.com/app/apikey")!)
                providerButton("Get an xAI key", url: URL(string: "https://console.x.ai/")!)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Spacer()
        }
        .background(Color("RosinBackground").ignoresSafeArea())
    }

    private func providerButton(_ label: String, url: URL) -> some View {
        Button {
            onOpenProvider(url)
        } label: {
            Text(label).font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
        }
    }
}
