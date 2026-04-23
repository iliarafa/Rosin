import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showEmailFlow = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Text("● ROSIN").foregroundColor(Color("RosinGreen")).font(.system(.caption, design: .monospaced))
                Text("[ SIGN IN ]").foregroundColor(.secondary).font(.system(.caption2, design: .monospaced)).tracking(2)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 48)
                    .overlay(
                        Button(action: { Task { await auth.signInWithApple() } }) {
                            Color.clear
                        }
                    )

                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    Text("Continue with Google")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                }

                Button {
                    showEmailFlow = true
                } label: {
                    Text("Continue with Email")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                }
            }
            .padding(.horizontal, 24)

            if let error = auth.error {
                Text(error).foregroundColor(Color("RosinDestructive"))
                    .font(.system(.caption, design: .monospaced))
            }

            Spacer()
        }
        .background(Color("RosinBackground").ignoresSafeArea())
        .sheet(isPresented: $showEmailFlow) {
            EmailCodeView().environmentObject(auth)
        }
    }
}
