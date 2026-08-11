import KafenoxCore
import Testing

@testable import KafenoxFeatures

private func makeCoffee(
    _ id: String,
    status: String = "COMPLETE",
    name: String? = nil,
    roaster: String? = nil,
    country: String? = nil,
    roastLevel: String? = "medium",
    notes: [String] = [],
    verified: Bool = true
) -> Coffee {
    Coffee(
        photoId: id, status: status,
        roaster: roaster, coffeeName: name, originCountry: country,
        roastLevel: roastLevel, flavorNotes: notes, isVerified: verified
    )
}

private func makeModel(repository: StubCoffeeRepository = StubCoffeeRepository()) -> CatalogViewModel {
    CatalogViewModel(repository: repository, useMockData: false)
}

@Suite("Catalog loading")
struct CatalogLoadingTests {
    @Test("A successful load populates the collection")
    func loadsCoffees() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("a"), makeCoffee("b")]))
        let model = makeModel(repository: repo)

        await model.load()

        #expect(model.coffees.count == 2)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test("A failure surfaces a readable message rather than a raw error")
    func surfacesFailure() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.failure(StubCoffeeRepository.Failure()))
        let model = makeModel(repository: repo)

        await model.load()

        #expect(model.coffees.isEmpty)
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading, "the loading flag must clear even on the error path")
    }
}

@Suite("Catalog filtering")
struct CatalogFilteringTests {
    private func loaded() async -> CatalogViewModel {
        let repo = StubCoffeeRepository()
        await repo.setList(
            .success([
                makeCoffee(
                    "light", name: "Konga", roaster: "Ridgeline", country: "Ethiopia",
                    roastLevel: "light", notes: ["Bergamot", "Peach"]),
                makeCoffee(
                    "medium", name: "Esperanza", roaster: "Ember", country: "Colombia",
                    roastLevel: "medium", notes: ["Caramel"]),
                makeCoffee(
                    "dark", name: "Batak", roaster: "Drift", country: "Indonesia",
                    roastLevel: "dark", notes: ["Cedar"]),
            ]))
        let model = makeModel(repository: repo)
        await model.load()
        return model
    }

    @Test("No filters shows everything")
    func unfiltered() async {
        #expect(await loaded().filtered.count == 3)
    }

    @Test("The roast chip narrows to that bucket")
    func roastFilter() async {
        let model = await loaded()
        model.roastFilter = "Light"
        #expect(model.filtered.map(\.photoId) == ["light"])
    }

    @Test(
        "Search matches name, roaster, origin, and flavor notes",
        arguments: [
            ("konga", "light"), ("ember", "medium"), ("indonesia", "dark"), ("bergamot", "light"),
        ])
    func searchFields(_ query: String, _ expectedId: String) async {
        let model = await loaded()
        model.query = query
        #expect(model.filtered.map(\.photoId) == [expectedId])
    }

    @Test("Search is case- and whitespace-insensitive")
    func searchNormalization() async {
        let model = await loaded()
        model.query = "  KONGA "
        #expect(model.filtered.map(\.photoId) == ["light"])
    }

    @Test("A query matching nothing yields an empty list, not everything")
    func noMatches() async {
        let model = await loaded()
        model.query = "unobtainium"
        #expect(model.filtered.isEmpty)
    }
}

@Suite("In-flight scans stay visible")
struct CatalogInFlightTests {
    /// A queued scan has no roast level or searchable text yet, so applying
    /// the normal filters to it would make it vanish the moment the user
    /// typed or picked a chip -- exactly when they are looking for it.
    private func mixed() async -> CatalogViewModel {
        let repo = StubCoffeeRepository()
        await repo.setList(
            .success([
                makeCoffee("done", name: "Konga", roastLevel: "light"),
                makeCoffee("queued", status: "PROCESSING", roastLevel: nil, verified: false),
                makeCoffee("broken", status: "FAILED", roastLevel: nil, verified: false),
            ]))
        let model = makeModel(repository: repo)
        await model.load()
        return model
    }

