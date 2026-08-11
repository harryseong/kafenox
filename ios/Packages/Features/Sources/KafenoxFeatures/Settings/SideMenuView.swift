import KafenoxDesignSystem
import SwiftUI

/// The 36pt circular hamburger button in the Collection and Insights
/// mastheads that opens the side menu.
struct MenuButton: View {
    let palette: Palette
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(palette.surface)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(palette.line, lineWidth: 1))
                .overlay(
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.fg)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
    }
}

/// The slide-out panel over the main screens (Collection/Insights); its
/// only destination today is Settings.
public struct SideMenuView: View {
    let palette: Palette
    var onSettings: () -> Void
    var onClose: () -> Void

    public init(
        palette: Palette,
        onSettings: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.onSettings = onSettings
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
                .accessibilityLabel("Close menu")
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Circle()
                            .fill(palette.surface)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(palette.line, lineWidth: 1))
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.fg)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close menu")
                }

                Text("Menu")
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(palette.muted)
                    .padding(.horizontal, 12)
                    .padding(.top, 14)

                Button(action: onSettings) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(palette.fg)
                        Text("Settings")
                            .appFont(14.5, weight: .semibold)
                            .tracking(-0.2)
                            .foregroundStyle(palette.fg)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.muted)
                    }
                    .padding(12)
                    .background(palette.surface2.opacity(0.001), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 34)
            .frame(width: 264, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(palette.bg.ignoresSafeArea())
            .overlay(Rectangle().fill(palette.line).frame(width: 1).ignoresSafeArea(), alignment: .leading)
            .shadow(color: palette.shadow, radius: 30, x: -24)
            .transition(.move(edge: .trailing))
        }
    }
}
