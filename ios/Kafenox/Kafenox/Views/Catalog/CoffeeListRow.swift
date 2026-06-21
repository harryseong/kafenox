import SwiftUI

struct CoffeeListRow: View {
    let coffee: Coffee
    let palette: Palette

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                coffee.swatchColor
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.black.opacity(0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Text(coffee.initials)
                    .font(.dmMono(19))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text((coffee.roaster ?? "").uppercased())
                    .font(.dmMono(9.5))
                    .foregroundStyle(palette.muted)
                Text(coffee.coffeeName ?? "Untitled")
                    .font(.hanken(15.5, weight: 700))
                    .foregroundStyle(palette.fg)
                    .lineLimit(1)
                Text("\(coffee.originLabel) · \(coffee.roastLevel?.capitalized ?? "—")")
                    .font(.hanken(12))
                    .foregroundStyle(palette.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(ratingText)
                    .font(.dmMono(19, medium: true))
                    .foregroundStyle(palette.accent)
                Text("/ 10")
                    .font(.hanken(9, weight: 600))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(11)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.line, lineWidth: 1))
    }

    private var ratingText: String {
        guard let rating = coffee.rating else { return "—" }
        return "\(rating)"
    }
}
