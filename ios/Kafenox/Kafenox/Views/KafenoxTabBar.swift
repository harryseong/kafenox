import SwiftUI

enum Tab { case catalog, map }

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
                        .fill(palette.accent)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundStyle(palette.onAccent)
                                .font(.system(size: 22, weight: .semibold))
                        )
                        .shadow(color: palette.accent.opacity(0.5), radius: 10, y: 4)
                    Text("Scan")
                        .font(.hanken(10, weight: 700))
                        .foregroundStyle(palette.accent)
                }
                .frame(maxWidth: .infinity)
                .offset(y: -6)
            }
            .buttonStyle(.plain)

            tabButton(tab: .map, systemImage: "globe.americas.fill", label: "Map")
        }
        .padding(.horizontal, 32)
        .padding(.top, 11)
        .frame(height: 88)
        .background(palette.surface)
        .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .top)
    }

    private func tabButton(tab: Tab, systemImage: String, label: String) -> some View {
        Button {
            activeTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 21))
                Text(label).font(.hanken(10, weight: 600))
            }
            .foregroundStyle(activeTab == tab ? palette.accent : palette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
