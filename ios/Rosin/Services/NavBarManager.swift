import Foundation
import SwiftUI

/// Represents a shortcut that can appear in the bottom navigation bar.
enum NavShortcut: String, CaseIterable, Codable, Identifiable {
    case history
    case apiKeys
    case settings
    case stats
    case recommendations
    case readme
    case theme

    var id: String { rawValue }

    var label: String {
        switch self {
        case .history: return "History"
        case .apiKeys: return "Keys"
        case .settings: return "Settings"
        case .stats: return "Stats"
        case .recommendations: return "Tips"
        case .readme: return "Readme"
        case .theme: return "Theme"
        }
    }

    var icon: String {
        switch self {
        case .history: return "clock"
        case .apiKeys: return "key"
        case .settings: return "gearshape"
        case .stats: return "chart.bar"
        case .recommendations: return "lightbulb"
        case .readme: return "doc.text"
        case .theme: return "moon"
        }
    }
}

/// Persists the user's chosen bottom nav bar shortcuts to UserDefaults.
@MainActor
final class NavBarManager: ObservableObject {
    private static let storageKey = "navBarShortcuts"
    static let defaultShortcuts: [NavShortcut] = [.history, .apiKeys, .settings]

    @Published var shortcuts: [NavShortcut] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([NavShortcut].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = Self.defaultShortcuts
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func toggle(_ shortcut: NavShortcut) {
        if let index = shortcuts.firstIndex(of: shortcut) {
            shortcuts.remove(at: index)
        } else {
            shortcuts.append(shortcut)
        }
    }

    func isEnabled(_ shortcut: NavShortcut) -> Bool {
        shortcuts.contains(shortcut)
    }
}
