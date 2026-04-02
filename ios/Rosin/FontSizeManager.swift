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

    /// Point size for stage response content text (bumped +2pt for readability)
    var pointSize: CGFloat {
        switch self {
        case .xSmall: return 12
        case .small: return 13
        case .medium: return 15
        case .large: return 17
        case .xLarge: return 19
        }
    }

    /// Line spacing for response content
    var lineSpacing: CGFloat {
        switch self {
        case .xSmall: return 4
        case .small: return 5
        case .medium: return 6
        case .large: return 7
        case .xLarge: return 8
        }
    }
}
