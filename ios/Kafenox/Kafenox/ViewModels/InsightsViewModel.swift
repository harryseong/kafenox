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

    /// Insights derives everything from the catalog, which normally loads
    /// when the Collection tab appears -- but the user can land on Insights
    /// first, so kick the load from here too.
    @MainActor
    func loadIfNeeded() async {
        if catalog.coffees.isEmpty {
            await catalog.load()
        }
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
    /// Family comes from the backend's Claude categorization when present,
    /// falling back to the client-side note lookup for older items.
    var flavorNoteStats: [FlavorNoteStat] {
        var counts: [String: Int] = [:]
        var backendFamilies: [String: String] = [:]
        for coffee in catalog.coffees {
            for note in coffee.flavorNotes {
                counts[note, default: 0] += 1
                if backendFamilies[note] == nil, let family = coffee.flavorFamilies?[note] {
                    backendFamilies[note] = family
                }
            }
        }
        return counts.map { note, count in
            let family = backendFamilies[note].flatMap(FlavorFamily.named) ?? FlavorFamily.of(note)
            return FlavorNoteStat(note: note, count: count, family: family)
        }
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

    // MARK: Timeline

    /// Coffees grouped by the month they were roasted, newest month first.
    var timelineGroups: [TimelineGroup] {
        let calendar = Calendar.current
        var byMonth: [Date: [(date: Date, coffee: Coffee)]] = [:]
        for coffee in catalog.coffees {
            guard let date = Self.timelineDate(of: coffee) else { continue }
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            byMonth[month, default: []].append((date, coffee))
        }
        return byMonth
            .sorted { $0.key > $1.key }
            .map { month, entries in
                TimelineGroup(
                    monthStart: month,
                    label: month.formatted(.dateTime.month(.wide).year()),
                    coffees: entries.sorted { $0.date > $1.date }.map(\.coffee)
                )
            }
    }

    /// Timeline entries are ordered by roast date ("YYYY-MM" or "YYYY-MM-DD"
    /// per the extraction schema), falling back to the logged date for
    /// coffees whose label carried no roast date.
    private static func timelineDate(of coffee: Coffee) -> Date? {
        if let raw = coffee.roastDate {
            let parts = raw.split(separator: "-")
            if parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]),
               (1...12).contains(month) {
                let day = parts.count >= 3 ? Int(parts[2]) : nil
                if let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day ?? 1)) {
                    return date
                }
            }
        }
        return loggedDate(of: coffee)
    }

    var timelineMetaLine: String {
        "\(catalog.coffees.count) coffees over \(timelineGroups.count) months"
    }

    var askMetaLine: String {
        "Grounded in \(catalog.coffees.count) logged coffees"
    }

    /// The backend writes Python `datetime.isoformat()` ("+00:00" offset,
    /// microsecond fractions); older/other writers may use "Z" or no
    /// fraction. FormatStyles are Sendable value types, unlike the Formatter
    /// classes, so these are safe as statics under Swift 6 concurrency.
    private static let isoParsers: [Date.ISO8601FormatStyle] = [
        .init(timeZoneSeparator: .colon, includingFractionalSeconds: true),
        .init(timeZoneSeparator: .colon),
        .init(includingFractionalSeconds: true),
        .init(),
    ]

    private static func loggedDate(of coffee: Coffee) -> Date? {
        guard let raw = coffee.createdAt else { return nil }
        return isoParsers.lazy.compactMap { try? $0.parse(raw) }.first
    }
}

struct TimelineGroup: Identifiable {
    let monthStart: Date
    let label: String
    let coffees: [Coffee]
    var id: Date { monthStart }
}
