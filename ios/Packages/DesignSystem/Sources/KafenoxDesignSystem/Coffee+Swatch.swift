import KafenoxCore
import SwiftUI

/// Visual identity derived client-side, since the backend's Coffee model has
/// no color field (that was a prototype seed-data flourish, not real product
/// data) -- deterministic so the same coffee always renders the same swatch
/// across launches.
extension Coffee {
    private static let swatches: [UInt32] = [
        0xb5613e, 0x4f6b4a, 0x34465e, 0x6b3f5b, 0xb58a3e, 0x9c4a2e,
        0x3e8a82, 0x8a3e54, 0x2e6b7a, 0x7d8a5e, 0x55606b, 0xa85a3a,
        0x5e7a4a, 0x7a4a2e,
    ]

    public var swatchColor: Color {
        let hash = abs(photoId.hashValue)
        return Color(hex: Self.swatches[hash % Self.swatches.count])
    }
}

extension FlavorFamily {
    public var color: Color { Color(hex: hex) }
}
