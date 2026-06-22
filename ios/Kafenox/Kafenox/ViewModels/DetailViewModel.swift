import Foundation

@Observable
final class DetailViewModel {
    var coffee: Coffee
    var errorMessage: String?

    init(coffee: Coffee) {
        self.coffee = coffee
    }

    @MainActor
    func setRating(_ n: Int) {
        let previous = coffee.rating
        coffee.rating = n
        Task {
            do {
                _ = try await APIClient.shared.updateCoffee(photoId: coffee.photoId, fields: ["rating": n])
            } catch {
                coffee.rating = previous
                errorMessage = "Couldn't save rating — try again."
            }
        }
    }
}
