import Foundation

struct OriginStat: Identifiable {
    let country: String
    let count: Int
    let lat: Double
    let lng: Double
    var id: String { country }
}

@Observable
final class MapViewModel {
    private let catalog: CatalogViewModel

    init(catalog: CatalogViewModel) {
        self.catalog = catalog
    }

    var origins: [OriginStat] {
        var byCountry: [String: (count: Int, lat: Double, lng: Double)] = [:]
        for coffee in catalog.coffees {
            guard let country = coffee.originCountry, let lat = coffee.lat, let lng = coffee.lng else { continue }
            if let existing = byCountry[country] {
                byCountry[country] = (existing.count + 1, existing.lat, existing.lng)
            } else {
                byCountry[country] = (1, lat, lng)
            }
        }
        return byCountry.map { OriginStat(country: $0.key, count: $0.value.count, lat: $0.value.lat, lng: $0.value.lng) }
    }

    var maxCount: Int {
        origins.map(\.count).max() ?? 1
    }

    var rankedOrigins: [OriginStat] {
        origins.sorted { $0.count > $1.count }
    }

    var metaLine: String {
        let totalCoffees = catalog.coffees.count
        return "\(origins.count) origins · \(totalCoffees) coffees logged"
    }
}
