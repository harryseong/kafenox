import KafenoxCore
import Testing

@testable import KafenoxFeatures

@Suite("Detail actions")
struct DetailViewModelTests {
    private func setUp(
        _ coffee: Coffee
    ) async -> (DetailViewModel, CatalogViewModel, StubCoffeeRepository) {
        let repo = StubCoffeeRepository()
        await repo.setList(.success([coffee]))
        await repo.setCoffee(coffee)
        let catalog = CatalogViewModel(repository: repo, useMockData: false)
        await catalog.load()
        return (DetailViewModel(coffee: coffee, catalog: catalog, repository: repo), catalog, repo)
    }

    @Test("Confirming an unreviewed coffee clears its New state everywhere")
    func verifyPropagatesToCatalog() async {
        let coffee = Coffee(photoId: "a", status: "COMPLETE", coffeeName: "Konga", isVerified: false)
        let (model, catalog, repo) = await setUp(coffee)
        #expect(model.coffee.isNew)

        await model.verify()

        #expect(model.coffee.isVerified)
        #expect(!model.coffee.isNew)
        #expect(catalog.coffees.first?.isVerified == true, "the catalog row must lose its New badge too")
        #expect(await repo.verifiedPhotoIds == ["a"])
        #expect(model.errorMessage == nil)
    }

    @Test("A failed confirm surfaces a message and leaves the coffee unverified")
    func verifyFailure() async {
        let coffee = Coffee(photoId: "missing", status: "COMPLETE", isVerified: false)
        let repo = StubCoffeeRepository()
        let catalog = CatalogViewModel(repository: repo, useMockData: false)
        // The stub has no coffee registered, so verify throws.
        let model = DetailViewModel(coffee: coffee, catalog: catalog, repository: repo)

        await model.verify()

        #expect(!model.coffee.isVerified)
        #expect(model.errorMessage != nil)
    }

    @Test("Deleting removes the coffee from the shared catalog")
    func deleteRemovesFromCatalog() async throws {
        let coffee = Coffee(photoId: "a", status: "COMPLETE")
        let (model, catalog, repo) = await setUp(coffee)

        try await model.delete()

        #expect(catalog.coffees.isEmpty)
        #expect(await repo.deletedPhotoIds == ["a"])
    }

    /// The rating strip fires on every tap, so it must send only the rating --
    /// anything else would flip isVerified server-side as a side effect.
    @Test("Rating a coffee sends only the rating")
    func ratingSendsOnlyRating() async throws {
        let coffee = Coffee(photoId: "a", status: "COMPLETE", isVerified: false)
        let (model, _, repo) = await setUp(coffee)

        model.setRating(7)
        try await waitUntilUpdate(repo)

        let recorded = try #require(await repo.updates.first)
        #expect(recorded.photoId == "a")
        #expect(recorded.update == CoffeeUpdate(rating: 7))
        #expect(recorded.update.payload.keys.sorted() == ["rating"])
    }

    @Test("Confirming sends the verified flag and nothing else")
    func verifySendsOnlyFlag() async {
        #expect(CoffeeUpdate(verified: true).payload.keys.sorted() == ["verified"])
        #expect(!CoffeeUpdate(verified: true).isEmpty)
    }

    @Test("An update with no fields set is empty, and a model alone doesn't count")
    func emptyUpdate() {
        #expect(CoffeeUpdate().isEmpty)
        #expect(CoffeeUpdate(model: "haiku").isEmpty, "a model only qualifies an accompanying edit")
        #expect(!CoffeeUpdate(flavorNotes: ["Peach"], model: "haiku").isEmpty)
    }

    @Test("An edit applied from the edit sheet reaches the catalog row")
    func applyUpdateSyncsCatalog() async {
        let coffee = Coffee(photoId: "a", status: "COMPLETE", coffeeName: "Old")
        let (model, catalog, _) = await setUp(coffee)

        var edited = coffee
        edited.coffeeName = "New"
        model.applyUpdate(edited)

        #expect(catalog.coffees.first?.coffeeName == "New")
    }

    /// `setRating` is synchronous and dispatches its PATCH into a Task.
    private func waitUntilUpdate(_ repo: StubCoffeeRepository) async throws {
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if await !repo.updates.isEmpty { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("No update was recorded")
    }
}
