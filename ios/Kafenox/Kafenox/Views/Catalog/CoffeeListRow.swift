import SwiftUI

struct CoffeeListRow: View {
    let coffee: Coffee
    let palette: Palette

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(coffee.swatchColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(coffee.coffeeName ?? "Untitled")
                    .font(.app(15.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(palette.fg)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(ratingText)
                .font(.app(13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.muted)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.muted)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 2)
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .bottom)
    }

    private var subtitle: String {
        [coffee.roaster, coffee.originLabel.isEmpty ? nil : coffee.originLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var ratingText: String {
        guard let rating = coffee.rating else { return "—" }
        return "\(rating)/10"
    }
}
