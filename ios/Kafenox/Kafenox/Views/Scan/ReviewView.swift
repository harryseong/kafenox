import SwiftUI

struct ReviewView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Bindable var viewModel: ScanViewModel
    var onAdd: (Coffee) -> Void
    var onRetake: () -> Void

    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review details")
                    .font(.hanken(27, weight: 800))
                    .foregroundStyle(palette.fg)
                Text("Extracted from the label — edit anything before saving.")
                    .font(.hanken(13.5))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 6)

                summaryRow(palette: palette)

                VStack(spacing: 13) {
                    field("Roaster", text: $viewModel.draftRoaster, palette: palette)
                    field("Coffee", text: $viewModel.draftName, palette: palette)
                    HStack(spacing: 11) {
                        field("Origin", text: $viewModel.draftCountry, palette: palette)
                        field("Region", text: $viewModel.draftRegion, palette: palette)
                    }
                    HStack(spacing: 11) {
                        field("Process", text: $viewModel.draftProcess, palette: palette)
                        field("Variety", text: $viewModel.draftVariety, palette: palette)
                    }
                    field("Producer", text: $viewModel.draftProducer, palette: palette)
                    if let flavors = viewModel.original?.flavorNotes, !flavors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FLAVOR NOTES")
                                .font(.dmMono(10))
                                .foregroundStyle(palette.muted)
                            FlowLayout(spacing: 7) {
                                ForEach(flavors, id: \.self) { note in
                                    Text(note)
                                        .font(.hanken(13, weight: 600))
                                        .foregroundStyle(palette.fg)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(palette.surface, in: Capsule())
                                        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(.top, 20)

                if let saveError {
                    Text(saveError)
                        .font(.hanken(13, weight: 600))
                        .foregroundStyle(.red)
                        .padding(.top, 12)
                }

                HStack(spacing: 11) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.hanken(15, weight: 700))
                            .foregroundStyle(palette.fg)
                            .padding(.horizontal, 22)
                            .frame(height: 52)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.line, lineWidth: 1))
                    }
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(palette.onAccent).frame(maxWidth: .infinity).frame(height: 52)
                                .background(palette.accent, in: RoundedRectangle(cornerRadius: 15))
                        } else {
                            Text("Add to collection")
                                .font(.hanken(15, weight: 700))
                                .foregroundStyle(palette.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(palette.accent, in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
                    .disabled(isSaving)
                }
                .padding(.top, 26)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.bg)
    }

    private func summaryRow(palette: Palette) -> some View {
        HStack(spacing: 13) {
            ZStack {
                (viewModel.original?.swatchColor ?? palette.accent)
                Text(viewModel.original?.initials ?? "?")
                    .font(.dmMono(17))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(palette.accent2).frame(width: 7, height: 7)
                    Text("Extracted · high confidence")
                        .font(.hanken(10.5, weight: 700))
                        .foregroundStyle(palette.accent)
                }
                Text(viewModel.draftName.isEmpty ? "Untitled" : viewModel.draftName)
                    .font(.hanken(16, weight: 700))
                    .foregroundStyle(palette.fg)
            }
        }
        .padding(13)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
        .padding(.top, 20)
    }

    private func field(_ label: String, text: Binding<String>, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.dmMono(10))
                .foregroundStyle(palette.muted)
            TextField("", text: text)
                .font(.hanken(15, weight: 600))
                .foregroundStyle(palette.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            let coffee = try await viewModel.addToCollection()
            onAdd(coffee)
        } catch {
            saveError = "Couldn't save — try again."
        }
    }
}
