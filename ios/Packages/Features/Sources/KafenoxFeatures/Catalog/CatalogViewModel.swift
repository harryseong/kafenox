import Foundation
import KafenoxCore
import KafenoxNetworking
import OSLog

public enum CatalogLayout: Sendable { case grid, list }

/// The app's single source of truth for the coffee collection. Detail,
/// Insights, and the upload queue all read and mutate this same instance
/// rather than holding their own copies, so a rating change or a finished
/// scan shows up everywhere at once.
@Observable
public final class CatalogViewModel {
    public var coffees: [Coffee] = []
    public var query: String = ""
    public var roastFilter: String = "All"
    public var layout: CatalogLayout = .list
    public var isLoading = false
    public var errorMessage: String?

    public let roastFilters = ["All", "Light", "Medium", "Dark"]

    private let repository: any CoffeeRepository
    private let useMockData: Bool

    /// `repository` is injected so tests can supply a stub; production wiring
    /// happens once in the app's composition root.
    public init(repository: any CoffeeRepository = APIClient.shared, useMockData: Bool = APIConfig.useMockData) {
        self.repository = repository
        self.useMockData = useMockData
    }

    /// In-flight and failed scans are pinned to the top and exempt from the
    /// filters: they have no roast level or flavor notes to match on yet, so
    /// filtering them would just make queued uploads vanish.
    public var filtered: [Coffee] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inFlight = coffees.filter { !$0.isCompleteExtraction }
        let extracted = coffees.filter(\.isCompleteExtraction).filter { coffee in
            if roastFilter != "All" && coffee.roastGroup != roastFilter { return false }
            guard !q.isEmpty else { return true }
            let haystack = [
                coffee.roaster, coffee.coffeeName, coffee.originCountry,
                coffee.originRegion,
            ].compactMap { $0 }.joined(separator: " ") + " " + coffee.flavorNotes.joined(separator: " ")
            return haystack.lowercased().contains(q)
        }
        return inFlight + extracted
    }

    public var originCount: Int {
        Set(coffees.compactMap(\.originCountry)).count
    }

    public var metaLine: String {
        let isFiltering = !query.isEmpty || roastFilter != "All"
        if isFiltering {
            return "\(filtered.count) of \(coffees.count) coffees"
        }
        return "\(coffees.count) coffees · \(originCount) origins"
    }

    @MainActor
    public func load() async {
        #if DEBUG
        if useMockData {
            coffees = Coffee.sampleData
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            coffees = try await repository.listCoffees()
        } catch {
            Logger.catalog.error("Loading catalog failed: \(error)")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your collection."
        }
    }

    /// Applied by UploadQueueMonitor when a queued scan finishes, so the row
    /// swaps from "Processing" to the real coffee without a full reload.
    @MainActor
    public func upsert(_ coffee: Coffee) {
        if let index = coffees.firstIndex(where: { $0.photoId == coffee.photoId }) {
            coffees[index] = coffee
        } else {
            coffees.insert(coffee, at: 0)
        }
    }

    @MainActor
    public func markStatus(photoId: String, status: String, errorMessage: String?) {
        guard let index = coffees.firstIndex(where: { $0.photoId == photoId }) else { return }
        coffees[index].status = status
        coffees[index].errorMessage = errorMessage
    }

    @MainActor
    public func remove(photoId: String) {
        coffees.removeAll { $0.photoId == photoId }
    }

    public func toggleLayout() {
        layout = layout == .grid ? .list : .grid
    }
}
