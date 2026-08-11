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

    @Test("An edit applied from the edit sheet reaches the catalog row")
    func applyUpdateSyncsCatalog() async {
        let coffee = Coffee(photoId: "a", status: "COMPLETE", coffeeName: "Old")
        let (model, catalog, _) = await setUp(coffee)

        var edited = coffee
        edited.coffeeName = "New"
        model.applyUpdate(edited)

        #expect(catalog.coffees.first?.coffeeName == "New")
    }
}
