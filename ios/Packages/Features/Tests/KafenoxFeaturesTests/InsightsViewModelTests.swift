import Foundation
import KafenoxCore
import Testing

@testable import KafenoxFeatures

private func coffee(
    _ id: String,
    country: String? = nil,
    lat: Double? = nil,
    lng: Double? = nil,
    notes: [String] = [],
    families: [String: String]? = nil,
    roastDate: String? = nil,
    createdAt: String? = nil,
    rating: Int? = nil
) -> Coffee {
    Coffee(
        photoId: id, status: "COMPLETE", createdAt: createdAt,
        originCountry: country, roastDate: roastDate,
        flavorNotes: notes, flavorFamilies: families,
        lat: lat, lng: lng, rating: rating, isVerified: true
    )
}

private func insights(_ coffees: [Coffee]) async -> InsightsViewModel {
    let repo = StubCoffeeRepository()
    await repo.setList(.success(coffees))
    let catalog = CatalogViewModel(repository: repo, useMockData: false)
    await catalog.load()
    return InsightsViewModel(catalog: catalog)
}

@Suite("Origin aggregation")
struct InsightsOriginTests {
    @Test("Coffees from the same country collapse into one pin")
    func groupsByCountry() async {
        let model = await insights([
            coffee("a", country: "Kenya", lat: -0.4, lng: 37),
            coffee("b", country: "Kenya", lat: -0.4, lng: 37),
            coffee("c", country: "Brazil", lat: -18, lng: -46),
        ])

        #expect(model.origins.count == 2)
        #expect(model.origins.first(where: { $0.country == "Kenya" })?.count == 2)
        #expect(model.maxCount == 2)
    }

    @Test("Coffees without coordinates are skipped rather than pinned at zero")
    func skipsMissingCoordinates() async {
        let model = await insights([coffee("a", country: "Kenya"), coffee("b")])
        #expect(model.origins.isEmpty)
    }

    @Test("An empty collection still yields a usable max for bar scaling")
    func emptyMaxCount() async {
        #expect(await insights([]).maxCount == 1)
    }

    @Test("Origins rank most-brewed first")
    func ranked() async {
        let model = await insights([
            coffee("a", country: "Kenya", lat: 1, lng: 1),
            coffee("b", country: "Brazil", lat: 2, lng: 2),
            coffee("c", country: "Brazil", lat: 2, lng: 2),
        ])
        #expect(model.rankedOrigins.first?.country == "Brazil")
    }
}

@Suite("Flavor aggregation")
struct InsightsFlavorTests {
    @Test("Notes are counted across coffees")
    func countsNotes() async {
        let model = await insights([
            coffee("a", notes: ["Caramel", "Peach"]),
            coffee("b", notes: ["Caramel"]),
        ])

        let caramel = model.flavorNoteStats.first { $0.note == "Caramel" }
        #expect(caramel?.count == 2)
        #expect(model.maxNoteCount == 2)
    }

    /// The backend's Claude categorization wins over the built-in table, so
    /// notes it has classified don't fall back to "Other".
    @Test("A backend-assigned family beats the client-side lookup")
    func backendFamilyWins() async {
        let model = await insights([
            coffee("a", notes: ["Yuzu"], families: ["Yuzu": "Fruity"])
        ])

        #expect(model.flavorNoteStats.first?.family.name == "Fruity")
    }

    @Test("Notes with no backend family fall back to the local table")
    func fallsBackToLocalTable() async {
        let model = await insights([coffee("a", notes: ["Bergamot"])])
        #expect(model.flavorNoteStats.first?.family.name == "Floral & Tea")
    }

    @Test("Families with no notes are dropped from the chart")
    func dropsEmptyFamilies() async {
        let model = await insights([coffee("a", notes: ["Caramel"])])
        #expect(model.familyStats.map(\.family.name) == ["Sweet"])
    }

    @Test("Ties between equally common notes break alphabetically")
    func stableRanking() async {
        let model = await insights([coffee("a", notes: ["Zest", "Almond"])])
        #expect(model.rankedNotes.map(\.note) == ["Almond", "Zest"])
    }
}

@Suite("Timeline grouping")
struct InsightsTimelineTests {
    @Test("Coffees group by roast month, newest month first")
    func groupsByMonth() async {
        let model = await insights([
            coffee("older", roastDate: "2025-01"),
            coffee("newer", roastDate: "2025-03"),
        ])

        #expect(model.timelineGroups.count == 2)
        #expect(model.timelineGroups.first?.coffees.first?.photoId == "newer")
    }

    @Test("Within a month, better-rated coffees come first")
    func sortsByRating() async {
        let model = await insights([
            coffee("meh", roastDate: "2025-03", rating: 5),
            coffee("great", roastDate: "2025-03", rating: 9),
            coffee("unrated", roastDate: "2025-03"),
        ])

        let group = try? #require(model.timelineGroups.first)
        #expect(group?.coffees.map(\.photoId) == ["great", "meh", "unrated"])
    }

    @Test("Both YYYY-MM and YYYY-MM-DD roast dates parse")
    func parsesRoastDateForms() async {
        let model = await insights([
            coffee("short", roastDate: "2025-03"),
            coffee("long", roastDate: "2025-03-14"),
        ])
        #expect(model.timelineGroups.count == 1, "both belong to March 2025")
    }

    /// The backend writes Python isoformat timestamps; older writers used a
    /// "Z" suffix or omitted fractional seconds.
    @Test(
        "Coffees without a roast date fall back to when they were logged",
        arguments: [
            "2025-03-14T09:00:00+00:00",
            "2025-03-14T09:00:00.123456+00:00",
            "2025-03-14T09:00:00Z",
        ])
    func fallsBackToLoggedDate(_ timestamp: String) async {
        let model = await insights([coffee("a", createdAt: timestamp)])
        #expect(model.timelineGroups.count == 1)
    }

    @Test("A coffee with neither roast nor logged date is left out entirely")
    func dropsUndateableCoffees() async {
        let model = await insights([coffee("a")])
        #expect(model.timelineGroups.isEmpty)
    }

    @Test("An unparseable roast date does not crash the timeline")
    func toleratesGarbageDates() async {
        let model = await insights([coffee("a", roastDate: "sometime last spring")])
        #expect(model.timelineGroups.isEmpty)
    }

    @Test("An empty collection reports a bare meta line")
    func emptyMetaLine() async {
        #expect(await insights([]).timelineMetaLine == "By roast date")
    }
}
