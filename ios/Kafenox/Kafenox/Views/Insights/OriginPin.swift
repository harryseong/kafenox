import SwiftUI

/// Deliberately simple -- no nested scroll/gesture views -- since custom
/// Annotation content inside MapKit's Map can have tap-through/clipping
/// quirks if it gets complex.
struct OriginPin: View {
    let count: Int
    let maxCount: Int
    let palette: Palette

    private var diameter: CGFloat {
        let ratio = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
        return 14 + ratio * 22
    }

    var body: some View {
        Circle()
            .fill(palette.fg)
            .frame(width: diameter, height: diameter)
            .overlay(Circle().stroke(palette.bg, lineWidth: 3))
            .shadow(color: palette.shadow, radius: 4)
    }
}
