import SwiftUI

enum WayfolioPalette {
    static let midnight = Color(hex: 0x07101E)
    static let navy = Color(hex: 0x0A1729)
    static let navyRaised = Color(hex: 0x10213A)
    static let parchment = Color(hex: 0xE8D8B4)
    static let parchmentDeep = Color(hex: 0xCDB889)
    // Content now lives on projected glass instead of opaque parchment.
    static let ink = Color(hex: 0xF6FBFD)
    static let brass = Color(hex: 0xC99B4C)
    static let brassBright = Color(hex: 0xF0C66D)
    static let cyan = Color(hex: 0x6BE7FF)
    static let violet = Color(hex: 0xA988FF)
    static let magenta = Color(hex: 0xFF7BDE)
    static let emerald = Color(hex: 0x73D79F)
    static let danger = Color(hex: 0xFF6E7B)
    static let mutedText = Color(hex: 0xB7C0C7)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
