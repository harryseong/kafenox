import SwiftUI

struct CoffeeGridCard: View {
    let coffee: Coffee
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                coffee.swatchColor
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.black.opacity(0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                Text(coffee.initials)
                    .font(.dmMono(30))
                    .foregroundStyle(.white.opacity(0.32))
                    .padding(.top, 9)
                    .padding(.leading, 11)

                VStack {
                    HStack {
                        Spacer()
                        Text(ratingText)
                            .font(.dmMono(12, medium: true))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                    HStack {
                        Text(coffee.originCountry?.uppercased() ?? "")
                            .font(.dmMono(10))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                }
                .padding(9)
            }
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text((coffee.roaster ?? "").uppercased())
                    .font(.dmMono(9.5))
                    .foregroundStyle(palette.muted)
                Text(coffee.coffeeName ?? "Untitled")
                    .font(.hanken(15, weight: 700))
                    .foregroundStyle(palette.fg)
                    .lineLimit(2)
            }

            FlowChips(items: coffee.flavorNotes, palette: palette)
        }
        .padding(11)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(palette.line, lineWidth: 1))
    }

    private var ratingText: String {
        guard let rating = coffee.rating else { return "—" }
        return "\(rating)"
    }
}

/// Wrapping chip row for flavor notes -- count varies per coffee.
struct FlowChips: View {
    let items: [String]
    let palette: Palette

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.hanken(10.5, weight: 600))
                    .foregroundStyle(palette.fg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.surface2, in: Capsule())
            }
        }
    }
}
