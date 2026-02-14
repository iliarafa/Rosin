import SwiftUI

@MainActor
class AppearanceManager: ObservableObject {
    @Published var colorScheme: ColorScheme?
    
    private let userDefaultsKey = "selectedColorScheme"
    
    init() {
        // Load saved preference
        if let savedValue = UserDefaults.standard.string(forKey: userDefaultsKey) {
            switch savedValue {
            case "light":
                colorScheme = .light
            case "dark":
                colorScheme = .dark
            default:
                colorScheme = nil // System default
            }
        }
    }
    
    func toggle(currentScheme: ColorScheme) {
        let effectiveScheme = colorScheme ?? currentScheme
        colorScheme = effectiveScheme == .dark ? .light : .dark
        save()
    }

    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        save()
    }

    func isDark(currentScheme: ColorScheme) -> Bool {
        let effectiveScheme = colorScheme ?? currentScheme
        return effectiveScheme == .dark
    }
    
    private func save() {
        let value: String?
        switch colorScheme {
        case .light:
            value = "light"
        case .dark:
            value = "dark"
        case .none:
            value = nil
        }
        
        if let value {
            UserDefaults.standard.set(value, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
}
