import Foundation

struct OriginStat: Identifiable {
    let country: String
    let count: Int
    let lat: Double
    let lng: Double
    var id: String { country }
}

@Observable
final class InsightsViewModel {
    private let catalog: CatalogViewModel

    init(catalog: CatalogViewModel) {
        self.catalog = catalog
    }

    // MARK: Origins

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

    var originMetaLine: String {
        let totalCoffees = catalog.coffees.count
        return "\(origins.count) origins · \(totalCoffees) coffees logged"
    }

    // MARK: Flavors

    /// One entry per distinct note, counting how many coffees carry it.
    var flavorNoteStats: [FlavorNoteStat] {
        var counts: [String: Int] = [:]
        for coffee in catalog.coffees {
            for note in coffee.flavorNotes { counts[note, default: 0] += 1 }
        }
        return counts.map { FlavorNoteStat(note: $0.key, count: $0.value, family: FlavorFamily.of($0.key)) }
    }

    /// Notes ranked most-common first, ties broken alphabetically.
    var rankedNotes: [FlavorNoteStat] {
        flavorNoteStats.sorted { $0.count != $1.count ? $0.count > $1.count : $0.note < $1.note }
    }

    var maxNoteCount: Int {
        flavorNoteStats.map(\.count).max() ?? 1
    }

    var topNotes: [FlavorNoteStat] {
        Array(rankedNotes.prefix(5))
    }

    /// Per-family totals, dropping empty families, biggest first.
    var familyStats: [FlavorFamilyStat] {
        let byFamily = Dictionary(grouping: flavorNoteStats, by: \.family.name)
        return FlavorFamily.all
            .map { family in
                FlavorFamilyStat(family: family, total: byFamily[family.name]?.reduce(0) { $0 + $1.count } ?? 0)
            }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    var maxFamilyTotal: Int {
        familyStats.map(\.total).max() ?? 1
    }

    var flavorMetaLine: String {
        "\(flavorNoteStats.count) distinct notes across \(catalog.coffees.count) coffees"
    }
}
