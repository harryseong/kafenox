import SwiftUI

/// A fixed-size center dot inside a transparent ring whose diameter scales
/// with the coffee count, so busy origins don't blot out the map beneath.
/// Deliberately simple -- no nested scroll/gesture views -- since custom
/// Annotation content inside MapKit's Map can have tap-through/clipping
/// quirks if it gets complex.
struct OriginPin: View {
    let count: Int
    let maxCount: Int
    let palette: Palette

    private var ringDiameter: CGFloat {
        let ratio = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
        return 16 + ratio * 38
    }

    var body: some View {
        Circle()
            .stroke(palette.fg, lineWidth: 1)
            .frame(width: ringDiameter, height: ringDiameter)
            .overlay(
                Circle()
                    .fill(palette.fg)
                    .frame(width: 6, height: 6)
            )
    }
}
