import SwiftUI

struct NoviceTerminalView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @StateObject private var viewModel: NoviceTerminalViewModel
    @State private var showSettings = false

    init(apiKeyManager: APIKeyManager) {
        _viewModel = StateObject(wrappedValue: NoviceTerminalViewModel(apiKeyManager: apiKeyManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.gray.opacity(0.2))
            Group {
                switch viewModel.phase {
                case .idle:
                    inputView
                case .verifying(let status):
                    verifyingView(status: status)
                case .done(let result):
                    NoviceResultView(result: result, onAskAnother: viewModel.reset)
                case .failed(let error):
                    errorView(error: error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        }
        .background(Color("RosinBackground").ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(apiKeyManager)
        }
    }

    private var header: some View {
        HStack {
            Text("● ROSIN")
                .foregroundStyle(Color("RosinGreen"))
            Text("[ NOVICE MODE ]")
                .foregroundStyle(.secondary)
                .tracking(2)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("novice-settings")
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var inputView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Ask a question. We'll verify it across multiple AIs.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 8) {
                Text(">")
                    .foregroundStyle(Color("RosinGreen"))
                TextField(
                    "e.g. Is creatine safe for teenagers?",
                    text: $viewModel.query,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...4)
            }
            .font(.system(.body, design: .monospaced))
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Button {
                viewModel.verify()
            } label: {
                Text("[ VERIFY ]")
                    .tracking(3)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color("RosinGreen"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color("RosinGreen"), lineWidth: 1)
                    )
            }
            .disabled(viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("novice-verify")

            Spacer()
            Spacer()
        }
    }

    private func verifyingView(status: String) -> some View {
        VStack {
            Spacer()
            Text(status)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .opacity(0.6)
            Spacer()
            Spacer()
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text("[ VERIFICATION FAILED ]")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.red)
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Try again") { viewModel.reset() }
                .buttonStyle(.borderless)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Spacer()
        }
    }
}
