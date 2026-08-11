import KafenoxDesignSystem
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
        // Always white, even in light mode: the pins sit on the map's own
        // (dark, saturated) imagery, not on the app background, and white
        // contrasts best there.
        Circle()
            .stroke(.white, lineWidth: 1)
            .frame(width: ringDiameter, height: ringDiameter)
            .overlay(
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            )
            .shadow(color: .black.opacity(0.35), radius: 2)
    }
}
