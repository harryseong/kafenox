import SwiftUI

/// The "Flavors" tab of the Insights screen: a frequency-sized flavor cloud,
/// per-family bars, and the most common individual notes across the
/// collection. Counts come from `InsightsViewModel`.
struct FlavorsInsightView: View {
    let viewModel: InsightsViewModel
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cloud
            familyBars
            commonNotes
        }
    }

    // MARK: Cloud

    private var cloud: some View {
        FlowLayout(spacing: 8) {
            ForEach(viewModel.rankedNotes) { stat in
                cloudChip(stat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.line, lineWidth: 1))
        .padding(.top, 18)
    }

    private func cloudChip(_ stat: FlavorNoteStat) -> some View {
        let t = CGFloat(stat.count) / CGFloat(max(viewModel.maxNoteCount, 1))
        let color = stat.family.color
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(stat.note)
                .font(.hanken(12.5 + t * 5, weight: 700))
                .foregroundStyle(palette.fg)
        }
        .padding(.vertical, 6 + t * 3)
        .padding(.horizontal, 11 + t * 5)
        .background(color.opacity(0.14 + t * 0.28), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.42), lineWidth: 1))
    }

    // MARK: By family

    private var familyBars: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BY FLAVOR FAMILY")
                .font(.hanken(13, weight: 700))
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
                        .font(.hanken(14.5, weight: 700))
                        .foregroundStyle(palette.fg)
                }
                Spacer()
                Text("\(stat.total) \(stat.total == 1 ? "note" : "notes")")
                    .font(.dmMono(12))
                    .foregroundStyle(palette.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface2)
                    Capsule().fill(stat.family.color)
                        .frame(width: geo.size.width * CGFloat(stat.total) / CGFloat(viewModel.maxFamilyTotal))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: Most common notes

    private var commonNotes: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MOST COMMON NOTES")
                .font(.hanken(13, weight: 700))
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
                    .font(.hanken(15, weight: 700))
                    .foregroundStyle(palette.fg)
                Text(stat.family.name.uppercased())
                    .font(.dmMono(10))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            Text("\(stat.count) \(stat.count == 1 ? "coffee" : "coffees")")
                .font(.dmMono(12))
                .foregroundStyle(palette.muted)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
    }
}
