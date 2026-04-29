import SwiftUI
import UIKit

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
    static let paperBackground = dynamicColor(light: Color(hex: 0xF6F2E8), dark: Color(hex: 0x0C0D10))
    static let paperSecondary = dynamicColor(light: Color(hex: 0xEFE9DC), dark: Color(hex: 0x17191E))
    static let graphiteInk = dynamicColor(light: premium.ink, dark: Color(hex: 0xF2EEE6))
    static let royalPurple = dynamicColor(light: premium.accent, dark: Color(hex: 0x6E4CE6))
    static let warmOrange = dynamicColor(light: Color(hex: 0xF4A261), dark: Color(hex: 0xF4A261))
    // Per-player line palette for readable board history.
    static let playerOneUndertone = dynamicColor(light: Color(hex: 0xD98C5F), dark: Color(hex: 0xF4A261))
    static let playerTwoUndertone = dynamicColor(light: Color(hex: 0x5D8F8B), dark: Color(hex: 0x64C2B8))
    static let juniorCoral = palette(for: .junior).playerOne
    static let juniorMint = palette(for: .junior).playerTwo
    static let juniorSky = palette(for: .junior).accent

    // Board-specific dark styling: graphite surface with subtle center lift.
    static let boardBase = dynamicColor(light: Color(hex: 0xF6F2E8), dark: Color(hex: 0x17191E))
    static let boardHighlight = dynamicColor(light: Color(hex: 0xEFE9DC), dark: Color(hex: 0x20232A))

    // Gameplay state colors (dark mode tuned, light untouched).
    static let pendingValid = dynamicColor(light: Color(hex: 0x7C3AED), dark: Color(hex: 0x66D1FF))
    static let invalidPreview = dynamicColor(light: Color(hex: 0xC84E4E), dark: Color(hex: 0xFF6B6B))
    static let newNodePulse = dynamicColor(light: Color(hex: 0x7C3AED), dark: Color(hex: 0xFFD166))

    private static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(
            uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
