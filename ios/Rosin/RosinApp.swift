import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @State private var showTerminal = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showTerminal {
                    TerminalView()
                        .environmentObject(apiKeyManager)
                        .transition(.opacity)
                } else {
                    LandingView(showTerminal: $showTerminal)
                        .transition(.opacity)
                }
            }
            .environmentObject(appearanceManager)
            .preferredColorScheme(appearanceManager.colorScheme)
        }
    }
}
