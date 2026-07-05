import MapKit
import SwiftUI

struct InsightsView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: InsightsViewModel

    enum Section: String, CaseIterable, Identifiable {
        case origins = "Origins"
        case flavors = "Flavors"
        case timeline = "Timeline"
        case askAI = "Ask AI"
        var id: String { rawValue }
    }

    @State private var section: Section = .origins
    @State private var askViewModel = AskAIViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 10, longitude: 20),
                            span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140))
    )

    var body: some View {
        let palette = themeStore.palette
        Group {
            if section == .askAI {
                // The chat manages its own scrolling and pins the composer at
                // the bottom, so its header stays fixed instead of scrolling.
                VStack(alignment: .leading, spacing: 0) {
                    header(palette: palette)
                    tabPills(palette: palette)
                    AskAIView(viewModel: askViewModel, palette: palette)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            } else {
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
                        case .askAI:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(palette.bg)
        // The Map on the Origins tab makes the NavigationStack show its
        // (empty) navigation bar, pushing that tab's content down relative to
        // the others. Every tab draws its own header, so hide the bar.
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadIfNeeded() }
    }

    private var metaLine: String {
        switch section {
        case .origins: return viewModel.originMetaLine
        case .flavors: return viewModel.flavorMetaLine
        case .timeline: return viewModel.timelineMetaLine
        case .askAI: return viewModel.askMetaLine
        }
    }

    private func header(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Insights")
                .font(.app(32, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(palette.fg)
            Text(metaLine)
                .font(.app(13, weight: .medium))
                .foregroundStyle(palette.muted)
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
                    .buttonStyle(.plain)
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
                    Annotation(origin.country, coordinate: CLLocationCoordinate2D(latitude: origin.lat, longitude: origin.lng)) {
                        OriginPin(count: origin.count, maxCount: viewModel.maxCount, palette: palette)
                    }
                }
            }
            .frame(height: 268)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.line, lineWidth: 1))
            .padding(.top, 18)

            HStack(spacing: 8) {
                Circle().fill(palette.fg).frame(width: 8, height: 8)
                Text("fewer coffees")
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(palette.muted)
                Circle().fill(palette.fg).frame(width: 15, height: 15).padding(.leading, 4)
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
