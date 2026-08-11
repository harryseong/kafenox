import Foundation
import KafenoxCore
import KafenoxNetworking
import OSLog

@Observable
public final class DetailViewModel {
    public var coffee: Coffee
    public var errorMessage: String?
    private let catalog: CatalogViewModel
    private let repository: any CoffeeRepository

    public init(coffee: Coffee, catalog: CatalogViewModel, repository: any CoffeeRepository = APIClient.shared) {
        self.coffee = coffee
        self.catalog = catalog
        self.repository = repository
    }

    @MainActor
    public func setRating(_ n: Int) {
        let previous = coffee.rating
        coffee.rating = n
        syncCatalog()
        Task {
            do {
                let updated = try await repository.updateCoffee(photoId: coffee.photoId, CoffeeUpdate(rating: n))
                coffee = updated
                syncCatalog()
            } catch {
                Logger.catalog.error("Saving rating failed: \(error)")
                coffee.rating = previous
                syncCatalog()
                errorMessage = "Couldn't save rating — try again."
            }
        }
    }

    /// Called by EditCoffeeView after a successful PATCH.
    @MainActor
    public func applyUpdate(_ updated: Coffee) {
        coffee = updated
        syncCatalog()
    }

    /// "Looks good" -- clears the New badge for an extraction the user is
    /// happy with as-is. Editing any field already does this server-side.
    @MainActor
    public func verify() async {
        errorMessage = nil
        do {
            applyUpdate(try await repository.verifyCoffee(photoId: coffee.photoId))
        } catch {
            Logger.catalog.error("Verifying coffee failed: \(error)")
            errorMessage = "Couldn't confirm — try again."
        }
    }

    @MainActor
    public func delete() async throws {
        try await repository.deleteCoffee(photoId: coffee.photoId)
        catalog.remove(photoId: coffee.photoId)
    }

    private func syncCatalog() {
        guard let index = catalog.coffees.firstIndex(where: { $0.photoId == coffee.photoId }) else { return }
        catalog.coffees[index] = coffee
    }
}
