import SwiftUI

enum AppTheme {
    static let paperBackground = Color(hex: 0xF6F2E8)
    static let paperSecondary = Color(hex: 0xEFE9DC)
    static let graphiteInk = Color(hex: 0x1C1C1C)
    static let royalPurple = Color(hex: 0x7C3AED)
    static let playerOneUndertone = Color(hex: 0x6D47C8)
    static let playerTwoUndertone = Color(hex: 0x4363C7)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
