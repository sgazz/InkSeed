import SwiftUI

enum AppTheme {
    static let paperBackground = Color(hex: 0xF8F7F4)
    static let graphiteInk = Color(hex: 0x1E1E1E)
    static let royalPurple = Color(hex: 0x7C3AED)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
