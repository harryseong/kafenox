import SwiftUI

/// The "Timeline" tab of the Insights screen: a flat list of logged coffees
/// grouped by month, newest first.
struct TimelineInsightView: View {
    let groups: [TimelineGroup]
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(groups) { group in
                monthGroup(group)
            }
        }
        .padding(.top, 22)
    }

    private func monthGroup(_ group: TimelineGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(group.label)
                    .font(.app(16, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(palette.fg)
                Text("\(group.coffees.count) \(group.coffees.count == 1 ? "coffee" : "coffees")")
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            .padding(.bottom, 4)

            ForEach(group.coffees) { coffee in
                coffeeRow(coffee)
            }
        }
    }

    private func coffeeRow(_ coffee: Coffee) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(coffee.swatchColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(coffee.coffeeName ?? "Unknown coffee")
                    .font(.app(15, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(palette.fg)
                Text(subtitle(for: coffee))
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            if let rating = coffee.rating {
                Text("\(rating)/10")
                    .font(.app(13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 2)
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .bottom)
    }

    private func subtitle(for coffee: Coffee) -> String {
        [coffee.roaster, coffee.originLabel.isEmpty ? nil : coffee.originLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
