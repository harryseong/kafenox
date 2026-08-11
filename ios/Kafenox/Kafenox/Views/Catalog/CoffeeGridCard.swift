import SwiftUI

struct CoffeeGridCard: View {
    let coffee: Coffee
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(coffee.swatchColor)
                    .frame(width: 10, height: 10)
                Spacer()
                if let badge = CoffeeStatusBadge(coffee: coffee) {
                    StatusBadgeView(kind: badge, palette: palette)
                } else {
                    Text(ratingText)
                        .font(.app(12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.muted)
                }
            }

            Text(coffee.coffeeName ?? "Untitled")
                .font(.app(16.5, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(palette.fg)
                .lineLimit(2)
                .frame(minHeight: 40, alignment: .topLeading)
                .padding(.top, 2)

            Text(coffee.roaster ?? subtitleFallback)
                .font(.app(12, weight: .medium))
                .foregroundStyle(palette.muted)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(coffee.flavorNotes.joined(separator: ", "))
                .font(.app(11.5))
                .foregroundStyle(palette.muted)
                .lineLimit(2)
                .lineSpacing(2)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .top)
        }
        .padding(.top, 15)
        .padding(.horizontal, 15)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.line, lineWidth: 1))
    }

    private var ratingText: String {
        guard let rating = coffee.rating else { return "—" }
        return "\(rating)/10"
    }

    /// A queued scan has no roaster yet; say why the line is blank.
    private var subtitleFallback: String {
        if coffee.isProcessing { return "Reading the label…" }
        if coffee.isFailedExtraction { return "Couldn't read that label" }
        return " "
    }
}
