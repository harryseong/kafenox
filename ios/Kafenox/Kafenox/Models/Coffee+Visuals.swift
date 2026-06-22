import SwiftUI

/// Visual identity derived client-side, since the backend's Coffee model has
/// no color/initials fields (those were prototype seed-data flourishes, not
/// real product data) -- deterministic so the same coffee always renders the
/// same swatch across launches.
extension Coffee {
    private static let swatches: [UInt32] = [
        0xb5613e, 0x4f6b4a, 0x34465e, 0x6b3f5b, 0xb58a3e, 0x9c4a2e,
        0x3e8a82, 0x8a3e54, 0x2e6b7a, 0x7d8a5e, 0x55606b, 0xa85a3a,
        0x5e7a4a, 0x7a4a2e,
    ]

    var swatchColor: Color {
        let hash = abs(photoId.hashValue)
        return Color(hex: Self.swatches[hash % Self.swatches.count])
    }

    var initials: String {
        let source = roaster ?? coffeeName ?? "?"
        let words = source.split(separator: " ").filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// Maps the backend's 6-value roastLevel enum down to the prototype's
    /// 3-bucket filter chips (All/Light/Medium/Dark).
    var roastGroup: String {
        switch roastLevel {
        case "light", "medium-light": return "Light"
        case "medium": return "Medium"
        case "medium-dark", "dark": return "Dark"
        default: return "Medium"
        }
    }

    /// 1-5 scale used for the Detail screen's roast-level progress bar.
    var roastLevelOrdinal: Int {
        switch roastLevel {
        case "light": return 1
        case "medium-light": return 2
        case "medium": return 3
        case "medium-dark": return 4
        case "dark": return 5
        default: return 3
        }
    }

    var originLabel: String {
        [originRegion, originCountry].compactMap { $0 }.joined(separator: ", ")
    }
}
