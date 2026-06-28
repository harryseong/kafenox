import SwiftUI

struct DetailView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let viewModel: DetailViewModel

    var body: some View {
        let palette = themeStore.palette
        let coffee = viewModel.coffee

        ScrollView {
            VStack(spacing: 0) {
                hero(coffee: coffee, palette: palette)

                VStack(alignment: .leading, spacing: 0) {
                    ratingCard(coffee: coffee, palette: palette)
                    flavorSection(coffee: coffee, palette: palette)
                    specGrid(coffee: coffee, palette: palette)
                    notesCard(coffee: coffee, palette: palette)
                }
                .padding(22)
            }
        }
        .background(palette.bg)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    private func hero(coffee: Coffee, palette: Palette) -> some View {
        ZStack(alignment: .bottomLeading) {
            coffee.swatchColor
            LinearGradient(
                colors: [Color.white.opacity(0.16), Color.black.opacity(0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Text(coffee.initials)
                .font(.dmMono(54))
                .foregroundStyle(.white.opacity(0.22))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
                .padding(.top, 62)
                .frame(maxHeight: .infinity, alignment: .top)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.32), in: Circle())
            }
            .padding(.leading, 18)
            .padding(.top, 62)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 7) {
                Text((coffee.roaster ?? "").uppercased())
                    .font(.dmMono(11))
                    .foregroundStyle(.white.opacity(0.85))
                Text(coffee.coffeeName ?? "Untitled")
                    .font(.hanken(32, weight: 800))
                    .foregroundStyle(.white)
                HStack(spacing: 7) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                    Text(coffee.originLabel)
                        .font(.hanken(14, weight: 600))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(22)
        }
        .frame(height: 300)
    }

    private func ratingCard(coffee: Coffee, palette: Palette) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("YOUR RATING")
                    .font(.hanken(13, weight: 700))
                    .foregroundStyle(palette.muted)
                Spacer()
                Text(coffee.rating.map { "\($0)" } ?? "—")
                    .font(.dmMono(30, medium: true))
                    .foregroundStyle(palette.accent)
                Text(" / 10")
                    .font(.hanken(13, weight: 600))
                    .foregroundStyle(palette.muted)
            }
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { n in
                    let on = n <= (coffee.rating ?? 0)
                    Button {
                        viewModel.setRating(n)
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(on ? palette.accent : palette.surface2)
                            .frame(height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(palette.line, lineWidth: 1))
    }

    private func flavorSection(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("FLAVOR NOTES")
                .font(.hanken(13, weight: 700))
                .foregroundStyle(palette.muted)
            FlowLayout(spacing: 8) {
                ForEach(coffee.flavorNotes, id: \.self) { note in
                    Text(note)
                        .font(.hanken(13.5, weight: 600))
                        .foregroundStyle(palette.fg)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(palette.surface, in: Capsule())
                        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
                }
            }
        }
        .padding(.top, 22)
    }

    private func specGrid(coffee: Coffee, palette: Palette) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            specCard(label: "ROAST LEVEL", palette: palette, fullWidth: true) {
                HStack {
                    Text(coffee.roastLevel?.capitalized ?? "—")
                        .font(.hanken(15, weight: 700))
                        .foregroundStyle(palette.fg)
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.surface2)
                            Capsule().fill(palette.accent)
                                .frame(width: geo.size.width * CGFloat(coffee.roastLevelOrdinal) / 5)
                        }
                    }
                    .frame(maxWidth: 150, maxHeight: 7)
                }
            }
            .gridCellColumns(2)

            specCard(label: "PROCESS", palette: palette) {
                Text(coffee.process ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
            specCard(label: "VARIETY", palette: palette) {
                Text(coffee.variety ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
            specCard(label: "ROAST DATE", palette: palette) {
                Text(coffee.roastDate.map(formatRoastDate) ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
            specCard(label: "ORIGIN", palette: palette) {
                Text(coffee.originCountry ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
            specCard(label: "ROAST TYPE", palette: palette) {
                Text(coffee.roastType?.capitalized ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
            specCard(label: "PRODUCER", palette: palette) {
                Text(coffee.producer ?? "—").font(.hanken(15, weight: 700)).foregroundStyle(palette.fg)
            }
        }
        .padding(.top, 24)
    }

    private func specCard(label: String, palette: Palette, fullWidth: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.dmMono(10))
                .foregroundStyle(palette.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
    }

    private func notesCard(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("NOTES")
                .font(.hanken(13, weight: 700))
                .foregroundStyle(palette.muted)
            Text(notesText(coffee))
                .font(.hanken(14.5))
                .foregroundStyle(palette.fg)
                .lineSpacing(5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface2, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 24)
    }

    private func notesText(_ coffee: Coffee) -> String {
        coffee.isVerified ? "Edited and confirmed by you." : "Extracted from the label — edit anything that looks off."
    }

    private func formatRoastDate(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count >= 2, let month = Int(parts[1]) else { return raw }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard month >= 1, month <= 12 else { return raw }
        return "\(months[month - 1]) \(parts[0])"
    }
}