    @Test("Processing and failed rows are pinned above extracted ones")
    func pinnedFirst() async {
        let ids = await mixed().filtered.map(\.photoId)
        #expect(ids.prefix(2).sorted() == ["broken", "queued"])
        #expect(ids.last == "done")
    }

    @Test("A roast filter does not hide in-flight scans")
    func survivesRoastFilter() async {
        let model = await mixed()
        model.roastFilter = "Light"
        let ids = model.filtered.map(\.photoId)
        #expect(ids.contains("queued"))
        #expect(ids.contains("broken"))
        #expect(ids.contains("done"))
    }

    @Test("A search query does not hide in-flight scans")
    func survivesSearch() async {
        let model = await mixed()
        model.query = "konga"
        let ids = model.filtered.map(\.photoId)
        #expect(ids.contains("queued"))
        #expect(ids.contains("done"))
    }
}

@Suite("Catalog mutation from the upload queue")
struct CatalogMutationTests {
    @Test("Upserting an existing coffee replaces it in place")
    func upsertReplaces() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("a", status: "PROCESSING", verified: false)]))
        let model = makeModel(repository: repo)
        await model.load()

        model.upsert(makeCoffee("a", name: "Konga"))

        #expect(model.coffees.count == 1)
        #expect(model.coffees[0].coffeeName == "Konga")
        #expect(model.coffees[0].status == "COMPLETE")
    }

    @Test("Upserting an unknown coffee prepends it as the newest")
    func upsertInserts() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("old")]))
        let model = makeModel(repository: repo)
        await model.load()

        model.upsert(makeCoffee("fresh"))

        #expect(model.coffees.map(\.photoId) == ["fresh", "old"])
    }

    @Test("Marking a status patches only that row")
    func markStatus() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("a", status: "PROCESSING"), makeCoffee("b")]))
        let model = makeModel(repository: repo)
        await model.load()

        model.markStatus(photoId: "a", status: "FAILED", errorMessage: "Too blurry")

        #expect(model.coffees[0].status == "FAILED")
        #expect(model.coffees[0].errorMessage == "Too blurry")
        #expect(model.coffees[1].status == "COMPLETE")
    }

    @Test("Marking an unknown photoId is a no-op, not a crash")
    func markStatusUnknown() async {
        let model = makeModel()
        model.markStatus(photoId: "ghost", status: "FAILED", errorMessage: nil)
        #expect(model.coffees.isEmpty)
    }

    @Test("Deleting removes the row and tells the backend")
    func deleteRemovesRow() async throws {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("a"), makeCoffee("b")]))
        let model = makeModel(repository: repo)
        await model.load()

        try await model.delete(photoId: "a")

        #expect(model.coffees.map(\.photoId) == ["b"])
        #expect(await repo.deletedPhotoIds == ["a"])
    }

    /// The confirmation sheet needs the throw to stay open and show the error,
    /// and the row must survive so the user can retry.
    @Test("A failed delete rethrows and keeps the row")
    func deleteFailureKeepsRow() async {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([makeCoffee("a")]))
        await repo.setDeleteFailing(true)
        let model = makeModel(repository: repo)
        await model.load()

        await #expect(throws: (any Error).self) {
            try await model.delete(photoId: "a")
        }
        #expect(model.coffees.map(\.photoId) == ["a"])
    }

    @Test("Meta line switches to a filtered count while filtering")
    func metaLine() async {
        let repo = StubCoffeeRepository()
        await repo.setList(
            .success([
                makeCoffee("a", country: "Kenya", roastLevel: "light"),
                makeCoffee("b", country: "Kenya", roastLevel: "dark"),
            ]))
        let model = makeModel(repository: repo)
        await model.load()

        #expect(model.metaLine == "2 coffees · 1 origins")
        model.roastFilter = "Light"
        #expect(model.metaLine == "1 of 2 coffees")
    }
}
