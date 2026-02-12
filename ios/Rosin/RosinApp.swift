import SwiftUI

@main
struct RosinApp: App {
    @StateObject private var apiKeyManager = APIKeyManager()

    var body: some Scene {
        WindowGroup {
            TerminalView()
                .environmentObject(apiKeyManager)
        }
    }
}
