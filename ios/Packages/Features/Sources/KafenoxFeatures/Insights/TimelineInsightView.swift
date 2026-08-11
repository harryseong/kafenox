import KafenoxCore
import KafenoxDesignSystem
import SwiftUI

/// The "Timeline" tab of the Insights screen: a vertical rail of months (by
/// roast date, newest first) with a card per coffee, best-rated first.
struct TimelineInsightView: View {
    let groups: [TimelineGroup]
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                monthGroup(group, isLast: group.id == groups.last?.id)
            }
        }
        .padding(.top, 24)
    }

    private func monthGroup(_ group: TimelineGroup, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 15) {
            // Rail: month node + connector down to the next group.
            VStack(spacing: 7) {
                Circle()
                    .fill(palette.bg)
                    .stroke(palette.fg, lineWidth: 3)
                    .frame(width: 13, height: 13)
                    .padding(.top, 5)
                if !isLast {
                    Capsule()
                        .fill(palette.line)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(group.label)
                        .font(.app(16.5, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(palette.fg)
                    Text(group.agoLabel)
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                    Spacer(minLength: 10)
                    Text("\(group.coffees.count) \(group.coffees.count == 1 ? "coffee" : "coffees")")
                        .font(.app(11.5, weight: .semibold))
                        .foregroundStyle(palette.muted)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(palette.surface2, in: Capsule())
                }

                VStack(spacing: 9) {
                    ForEach(group.coffees) { coffee in
                        coffeeCard(coffee)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.bottom, 28)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func coffeeCard(_ coffee: Coffee) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(coffee.swatchColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(coffee.initials)
                            .font(.app(12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(coffee.coffeeName ?? "Unknown coffee")
                        .font(.app(15, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(palette.fg)
                        .lineLimit(1)
                    Text(subtitle(for: coffee))
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(coffee.rating.map { "\($0)" } ?? "—")
                    .font(.app(13.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.fg)
            }

            FlowRowLine(spacing: 6) {
                if let roast = coffee.roastLevel {
                    Text("\(roast) roast")
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(palette.fg)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .background(palette.surface2, in: Capsule())
                }
                ForEach(coffee.flavorNotes.prefix(3), id: \.self) { note in
                    Text(note)
                        .font(.app(11, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 9)
                        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
                }
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.line, lineWidth: 1))
    }

    private func subtitle(for coffee: Coffee) -> String {
        [coffee.roaster, coffee.originLabel.isEmpty ? nil : coffee.originLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// A single wrapping chip row (the design caps chips at roast + 3 notes, so
/// one or two lines at most).
private struct FlowRowLine<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
