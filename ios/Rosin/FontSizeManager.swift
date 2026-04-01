import SwiftUI

@MainActor
final class FontSizeManager: ObservableObject {
    @Published var sizeCategory: FontSizeCategory {
        didSet { save() }
    }

    private let key = "fontSizeCategory"

    init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let category = FontSizeCategory(rawValue: raw) {
            sizeCategory = category
        } else {
            sizeCategory = .medium
        }
    }

    private func save() {
        UserDefaults.standard.set(sizeCategory.rawValue, forKey: key)
    }
}

enum FontSizeCategory: String, CaseIterable, Identifiable {
    case xSmall
    case small
    case medium
    case large
    case xLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xLarge: return "XL"
        }
    }

    /// Point size for stage response content text
    var pointSize: CGFloat {
        switch self {
        case .xSmall: return 10
        case .small: return 11
        case .medium: return 12
        case .large: return 14
        case .xLarge: return 16
        }
    }

    /// Line spacing for response content
    var lineSpacing: CGFloat {
        switch self {
        case .xSmall: return 3
        case .small: return 4
        case .medium: return 5
        case .large: return 6
        case .xLarge: return 7
        }
    }
}
