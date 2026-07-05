import SwiftUI

/// The two palettes from the Claude Design v3 prototype's theme tokens.
enum Theme: String, CaseIterable {
    case light, dark

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    func toggled() -> Theme {
        self == .light ? .dark : .light
    }
}

struct Palette {
    let bg: Color
    let surface: Color
    let surface2: Color
    let fg: Color
    let muted: Color
    let line: Color
    let shadow: Color

    /// Theme-independent semantic colors (same in light and dark).
    static let error = Color(hex: 0xc73a2e)
    static let success = Color(hex: 0x3f9d6e)

    static func `for`(_ theme: Theme) -> Palette {
        switch theme {
        case .light:
            return Palette(
                bg: Color(hex: 0xfafafa), surface: .white, surface2: Color(hex: 0xefefee),
                fg: Color(hex: 0x131312), muted: Color(hex: 0x98938c),
                line: Color(hex: 0x131312, opacity: 0.09),
                shadow: Color.black.opacity(0.22)
            )
        case .dark:
            return Palette(
                bg: Color(hex: 0x0d0d0d), surface: Color(hex: 0x171717), surface2: Color(hex: 0x232322),
                fg: Color(hex: 0xf2f2f0), muted: Color(hex: 0x8a8a88),
                line: Color(hex: 0xf2f2f0, opacity: 0.11),
                shadow: Color.black.opacity(0.6)
            )
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// v3 dropped the custom Hanken Grotesk / DM Mono pairing for the platform
/// system stack -- everything is the system font differentiated by size,
/// weight, and tracking. `app` mirrors the design's px sizes 1:1.
extension Font {
    static func app(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
