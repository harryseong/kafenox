import Foundation

enum CatalogLayout { case grid, list }

@Observable
final class CatalogViewModel {
    var coffees: [Coffee] = []
    var query: String = ""
    var roastFilter: String = "All"
    var layout: CatalogLayout = .list
    var isLoading = false
    var errorMessage: String?

    let roastFilters = ["All", "Light", "Medium", "Dark"]

    /// In-flight and failed scans are pinned to the top and exempt from the
    /// filters: they have no roast level or flavor notes to match on yet, so
    /// filtering them would just make queued uploads vanish.
    var filtered: [Coffee] {
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

    var originCount: Int {
        Set(coffees.compactMap(\.originCountry)).count
    }

    var metaLine: String {
        let isFiltering = !query.isEmpty || roastFilter != "All"
        if isFiltering {
            return "\(filtered.count) of \(coffees.count) coffees"
        }
        return "\(coffees.count) coffees · \(originCount) origins"
    }

    @MainActor
    func load() async {
        #if DEBUG
        if APIConfig.useMockData {
            coffees = Coffee.sampleData
            return
        }
        #endif
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            coffees = try await APIClient.shared.listCoffees()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Applied by UploadQueueMonitor when a queued scan finishes, so the row
    /// swaps from "Processing" to the real coffee without a full reload.
    @MainActor
    func upsert(_ coffee: Coffee) {
        if let index = coffees.firstIndex(where: { $0.photoId == coffee.photoId }) {
            coffees[index] = coffee
        } else {
            coffees.insert(coffee, at: 0)
        }
    }

    @MainActor
    func markStatus(photoId: String, status: String, errorMessage: String?) {
        guard let index = coffees.firstIndex(where: { $0.photoId == photoId }) else { return }
        coffees[index].status = status
        coffees[index].errorMessage = errorMessage
    }

    func toggleLayout() {
        layout = layout == .grid ? .list : .grid
    }
}
