import Foundation
import SwiftUI

enum RosinMode: String {
    case novice
    case pro
}

@MainActor
final class RosinModeManager: ObservableObject {
    private let storageKey = "rosin.mode"

    @Published var mode: RosinMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: storageKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        self.mode = RosinMode(rawValue: stored ?? "") ?? .novice
    }
}
