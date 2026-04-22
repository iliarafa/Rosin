import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var fontSizeManager = FontSizeManager()
    @StateObject private var modeManager = RosinModeManager()
    @State private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingComplete {
                    LandingView(showTerminal: $onboardingComplete)
                } else {
                    switch modeManager.mode {
                    case .novice:
                        NoviceTerminalView(apiKeyManager: apiKeyManager)
                    case .pro:
                        TerminalView()
                    }
                }
            }
            .environmentObject(apiKeyManager)
            .environmentObject(appearanceManager)
            .environmentObject(fontSizeManager)
            .environmentObject(modeManager)
            .preferredColorScheme(appearanceManager.colorScheme)
            .animation(.default, value: modeManager.mode)
        }
    }
}
