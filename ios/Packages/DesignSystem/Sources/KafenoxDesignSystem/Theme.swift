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

    // A ButtonStyle can't read @Environment itself, so the label goes through
    // a nested View that can.
    public func makeBody(configuration: Configuration) -> some View {
        ScaleBody(configuration: configuration, scale: scale)
    }

    private struct ScaleBody: View {
        let configuration: Configuration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : scale)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// v3 dropped the custom Hanken Grotesk / DM Mono pairing for the platform
/// system stack -- everything is the system font differentiated by size,
/// weight, and tracking. `appFont` mirrors the design's px sizes 1:1.
///
/// It is a view modifier rather than a `Font` factory on purpose. The design's
/// sizes are absolute, and `Font.system(size:)` is a *fixed* size that ignores
/// Dynamic Type entirely. Computing a scaled size eagerly (via `UIFontMetrics`)
/// does scale the text, but resolves once at body-evaluation time, so changing
/// the system text size while the app runs has no effect until relaunch.
/// `@ScaledMetric` is a `DynamicProperty`, so it re-reads the environment and
/// the text resizes live.
///
/// Each size scales against the system text style closest to it, because
/// Apple's curves differ by role: a caption grows far more than a large title.
/// Scaling everything against `.body` made mastheads balloon off the screen at
/// accessibility sizes while small print stayed cramped.
private struct AppFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        // `relativeTo` is fixed at init, which is fine -- it only needs to
        // depend on the design size, not on anything that changes later.
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.textStyle(for: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<13: .caption
        case ..<14: .footnote
        case ..<16: .subheadline
        case ..<17: .callout
        case ..<20: .body
        case ..<23: .title3
        case ..<29: .title2
        case ..<35: .title
        default: .largeTitle
        }
    }
}

extension View {
    /// Applies the app's type ramp at a design size, scaled for Dynamic Type.
    public func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(AppFont(size: size, weight: weight))
    }
}
