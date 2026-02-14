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
    
    func toggle() {
        switch colorScheme {
        case .none:
            colorScheme = .light
        case .light:
            colorScheme = .dark
        case .dark:
            colorScheme = nil
        }
        save()
    }
    
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        save()
    }
    
    var displayText: String {
        switch colorScheme {
        case .none:
            return "[THEME:SYS]"
        case .light:
            return "[THEME:LHT]"
        case .dark:
            return "[THEME:DRK]"
        }
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
