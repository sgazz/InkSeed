import SwiftUI

enum ThemeMode: Int {
    case premium
    case junior
    case dark
}

struct ThemePalette {
    let background: Color
    let secondaryBackground: Color
    let ink: Color
    let accent: Color
    let playerOne: Color
    let playerTwo: Color
}

enum AppTheme {
    static func palette(for mode: ThemeMode) -> ThemePalette {
        switch mode {
        case .premium:
            return ThemePalette(
                background: Color(hex: 0xF6F2E8),
                secondaryBackground: Color(hex: 0xEFE9DC),
                ink: Color(hex: 0x1C1C1C),
                accent: Color(hex: 0x7C3AED),
                playerOne: Color(hex: 0x6D47C8),
                playerTwo: Color(hex: 0x4363C7)
            )
        case .junior:
            return ThemePalette(
                background: Color(hex: 0xFFF9F2),
                secondaryBackground: Color(hex: 0xF5EFE4),
                ink: Color(hex: 0x1F2229),
                accent: Color(hex: 0x56A3FF),
                playerOne: Color(hex: 0xFF8A77),
                playerTwo: Color(hex: 0x3BC9B0)
            )
        case .dark:
            return ThemePalette(
                background: Color(hex: 0x12141A),
                secondaryBackground: Color(hex: 0x1A1E27),
                ink: Color(hex: 0xE8EAF2),
                accent: Color(hex: 0x9B7BFF),
                playerOne: Color(hex: 0x8D6AE6),
                playerTwo: Color(hex: 0x5E8BE8)
            )
        }
    }

    // Backward compatibility: existing callsites stay functional.
    private static let premium = palette(for: .premium)
    static let paperBackground = premium.background
    static let paperSecondary = premium.secondaryBackground
    static let graphiteInk = premium.ink
    static let royalPurple = premium.accent
    static let playerOneUndertone = premium.playerOne
    static let playerTwoUndertone = premium.playerTwo
    static let juniorCoral = palette(for: .junior).playerOne
    static let juniorMint = palette(for: .junior).playerTwo
    static let juniorSky = palette(for: .junior).accent
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
