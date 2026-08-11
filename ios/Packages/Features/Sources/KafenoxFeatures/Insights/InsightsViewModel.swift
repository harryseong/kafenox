import Foundation
import KafenoxCore

public struct OriginStat: Identifiable, Sendable {
    public let country: String
    public let count: Int
    public let lat: Double
    public let lng: Double
    public var id: String { country }

    public init(country: String, count: Int, lat: Double, lng: Double) {
        self.country = country
        self.count = count
        self.lat = lat
        self.lng = lng
    }
}

@Observable
public final class InsightsViewModel {
    private let catalog: CatalogViewModel

    public init(catalog: CatalogViewModel) {
        self.catalog = catalog
    }

    /// Insights derives everything from the catalog, which normally loads
    /// when the Collection tab appears -- but the user can land on Insights
    /// first, so kick the load from here too.
    @MainActor
    public func loadIfNeeded() async {
        if catalog.coffees.isEmpty {
            await catalog.load()
        }
    }

    // MARK: Origins

    public var origins: [OriginStat] {
        var byCountry: [String: (count: Int, lat: Double, lng: Double)] = [:]
        for coffee in catalog.coffees {
            guard let country = coffee.originCountry, let lat = coffee.lat, let lng = coffee.lng else { continue }
            if let existing = byCountry[country] {
                byCountry[country] = (existing.count + 1, existing.lat, existing.lng)
            } else {
                byCountry[country] = (1, lat, lng)
            }
        }
        return byCountry.map {
            OriginStat(country: $0.key, count: $0.value.count, lat: $0.value.lat, lng: $0.value.lng)
        }
    }

    public var maxCount: Int {
        origins.map(\.count).max() ?? 1
    }

    public var rankedOrigins: [OriginStat] {
        origins.sorted { $0.count > $1.count }
    }

    public var originMetaLine: String {
        let totalCoffees = catalog.coffees.count
        return "\(origins.count) origins · \(totalCoffees) coffees logged"
    }

    // MARK: Flavors

    /// One entry per distinct note, counting how many coffees carry it.
    /// Family comes from the backend's Claude categorization when present,
    /// falling back to the client-side note lookup for older items.
    public var flavorNoteStats: [FlavorNoteStat] {
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
    public var rankedNotes: [FlavorNoteStat] {
        flavorNoteStats.sorted { $0.count != $1.count ? $0.count > $1.count : $0.note < $1.note }
    }

    public var maxNoteCount: Int {
        flavorNoteStats.map(\.count).max() ?? 1
    }

    public var topNotes: [FlavorNoteStat] {
        Array(rankedNotes.prefix(5))
    }

    /// Per-family totals, dropping empty families, biggest first.
    public var familyStats: [FlavorFamilyStat] {
        let byFamily = Dictionary(grouping: flavorNoteStats, by: \.family.name)
        return FlavorFamily.all
            .map { family in
                FlavorFamilyStat(family: family, total: byFamily[family.name]?.reduce(0) { $0 + $1.count } ?? 0)
            }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    public var maxFamilyTotal: Int {
        familyStats.map(\.total).max() ?? 1
    }

    public var flavorMetaLine: String {
        "\(flavorNoteStats.count) distinct notes across \(catalog.coffees.count) coffees"
    }

    // MARK: Timeline

    /// Coffees grouped by the month they were roasted, newest month first;
    /// within a month, best-rated first (per the v3 design).
    public var timelineGroups: [TimelineGroup] {
        let calendar = Calendar.current
        var byMonth: [Date: [Coffee]] = [:]
        for coffee in catalog.coffees {
            guard let date = Self.timelineDate(of: coffee) else { continue }
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            byMonth[month, default: []].append(coffee)
        }
        return
            byMonth
            .sorted { $0.key > $1.key }
            .map { month, coffees in
                TimelineGroup(
                    monthStart: month,
                    label: month.formatted(.dateTime.month(.wide).year()),
                    agoLabel: Self.agoLabel(for: month, calendar: calendar),
                    coffees: coffees.sorted { ($0.rating ?? -1) > ($1.rating ?? -1) }
                )
            }
    }

    /// "this month" / "1 mo ago" / "N mo ago", matching the design's rail
    /// header.
    private static func agoLabel(for month: Date, calendar: Calendar) -> String {
        let now = calendar.dateComponents([.year, .month], from: Date())
        let then = calendar.dateComponents([.year, .month], from: month)
        guard let ny = now.year, let nm = now.month, let ty = then.year, let tm = then.month else { return "" }
        let delta = (ny * 12 + nm) - (ty * 12 + tm)
        switch delta {
        case ...0: return "this month"
        case 1: return "1 mo ago"
        default: return "\(delta) mo ago"
        }
    }

    /// Timeline entries are ordered by roast date ("YYYY-MM" or "YYYY-MM-DD"
    /// per the extraction schema), falling back to the logged date for
    /// coffees whose label carried no roast date.
    private static func timelineDate(of coffee: Coffee) -> Date? {
        if let raw = coffee.roastDate {
            let parts = raw.split(separator: "-")
            if parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]),
                (1...12).contains(month)
            {
                let day = parts.count >= 3 ? Int(parts[2]) : nil
                if let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day ?? 1)) {
                    return date
                }
            }
        }
        return loggedDate(of: coffee)
    }

    public var timelineMetaLine: String {
        let groups = timelineGroups
        guard let newest = groups.first, let oldest = groups.last else { return "By roast date" }
        return "By roast date · \(oldest.label) — \(newest.label)"
    }

    public var askMetaLine: String {
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

public struct TimelineGroup: Identifiable, Sendable {
    public let monthStart: Date
    public let label: String
    public let agoLabel: String
    public let coffees: [Coffee]
    public var id: Date { monthStart }

    public init(monthStart: Date, label: String, agoLabel: String, coffees: [Coffee]) {
        self.monthStart = monthStart
        self.label = label
        self.agoLabel = agoLabel
        self.coffees = coffees
    }
}
