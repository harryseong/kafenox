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

    var filtered: [Coffee] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return coffees.filter { coffee in
            if roastFilter != "All" && coffee.roastGroup != roastFilter { return false }
            guard !q.isEmpty else { return true }
            let haystack = [
                coffee.roaster, coffee.coffeeName, coffee.originCountry,
                coffee.originRegion,
            ].compactMap { $0 }.joined(separator: " ") + " " + coffee.flavorNotes.joined(separator: " ")
            return haystack.lowercased().contains(q)
        }
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

    func toggleLayout() {
        layout = layout == .grid ? .list : .grid
    }
}
