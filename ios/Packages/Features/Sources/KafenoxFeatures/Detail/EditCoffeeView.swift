import KafenoxCore
import KafenoxDesignSystem
import KafenoxNetworking
import OSLog
import SwiftUI

/// Full-screen edit form matching the v3 design: boxed inputs, roast-level
/// pills, add/remove flavor-note chips. Presented as a sheet from DetailView;
/// only PATCHes fields the user actually changed. Producer/altitude aren't
/// editable here -- the v3 design's Edit screen doesn't surface them either.
struct EditCoffeeView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let coffee: Coffee
    var onSave: (Coffee) -> Void

    @State private var draftRoaster: String
    @State private var draftName: String
    @State private var draftCountry: String
    @State private var draftRegion: String
    @State private var draftProcess: String
    @State private var draftVariety: String
    @State private var draftRoastDate: String
    @State private var draftRoastLevel: String
    @State private var draftFlavorNotes: [String]
    @State private var flavorInput = ""

    @State private var isSaving = false
    @State private var saveError: String?

    private static let roastLevels = [
        ("light", "Light"), ("medium-light", "Medium-light"), ("medium", "Medium"),
        ("medium-dark", "Medium-dark"), ("dark", "Dark"),
    ]

    init(coffee: Coffee, onSave: @escaping (Coffee) -> Void) {
        self.coffee = coffee
        self.onSave = onSave
        _draftRoaster = State(initialValue: coffee.roaster ?? "")
        _draftName = State(initialValue: coffee.coffeeName ?? "")
        _draftCountry = State(initialValue: coffee.originCountry ?? "")
        _draftRegion = State(initialValue: coffee.originRegion ?? "")
        _draftProcess = State(initialValue: coffee.process ?? "")
        _draftVariety = State(initialValue: coffee.variety ?? "")
        _draftRoastDate = State(initialValue: coffee.roastDate ?? "")
        _draftRoastLevel = State(initialValue: coffee.roastLevel ?? "medium")
        _draftFlavorNotes = State(initialValue: coffee.flavorNotes)
    }

    var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(palette: palette)
                summary(palette: palette)
                fields(palette: palette)
                if let saveError {
                    Text(saveError)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(Palette.error)
                        .padding(.top, 12)
                }
                actions(palette: palette)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(palette.bg)
    }

    private func header(palette: Palette) -> some View {
        HStack {
            Text("Edit coffee")
                .font(.app(26, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(palette.fg)
            Spacer()
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(palette.line, lineWidth: 1))
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.fg)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private func summary(palette: Palette) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 12)
                .fill(coffee.swatchColor)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing")
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(palette.muted)
                Text(draftName.isEmpty ? "Untitled" : draftName)
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(palette.fg)
            }
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
        .padding(.top, 18)
    }

    private func fields(palette: Palette) -> some View {
        VStack(spacing: 15) {
            field("Roaster", text: $draftRoaster, palette: palette)
            field("Coffee", text: $draftName, palette: palette)
            HStack(spacing: 12) {
                field("Origin", text: $draftCountry, palette: palette)
                field("Region", text: $draftRegion, palette: palette)
            }
            HStack(spacing: 12) {
                field("Process", text: $draftProcess, palette: palette)
                field("Variety", text: $draftVariety, palette: palette)
            }
            field("Roast date", text: $draftRoastDate, palette: palette)
            roastLevelPicker(palette: palette)
            flavorNotesEditor(palette: palette)
        }
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

    private func roastLevelPicker(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Roast level")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Self.roastLevels, id: \.0) { value, label in
                        let active = draftRoastLevel == value
                        Button {
                            draftRoastLevel = value
                        } label: {
                            Text(label)
                                .font(.app(13, weight: .semibold))
                                .foregroundStyle(active ? palette.bg : palette.muted)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 7)
                                .background(active ? palette.fg : palette.surface2, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func flavorNotesEditor(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flavor notes")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
            FlowLayout(spacing: 7) {
                ForEach(draftFlavorNotes, id: \.self) { note in
                    HStack(spacing: 7) {
                        Text(note)
                            .font(.app(13, weight: .medium))
                            .foregroundStyle(palette.fg)
                        Button {
                            draftFlavorNotes.removeAll { $0 == note }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(palette.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(note)")
                    }
                    .padding(.leading, 13)
                    .padding(.trailing, 6)
                    .padding(.vertical, 6)
                    .background(palette.surface2, in: Capsule())
                }

                HStack(spacing: 6) {
                    TextField("Add note", text: $flavorInput)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(palette.fg)
                        .frame(width: 74)
                        .onSubmit(addFlavor)
                    Button(action: addFlavor) {
                        Circle()
                            .fill(palette.fg)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.bg)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add flavor note")
                }
                .padding(.leading, 13)
                .padding(.trailing, 4)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
        }
    }

    private func addFlavor() {
        let trimmed = flavorInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !draftFlavorNotes.contains(trimmed) else {
            flavorInput = ""
            return
        }
        draftFlavorNotes.append(trimmed)
        flavorInput = ""
    }

    private func actions(palette: Palette) -> some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
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
                        Text("Save changes")
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

    @MainActor
    private func save() async {
        var changed: [String: Sendable] = [:]
        if draftRoaster != (coffee.roaster ?? "") { changed["roaster"] = draftRoaster }
        if draftName != (coffee.coffeeName ?? "") { changed["coffeeName"] = draftName }
        if draftCountry != (coffee.originCountry ?? "") { changed["originCountry"] = draftCountry }
        if draftRegion != (coffee.originRegion ?? "") { changed["originRegion"] = draftRegion }
        if draftProcess != (coffee.process ?? "") { changed["process"] = draftProcess }
        if draftVariety != (coffee.variety ?? "") { changed["variety"] = draftVariety }
        if draftRoastDate != (coffee.roastDate ?? "") { changed["roastDate"] = draftRoastDate }
        if draftRoastLevel != (coffee.roastLevel ?? "") { changed["roastLevel"] = draftRoastLevel }
        if draftFlavorNotes != coffee.flavorNotes {
            changed["flavorNotes"] = draftFlavorNotes
            // Settings-selected model for categorizing any new notes.
            changed["model"] = SettingsStore.shared.model(for: .notes).rawValue
        }

        guard !changed.isEmpty else {
            dismiss()
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            let updated = try await APIClient.shared.updateCoffee(photoId: coffee.photoId, fields: changed)
            onSave(updated)
            dismiss()
        } catch {
            Logger.catalog.error("Saving coffee edits failed: \(error)")
            saveError = "Couldn't save — try again."
        }
    }
}
