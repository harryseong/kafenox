import SwiftUI

struct DetailView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let viewModel: DetailViewModel

    @State private var isEditPresented = false
    @State private var isDeleteConfirmPresented = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        let palette = themeStore.palette
        let coffee = viewModel.coffee

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navRow(palette: palette)
                header(coffee: coffee, palette: palette)
                ratingCard(coffee: coffee, palette: palette)
                flavorSection(coffee: coffee, palette: palette)
                detailRows(coffee: coffee, palette: palette)
                tastingNote(coffee: coffee, palette: palette)
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(palette.bg)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isEditPresented) {
            EditCoffeeView(coffee: viewModel.coffee) { updated in
                viewModel.applyUpdate(updated)
            }
            .environment(themeStore)
        }
        .overlay {
            if isDeleteConfirmPresented {
                DeleteConfirmationView(
                    palette: palette,
                    isDeleting: isDeleting,
                    errorMessage: deleteError,
                    onCancel: { isDeleteConfirmPresented = false },
                    onDelete: { Task { await performDelete() } }
                )
            }
        }
    }

    private func navRow(palette: Palette) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(palette.line, lineWidth: 1))
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.fg)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isEditPresented = true
                } label: {
                    Circle()
                        .fill(palette.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(palette.line, lineWidth: 1))
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.fg)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    deleteError = nil
                    isDeleteConfirmPresented = true
                } label: {
                    Circle()
                        .fill(palette.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(palette.line, lineWidth: 1))
                        .overlay(
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.fg)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @MainActor
    private func performDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await viewModel.delete()
            isDeleting = false
            dismiss()
        } catch {
            isDeleting = false
            deleteError = "Couldn't delete — try again."
        }
    }

    private func header(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(coffee.swatchColor)
                .frame(width: 44, height: 44)
            Text(coffee.coffeeName ?? "Untitled")
                .font(.app(28, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(palette.fg)
                .padding(.top, 14)
            Text(subtitle(for: coffee))
                .font(.app(14, weight: .medium))
                .foregroundStyle(palette.muted)
                .padding(.top, 6)
        }
        .padding(.top, 18)
    }

    private func subtitle(for coffee: Coffee) -> String {
        [coffee.roaster, coffee.originLabel.isEmpty ? nil : coffee.originLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func ratingCard(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Your rating")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(palette.muted)
                Spacer()
                Text(coffee.rating.map { "\($0)" } ?? "—")
                    .font(.app(28, weight: .bold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(palette.fg)
                Text(" / 10")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(palette.muted)
            }
            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { n in
                    let on = n <= (coffee.rating ?? 0)
                    Button {
                        viewModel.setRating(n)
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(on ? palette.fg : palette.surface2)
                            .frame(height: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(17)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.line, lineWidth: 1))
        .padding(.top, 22)
    }

    private func flavorSection(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flavor notes")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
            FlowLayout(spacing: 7) {
                ForEach(coffee.flavorNotes, id: \.self) { note in
                    Text(note)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(palette.fg)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(palette.surface2, in: Capsule())
                }
            }
        }
        .padding(.top, 24)
    }

    private func detailRows(coffee: Coffee, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
                .padding(.bottom, 4)

            detailRow(label: "Roast level", palette: palette) {
                HStack(spacing: 10) {
                    Text(coffee.roastLevel?.capitalized ?? "—")
                        .font(.app(14, weight: .semibold))
                        .foregroundStyle(palette.fg)
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.surface2)
                        Capsule().fill(palette.fg)
                            .frame(width: 88 * CGFloat(coffee.roastLevelOrdinal) / 5)
                    }
                    .frame(width: 88, height: 4)
                }
            }
            detailRow(label: "Roast type", value: coffee.roastType?.capitalized, palette: palette)
            detailRow(label: "Process", value: coffee.process?.capitalized, palette: palette)
            detailRow(label: "Variety", value: coffee.variety, palette: palette)
            detailRow(label: "Producer", value: coffee.producer, palette: palette)
            detailRow(label: "Roast date", value: coffee.roastDate.map(formatRoastDate), palette: palette)
            detailRow(label: "Altitude", value: coffee.altitude, palette: palette)
        }
        .padding(.top, 24)
    }

    private func detailRow(label: String, value: String?, palette: Palette) -> some View {
        detailRow(label: label, palette: palette) {
            Text(value ?? "—")
                .font(.app(14, weight: .semibold))
                .foregroundStyle(palette.fg)
        }
    }

    private func detailRow(label: String, palette: Palette, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label)
                .font(.app(13.5))
                .foregroundStyle(palette.muted)
            Spacer()
            trailing()
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 2)
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .bottom)
    }

    private func tastingNote(coffee: Coffee, palette: Palette) -> some View {
        Text(notesText(coffee))
            .font(.app(15))
            .foregroundStyle(palette.fg)
            .lineSpacing(5)
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
