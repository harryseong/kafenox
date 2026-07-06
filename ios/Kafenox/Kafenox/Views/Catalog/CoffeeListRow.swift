import SwiftUI

/// A list row that swipes left to reveal Edit/Delete actions (v3 design's
/// "swipe left for actions" list behavior). Only one row is open at a time,
/// tracked by the parent through `openId`; tapping an open row closes it
/// instead of navigating.
struct SwipeableCoffeeRow: View {
    let coffee: Coffee
    let palette: Palette
    @Binding var openId: String?
    var onEdit: () -> Void
    var onDelete: () -> Void

    /// Live drag translation, added on top of the resting offset.
    @State private var dragX: CGFloat = 0

    private static let actionsWidth: CGFloat = 128

    private var isOpen: Bool { openId == coffee.photoId }

    private var offsetX: CGFloat {
        let base = isOpen ? -Self.actionsWidth : 0
        return min(0, max(-150, base + dragX))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button(action: {
                    openId = nil
                    onEdit()
                }) {
                    Text("Edit")
                        .font(.app(12.5, weight: .semibold))
                        .foregroundStyle(palette.fg)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                        .background(palette.surface2)
                }
                .buttonStyle(.plain)
                Button(action: {
                    openId = nil
                    onDelete()
                }) {
                    Text("Delete")
                        .font(.app(12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                        .background(Palette.error)
                }
                .buttonStyle(.plain)
            }

            NavigationLink(value: coffee) {
                CoffeeListRow(coffee: coffee, palette: palette)
                    .background(palette.bg)
            }
            .buttonStyle(.plain)
            .offset(x: offsetX)
            // Tapping while open just closes the row.
            .overlay {
                if isOpen && dragX == 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(x: offsetX)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { openId = nil } }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        dragX = value.translation.width
                    }
                    .onEnded { value in
                        let settled = offsetX
                        withAnimation(.easeOut(duration: 0.18)) {
                            dragX = 0
                            openId = settled < -64 ? coffee.photoId : (isOpen ? nil : openId)
                        }
                    }
            )
        }
        .clipped()
    }
}

struct CoffeeListRow: View {
    let coffee: Coffee
    let palette: Palette

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(coffee.swatchColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(coffee.coffeeName ?? "Untitled")
                    .font(.app(15.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(palette.fg)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(ratingText)
                .font(.app(13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.muted)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.muted)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 2)
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .bottom)
    }

    private var subtitle: String {
        [coffee.roaster, coffee.originLabel.isEmpty ? nil : coffee.originLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var ratingText: String {
        guard let rating = coffee.rating else { return "—" }
        return "\(rating)/10"
    }
}
