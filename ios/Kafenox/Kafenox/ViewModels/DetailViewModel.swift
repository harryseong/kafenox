import Foundation

@Observable
final class DetailViewModel {
    var coffee: Coffee
    var errorMessage: String?
    private let catalog: CatalogViewModel

    init(coffee: Coffee, catalog: CatalogViewModel) {
        self.coffee = coffee
        self.catalog = catalog
    }

    @MainActor
    func setRating(_ n: Int) {
        let previous = coffee.rating
        coffee.rating = n
        syncCatalog()
        Task {
            do {
                let updated = try await APIClient.shared.updateCoffee(photoId: coffee.photoId, fields: ["rating": n])
                coffee = updated
                syncCatalog()
            } catch {
                coffee.rating = previous
                syncCatalog()
                errorMessage = "Couldn't save rating — try again."
            }
        }
    }

    /// Called by EditCoffeeView after a successful PATCH.
    @MainActor
    func applyUpdate(_ updated: Coffee) {
        coffee = updated
        syncCatalog()
    }

    @MainActor
    func delete() async throws {
        try await APIClient.shared.deleteCoffee(photoId: coffee.photoId)
        catalog.coffees.removeAll { $0.photoId == coffee.photoId }
    }

    private func syncCatalog() {
        guard let index = catalog.coffees.firstIndex(where: { $0.photoId == coffee.photoId }) else { return }
        catalog.coffees[index] = coffee
    }
}
