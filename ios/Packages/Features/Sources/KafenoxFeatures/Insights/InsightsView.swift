import KafenoxDesignSystem
import MapKit
import SwiftUI

public struct InsightsView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: InsightsViewModel
    var onMenu: () -> Void = {}

    public init(viewModel: InsightsViewModel, onMenu: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onMenu = onMenu
    }

    enum Section: String, CaseIterable, Identifiable {
        case origins = "Origins"
        case flavors = "Flavors"
        case timeline = "Timeline"
        var id: String { rawValue }
    }

    @State private var section: Section = .origins
    @State private var askViewModel = AskAIViewModel()
    @State private var isAskPresented = false
    @State private var isScrolled = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10, longitude: 20),
            span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140))
    )

    public var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(palette: palette)
                tabPills(palette: palette)
                switch section {
                case .origins:
                    originsContent(palette: palette)
                case .flavors:
                    FlavorsInsightView(viewModel: viewModel, palette: palette)
                case .timeline:
                    TimelineInsightView(groups: viewModel.timelineGroups, palette: palette)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 52
        } action: { _, scrolled in
            withAnimation(.easeOut(duration: 0.18)) { isScrolled = scrolled }
        }
        .overlay(alignment: .top) {
            CompactHeaderBar(title: "Insights", visible: isScrolled, palette: palette)
        }
        .overlay(alignment: .bottomTrailing) {
            askFab(palette: palette)
        }
        .background(palette.bg)
        // The Map on the Origins tab makes the NavigationStack show its
        // (empty) navigation bar, pushing that tab's content down relative to
        // the others. Every tab draws its own header, so hide the bar.
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadIfNeeded() }
        .fullScreenCover(isPresented: $isAskPresented) {
            AskAIScreen(viewModel: askViewModel, metaLine: viewModel.askMetaLine)
        }
    }

    /// The floating Ask AI entry point, bottom-right above the tab bar.
    private func askFab(palette: Palette) -> some View {
        Button {
            isAskPresented = true
        } label: {
            Circle()
                .fill(palette.fg)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.bg)
                        .accessibilityHidden(true)
                )
                .shadow(color: palette.shadow, radius: 15, y: 7)
                .opacity(0.6)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Ask AI")
        .accessibilityHint("Opens a chat grounded in your collection")
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private var metaLine: String {
        switch section {
        case .origins: return viewModel.originMetaLine
        case .flavors: return viewModel.flavorMetaLine
        case .timeline: return viewModel.timelineMetaLine
        }
    }

    private func header(palette: Palette) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Insights")
                    .font(.app(32, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(palette.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(metaLine)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            MenuButton(palette: palette, action: onMenu)
                .padding(.top, 3)
        }
    }

    private func tabPills(palette: Palette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Section.allCases) { item in
                    let active = section == item
                    Button {
                        section = item
                    } label: {
                        Text(item.rawValue)
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(active ? palette.bg : palette.muted)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 15)
                            .background(active ? palette.fg : palette.surface2, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.94))
                }
            }
        }
        .padding(.top, 14)
    }

    // MARK: Origins

    private func originsContent(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(position: $cameraPosition) {
                ForEach(viewModel.origins) { origin in
                    Annotation(
                        origin.country, coordinate: CLLocationCoordinate2D(latitude: origin.lat, longitude: origin.lng)
                    ) {
                        OriginPin(count: origin.count, maxCount: viewModel.maxCount, palette: palette)
                    }
                }
            }
            .frame(height: 268)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.line, lineWidth: 1))
            .padding(.top, 18)

            HStack(spacing: 8) {
                Circle().stroke(palette.muted, lineWidth: 1).frame(width: 8, height: 8)
                Text("fewer coffees")
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(palette.muted)
                Circle().stroke(palette.muted, lineWidth: 1).frame(width: 15, height: 15).padding(.leading, 4)
                Text("more coffees")
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            .padding(.top, 12)

            Text("Most-brewed origins")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(palette.muted)
                .padding(.top, 22)

            VStack(spacing: 11) {
                ForEach(viewModel.rankedOrigins.prefix(6)) { origin in
                    originRow(origin, palette: palette)
                }
            }
            .padding(.top, 14)
        }
    }

    private func originRow(_ origin: OriginStat, palette: Palette) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(origin.country)
                    .font(.app(14.5, weight: .semibold))
                    .foregroundStyle(palette.fg)
                Spacer()
                Text("\(origin.count) \(origin.count == 1 ? "coffee" : "coffees")")
                    .font(.app(12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface2)
                    Capsule().fill(palette.fg)
                        .frame(width: geo.size.width * CGFloat(origin.count) / CGFloat(viewModel.maxCount))
                }
            }
            .frame(height: 4)
        }
    }
}

/// The condensed title bar that fades in over Collection/Insights once the
/// large masthead scrolls out of view.
struct CompactHeaderBar: View {
    let title: String
    let visible: Bool
    let palette: Palette

    var body: some View {
        Text(title)
            .font(.app(15.5, weight: .bold))
            .tracking(-0.2)
            .foregroundStyle(palette.fg)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(palette.bg)
            .overlay(Rectangle().fill(palette.line).frame(height: 1), alignment: .bottom)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : -10)
            .allowsHitTesting(false)
    }
}
