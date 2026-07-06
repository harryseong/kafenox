import SwiftUI

/// Full-screen Settings, reached from the slide-out side menu: theme choice
/// (light/dark/system) and a Bedrock Claude model per AI feature.
struct SettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let settings: SettingsStore

    var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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

                Text("Settings")
                    .font(.app(32, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(palette.fg)
                    .padding(.top, 18)
                Text("Appearance and AI models")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 5)

                Text("Appearance")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 24)
                themeCard(palette: palette)
                    .padding(.top, 10)

                Text("AI models")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 28)
                Text("Anthropic Claude via Amazon Bedrock. Choose a model per feature.")
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 5)

                VStack(spacing: 12) {
                    ForEach(AIFeature.allCases) { feature in
                        featureCard(feature, palette: palette)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Appearance

    private func themeCard(palette: Palette) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Theme")
                    .font(.app(14.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(palette.fg)
                Text("Applies across the whole app")
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(ThemeChoice.allCases, id: \.self) { option in
                    let active = themeStore.choice == option
                    Button {
                        themeStore.choice = option
                    } label: {
                        Text(option.label)
                            .font(.app(12.5, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(active ? palette.bg : palette.muted)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(active ? palette.fg : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(palette.surface2, in: Capsule())
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
    }

    // MARK: AI models

    private func featureCard(_ feature: AIFeature, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.surface2)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: feature.systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.fg)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(.app(14.5, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(palette.fg)
                    Text(feature.subtitle)
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(palette.muted)
                }
            }

            VStack(spacing: 6) {
                ForEach(ModelChoice.allCases) { model in
                    modelRow(model, feature: feature, palette: palette)
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
    }

    private func modelRow(_ model: ModelChoice, feature: AIFeature, palette: Palette) -> some View {
        let active = settings.model(for: feature) == model
        return Button {
            settings.setModel(model, for: feature)
        } label: {
            HStack(spacing: 11) {
                Circle()
                    .fill(palette.bg)
                    .stroke(active ? palette.fg : palette.muted, lineWidth: active ? 5 : 1.5)
                    .frame(width: 16, height: 16)
                Text(model.displayName)
                    .font(.app(13.5, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(palette.fg)
                Spacer(minLength: 0)
                Text(model.tag)
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(active ? palette.surface2 : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(active ? palette.fg : palette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
