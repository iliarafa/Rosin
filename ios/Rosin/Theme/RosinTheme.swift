import SwiftUI

enum RosinTheme {
    // MARK: - Colors
    static let green = Color("RosinGreen")
    static let destructive = Color("RosinDestructive")
    static let background = Color("RosinBackground")
    static let muted = Color("RosinMuted")

    // MARK: - Fonts
    static let monoCaption = Font.system(.caption, design: .monospaced)
    static let monoCaption2 = Font.system(.caption2, design: .monospaced)
    static let monoFootnote = Font.system(.footnote, design: .monospaced)
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSubheadline = Font.system(.subheadline, design: .monospaced)
    static let monoHeadline = Font.system(.headline, design: .monospaced)

    // MARK: - Divider strings
    static let thinDivider = String(repeating: "\u{2500}", count: 50)
    static let thickDivider = String(repeating: "\u{2550}", count: 50)

    // MARK: - Animation
    static let pulseAnimation = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
}
