import SwiftUI

/// The two palettes from the Claude Design v3 prototype's theme tokens.
public enum Theme: String, CaseIterable, Sendable {
    case light, dark
}

/// What the user picks in Settings; `system` resolves to light/dark from
/// the device appearance at render time.
public enum ThemeChoice: String, CaseIterable, Sendable {
    case light, dark, system

    public var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

public struct Palette: Sendable {
    public let bg: Color
    public let surface: Color
    public let surface2: Color
    public let fg: Color
    public let muted: Color
    public let line: Color
    public let shadow: Color

    /// Theme-independent semantic colors (same in light and dark).
    public static let error = Color(hex: 0xc73a2e)
    public static let success = Color(hex: 0x3f9d6e)

    public static func `for`(_ theme: Theme) -> Palette {
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
    public init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Mirrors the design's `style-active: transform:scale(...)` press feedback
/// on circular icon buttons, chips, and the Ask AI FAB.
public struct PressScaleButtonStyle: ButtonStyle {
    public var scale: CGFloat

    public init(scale: CGFloat = 0.92) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// v3 dropped the custom Hanken Grotesk / DM Mono pairing for the platform
/// system stack -- everything is the system font differentiated by size,
/// weight, and tracking. `app` mirrors the design's px sizes 1:1.
///
/// `.system(size:)` scales with Dynamic Type via `relativeTo`, so text still
/// responds to the user's preferred content size.
extension Font {
    public static func app(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
