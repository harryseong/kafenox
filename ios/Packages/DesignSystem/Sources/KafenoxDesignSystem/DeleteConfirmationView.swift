import SwiftUI

/// Centered confirmation modal matching the v3 design: a custom overlay
/// (not a native alert) so blur/shadow/typography match the design exactly.
public struct DeleteConfirmationView: View {
    public let palette: Palette
    public var isDeleting: Bool
    public var errorMessage: String?
    public var onCancel: () -> Void
    public var onDelete: () -> Void

    public init(
        palette: Palette,
        isDeleting: Bool,
        errorMessage: String?,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.palette = palette
        self.isDeleting = isDeleting
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .background(.thinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityLabel("Dismiss")
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 0) {
                Text("Delete this coffee?")
                    .appFont(19, weight: .bold)
                    .tracking(-0.3)
                    .foregroundStyle(palette.fg)
                    .multilineTextAlignment(.center)
                Text("This removes it from your collection and all insights. This can't be undone.")
                    .appFont(13)
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 9)
                if let errorMessage {
                    Text(errorMessage)
                        .appFont(12.5, weight: .medium)
                        .foregroundStyle(Palette.error)
                        .padding(.top, 8)
                }
                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .appFont(14.5, weight: .semibold)
                            .foregroundStyle(palette.fg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Group {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Delete")
                                    .appFont(14.5, weight: .semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Palette.error, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
                .padding(.top, 22)
            }
            .padding(24)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: palette.shadow, radius: 30, y: 14)
            .padding(34)
        }
    }
}
