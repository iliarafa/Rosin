import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var fontSizeManager = FontSizeManager()
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
            .environmentObject(fontSizeManager)
            .preferredColorScheme(appearanceManager.colorScheme)
        }
    }
}
