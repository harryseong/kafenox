import KafenoxDesignSystem
import SwiftUI

/// Full-screen Settings, reached from the slide-out side menu: theme choice
/// (light/dark/system) and a Bedrock Claude model per AI feature.
public struct SettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Which AI-feature row is expanded in the accordion (one at a time).
    @State private var expandedFeature: AIFeature?

    public var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Settings")
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
                    .buttonStyle(PressScaleButtonStyle())
                }
                Text("Appearance and AI models")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 6)

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

                VStack(spacing: 0) {
                    ForEach(AIFeature.allCases) { feature in
                        featureRow(feature, palette: palette)
                        if feature != AIFeature.allCases.last {
                            Rectangle().fill(palette.line).frame(height: 1)
                        }
                    }
                }
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

    /// A collapsible feature row: header shows the current model; expanding
    /// reveals the options with a checkmark on the active one.
    private func featureRow(_ feature: AIFeature, palette: Palette) -> some View {
        let expanded = expandedFeature == feature
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    expandedFeature = expanded ? nil : feature
                }
            } label: {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(palette.surface2)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: feature.systemImage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.fg)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.app(14, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(palette.fg)
                        Text(feature.subtitle)
                            .font(.app(11.5, weight: .medium))
                            .foregroundStyle(palette.muted)
                    }
                    Spacer(minLength: 8)
                    Text(settings.model(for: feature).displayName)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    Rectangle().fill(palette.line).frame(height: 1)
                    ForEach(ModelChoice.allCases) { model in
                        optionRow(model, feature: feature, palette: palette)
                    }
                }
                .background(palette.surface2)
            }
        }
    }

    private func optionRow(_ model: ModelChoice, feature: AIFeature, palette: Palette) -> some View {
        let active = settings.model(for: feature) == model
        return Button {
            settings.setModel(model, for: feature)
            withAnimation(.easeOut(duration: 0.18)) { expandedFeature = nil }
        } label: {
            HStack(spacing: 10) {
                Text(model.displayName)
                    .font(.app(13.5, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(palette.fg)
                Spacer(minLength: 0)
                Text(model.tag)
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(palette.muted)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.fg)
                    .opacity(active ? 1 : 0)
            }
            .padding(.vertical, 12)
            .padding(.leading, 55)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
