import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var fontSizeManager = FontSizeManager()
    @StateObject private var modeManager = RosinModeManager()
    @StateObject private var auth = AuthViewModel()
    @State private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingComplete {
                    LandingView(showTerminal: $onboardingComplete)
                } else {
                    switch modeManager.mode {
                    case .novice:
                        if auth.isSignedIn {
                            NoviceTerminalView(apiKeyManager: apiKeyManager)
                        } else if auth.isHydrating {
                            hydratingPlaceholder
                        } else {
                            SignInView()
                        }
                    case .pro:
                        TerminalView()
                    }
                }
            }
            .environmentObject(apiKeyManager)
            .environmentObject(appearanceManager)
            .environmentObject(fontSizeManager)
            .environmentObject(modeManager)
            .environmentObject(auth)
            .preferredColorScheme(appearanceManager.colorScheme)
            .animation(.default, value: modeManager.mode)
            .task { await auth.hydrate() }
        }
    }

    private var hydratingPlaceholder: some View {
        VStack(spacing: 8) {
            Text("● ROSIN")
                .foregroundStyle(Color("RosinGreen"))
                .font(.system(.caption, design: .monospaced))
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color("RosinGreen"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("RosinBackground").ignoresSafeArea())
    }
}
