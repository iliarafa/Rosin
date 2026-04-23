import SwiftUI

struct EmailCodeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var phase: Phase = .email
    @State private var error: String?
    @State private var sending = false

    enum Phase { case email, code }

    var body: some View {
        VStack(spacing: 20) {
            Text(phase == .email ? "Enter your email" : "Enter your 6-digit code")
                .font(.system(.headline, design: .monospaced))
                .padding(.top, 24)

            if phase == .email {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                    .padding(.horizontal, 24)

                Button {
                    Task {
                        sending = true; error = nil
                        defer { sending = false }
                        do {
                            try await auth.requestEmailCode(email)
                            phase = .code
                        } catch {
                            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed"
                        }
                    }
                } label: {
                    Text(sending ? "Sending..." : "Send code")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("RosinGreen")))
                }
                .disabled(sending || email.isEmpty)
                .padding(.horizontal, 24)
            } else {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                    .padding(.horizontal, 24)
                    .onChange(of: code) { newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }

                Button {
                    Task {
                        await auth.verifyEmailCode(email: email, code: code)
                        if auth.isSignedIn { dismiss() }
                        else { error = auth.error ?? "Invalid code" }
                    }
                } label: {
                    Text("Verify").font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("RosinGreen")))
                }
                .disabled(code.count != 6)
                .padding(.horizontal, 24)
            }

            if let error { Text(error).foregroundColor(Color("RosinDestructive")).font(.system(.caption, design: .monospaced)) }

            Spacer()
        }
        .padding(.top, 12)
        .background(Color("RosinBackground").ignoresSafeArea())
    }
}
