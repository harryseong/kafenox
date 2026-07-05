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
                    .font(.app(27, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(palette.fg)
                Text("Extracted from the label — edit anything before saving.")
                    .font(.app(13.5))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 6)

                summaryRow(palette: palette)

                VStack(spacing: 13) {
                    field("Roaster", text: $viewModel.draftRoaster, palette: palette)
                    field("Coffee", text: $viewModel.draftName, palette: palette)
                    HStack(spacing: 10) {
                        field("Origin", text: $viewModel.draftCountry, palette: palette)
                        field("Region", text: $viewModel.draftRegion, palette: palette)
                    }
                    HStack(spacing: 10) {
                        field("Process", text: $viewModel.draftProcess, palette: palette)
                        field("Variety", text: $viewModel.draftVariety, palette: palette)
                    }
                    field("Producer", text: $viewModel.draftProducer, palette: palette)
                    if let flavors = viewModel.original?.flavorNotes, !flavors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Flavor notes")
                                .font(.app(12, weight: .semibold))
                                .foregroundStyle(palette.muted)
                            FlowLayout(spacing: 7) {
                                ForEach(flavors, id: \.self) { note in
                                    Text(note)
                                        .font(.app(13, weight: .medium))
                                        .foregroundStyle(palette.fg)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .background(palette.surface2, in: Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 20)

                if let saveError {
                    Text(saveError)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(Palette.error)
                        .padding(.top, 12)
                }

                HStack(spacing: 10) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.app(14.5, weight: .semibold))
                            .foregroundStyle(palette.fg)
                            .padding(.horizontal, 22)
                            .frame(height: 48)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(palette.bg)
                            } else {
                                Text("Add to collection")
                                    .font(.app(14.5, weight: .semibold))
                                    .foregroundStyle(palette.bg)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(palette.fg, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.original?.swatchColor ?? palette.surface2)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.success).frame(width: 6, height: 6)
                    Text("Extracted · high confidence")
                        .font(.app(11, weight: .medium))
                        .foregroundStyle(palette.muted)
                }
                Text(viewModel.draftName.isEmpty ? "Untitled" : viewModel.draftName)
                    .font(.app(16, weight: .semibold))
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
            Text(label)
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
            TextField("", text: text)
                .font(.app(14.5, weight: .medium))
                .foregroundStyle(palette.fg)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
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
