import KafenoxDesignSystem
import SwiftUI

enum Tab { case catalog, insights }

struct KafenoxTabBar: View {
    let palette: Palette
    @Binding var activeTab: Tab
    var onScan: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tabButton(tab: .catalog, systemImage: "square.grid.2x2.fill", label: "Collection")

            Button(action: onScan) {
                VStack(spacing: 5) {
                    Circle()
                        .fill(palette.fg)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundStyle(palette.bg)
                                .font(.system(size: 21, weight: .semibold))
                                .accessibilityHidden(true)
                        )
                        .shadow(color: palette.shadow, radius: 9, y: 4)
                    Text("Scan")
                        .font(.app(10, weight: .semibold))
                        .foregroundStyle(palette.fg)
                }
                .frame(maxWidth: .infinity)
                .offset(y: -9)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan a coffee bag")
            .accessibilityAddTraits(.isButton)

            tabButton(tab: .insights, systemImage: "chart.bar.fill", label: "Insights")
        }
        .padding(.horizontal, 32)
        .padding(.top, 11)
        .frame(height: 84)
        .background(palette.surface.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .top)
    }

    private func tabButton(tab: Tab, systemImage: String, label: String) -> some View {
        Button {
            activeTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 21))
                Text(label)
                    .font(.app(10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(activeTab == tab ? palette.fg : palette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(activeTab == tab ? [.isButton, .isSelected] : .isButton)
    }
}
