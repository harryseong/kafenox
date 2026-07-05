import MapKit
import SwiftUI

struct OriginsMapView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: MapViewModel

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 10, longitude: 20),
                            span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140))
    )

    var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Origins")
                    .font(.hanken(30, weight: 800))
                    .foregroundStyle(palette.fg)
                Text(viewModel.metaLine)
                    .font(.dmMono(11))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 7)

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
                    Circle().fill(palette.accent).frame(width: 8, height: 8)
                    Text("fewer coffees")
                        .font(.dmMono(10))
                        .foregroundStyle(palette.muted)
                    Circle().fill(palette.accent).frame(width: 15, height: 15).padding(.leading, 4)
                    Text("more coffees")
                        .font(.dmMono(10))
                        .foregroundStyle(palette.muted)
                }
                .padding(.top, 12)

                Text("MOST-BREWED ORIGINS")
                    .font(.hanken(13, weight: 700))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 22)

                VStack(spacing: 11) {
                    ForEach(viewModel.rankedOrigins.prefix(6)) { origin in
                        originRow(origin, palette: palette)
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .background(palette.bg)
    }

    private func originRow(_ origin: OriginStat, palette: Palette) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(origin.country)
                    .font(.hanken(14.5, weight: 700))
                    .foregroundStyle(palette.fg)
                Spacer()
                Text("\(origin.count) \(origin.count == 1 ? "coffee" : "coffees")")
                    .font(.dmMono(12))
                    .foregroundStyle(palette.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surface2)
                    Capsule().fill(palette.accent)
                        .frame(width: geo.size.width * CGFloat(origin.count) / CGFloat(viewModel.maxCount))
                }
            }
            .frame(height: 8)
        }
    }
}
