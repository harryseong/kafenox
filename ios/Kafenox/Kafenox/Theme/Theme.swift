import SwiftUI
import UIKit

/// The three palettes from the Claude Design prototype's `palette(t)` function.
enum Theme: String, CaseIterable {
    case warm, dark, minimal

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    func next() -> Theme {
        let all = Theme.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

struct Palette {
    let bg: Color
    let surface: Color
    let surface2: Color
    let fg: Color
    let muted: Color
    let line: Color
    let accent: Color
    let accent2: Color
    let onAccent: Color

    static func `for`(_ theme: Theme) -> Palette {
        switch theme {
        case .warm:
            return Palette(
                bg: Color(hex: 0xefe7da), surface: Color(hex: 0xfaf6ef), surface2: Color(hex: 0xe7dccb),
                fg: Color(hex: 0x2b211a), muted: Color(hex: 0x8a7c6c),
                line: Color(hex: 0x2b211a, opacity: 0.10),
                accent: Color(hex: 0xb5613e), accent2: Color(hex: 0x4f6b4a), onAccent: .white
            )
        case .dark:
            return Palette(
                bg: Color(hex: 0x131110), surface: Color(hex: 0x1c1917), surface2: Color(hex: 0x272320),
                fg: Color(hex: 0xf3ece1), muted: Color(hex: 0x9b8f80),
                line: Color.white.opacity(0.10),
                accent: Color(hex: 0xd2a24a), accent2: Color(hex: 0x7fa37a), onAccent: Color(hex: 0x1a1410)
            )
        case .minimal:
            return Palette(
                bg: Color(hex: 0xf7f6f4), surface: .white, surface2: Color(hex: 0xf0eeea),
                fg: Color(hex: 0x1a1715), muted: Color(hex: 0x8d877f),
                line: Color.black.opacity(0.09),
                accent: Color(hex: 0xb1442f), accent2: Color(hex: 0x3f7d6e), onAccent: .white
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

/// 'wght' axis tag (FourCharCode for "wght") used to instantiate the Hanken
/// Grotesk variable font at an exact weight via CoreText's variation
/// attribute -- Google's font repo only ships the variable TTF for this
/// family now, no static per-weight files exist upstream.
private let wghtAxisTag: Int = 0x77676874

extension Font {
    static func hanken(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Hanken Grotesk",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxisTag: weight],
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    static func dmMono(_ size: CGFloat, medium: Bool = false) -> Font {
        .custom(medium ? "DMMono-Medium" : "DMMono-Regular", size: size)
    }
}
