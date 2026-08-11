import KafenoxCore
import KafenoxDesignSystem
import SwiftUI

/// The "Flavors" tab of the Insights screen: per-family bars plus the most
/// common individual notes. (The v2 flavor cloud was dropped in the v3
/// design.) Counts come from `InsightsViewModel`.
struct FlavorsInsightView: View {
    let viewModel: InsightsViewModel
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            familyBars
            commonNotes
        }
    }

    // MARK: By family

    private var familyBars: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("By flavor family")
                .appFont(12, weight: .semibold)
                .foregroundStyle(palette.muted)
                .padding(.top, 22)

            VStack(spacing: 11) {
                ForEach(viewModel.familyStats) { stat in
                    familyRow(stat)
                }
            }
            .padding(.top, 14)
        }
    }

    private func familyRow(_ stat: FlavorFamilyStat) -> some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(stat.family.color).frame(width: 9, height: 9)
                    Text(stat.family.name)
                        .appFont(14.5, weight: .semibold)
                        .foregroundStyle(palette.fg)
                }
                Spacer()
                Text("\(stat.total) \(stat.total == 1 ? "note" : "notes")")
                    .appFont(12, weight: .medium)
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface2)
                    Capsule().fill(stat.family.color)
                        .frame(width: geo.size.width * CGFloat(stat.total) / CGFloat(viewModel.maxFamilyTotal))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: Most common notes

    private var commonNotes: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Most common notes")
                .appFont(12, weight: .semibold)
                .foregroundStyle(palette.muted)
                .padding(.top, 24)

            VStack(spacing: 9) {
                ForEach(viewModel.topNotes) { stat in
                    noteRow(stat)
                }
            }
            .padding(.top, 14)
        }
    }

    private func noteRow(_ stat: FlavorNoteStat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9)
                .fill(stat.family.color)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(stat.note)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(palette.fg)
                Text(stat.family.name)
                    .appFont(11, weight: .medium)
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            Text("\(stat.count) \(stat.count == 1 ? "coffee" : "coffees")")
                .appFont(12, weight: .medium)
                .monospacedDigit()
                .foregroundStyle(palette.muted)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
    }
}
