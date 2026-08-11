import Foundation
import KafenoxCore

/// Hand-written stand-in for the real API client. A plain actor beats a
/// mocking framework here: it is readable, it records calls without extra
/// machinery, and it stops compiling the moment CoffeeRepository changes.
actor StubCoffeeRepository: CoffeeRepository {
    struct Failure: Error {}

    /// Status returned per photoId, consumed one entry at a time so a test
    /// can script "PROCESSING, then COMPLETE".
    private var statusScript: [String: [String]] = [:]
    private var coffees: [String: Coffee] = [:]
    private var listResult: Result<[Coffee], Error> = .success([])
    private var shouldFailStatus = false
    private var shouldFailFetch = false
    private var shouldFailDelete = false

    private(set) var verifiedPhotoIds: [String] = []
    private(set) var deletedPhotoIds: [String] = []
    private(set) var updates: [(photoId: String, update: CoffeeUpdate)] = []
    private(set) var statusPollCount = 0

    /// Recorded Ask AI calls, so tests can assert the history snapshot and
    /// the Settings-selected model actually reach the transport.
    struct Ask: Equatable {
        let question: String
        let history: [ChatTurn]
        let model: String?
    }
    private(set) var asks: [Ask] = []
    private var shouldFailAsk = false
    private var answer = "stub answer"

    func setAsk(answer: String) { self.answer = answer }
    func setAskFailing(_ failing: Bool) { shouldFailAsk = failing }

    init() {}

    // MARK: Scripting

    func setList(_ result: Result<[Coffee], Error>) { listResult = result }
    func setCoffee(_ coffee: Coffee) { coffees[coffee.photoId] = coffee }
    func setStatusScript(_ statuses: [String], for photoId: String) { statusScript[photoId] = statuses }
    func setStatusFailing(_ failing: Bool) { shouldFailStatus = failing }
    func setFetchFailing(_ failing: Bool) { shouldFailFetch = failing }
    func setDeleteFailing(_ failing: Bool) { shouldFailDelete = failing }

    // MARK: CoffeeRepository

    func listCoffees() async throws -> [Coffee] { try listResult.get() }

    func coffee(photoId: String) async throws -> Coffee {
        if shouldFailFetch { throw Failure() }
        guard let coffee = coffees[photoId] else { throw Failure() }
        return coffee
    }

    func updateCoffee(photoId: String, _ update: CoffeeUpdate) async throws -> Coffee {
        updates.append((photoId, update))
        guard var coffee = coffees[photoId] else { throw Failure() }
        if let rating = update.rating { coffee.rating = rating }
        if let roaster = update.roaster { coffee.roaster = roaster }
        if let name = update.coffeeName { coffee.coffeeName = name }
        if let notes = update.flavorNotes { coffee.flavorNotes = notes }
        // Mirrors the backend: any edit other than a bare rating verifies.
        if update.payload.keys.contains(where: { $0 != "rating" && $0 != "model" }) {
            coffee.isVerified = true
        }
        coffees[photoId] = coffee
        return coffee
    }

    func verifyCoffee(photoId: String) async throws -> Coffee {
        verifiedPhotoIds.append(photoId)
        guard var coffee = coffees[photoId] else { throw Failure() }
        coffee.isVerified = true
        coffees[photoId] = coffee
        return coffee
    }

    func deleteCoffee(photoId: String) async throws {
        if shouldFailDelete { throw Failure() }
        deletedPhotoIds.append(photoId)
        coffees[photoId] = nil
    }

    func initiateUpload(models: [String: String]) async throws -> UploadTicket {
        UploadTicket(photoId: "stub-photo", uploadUrl: URL(string: "https://example.invalid/upload")!)
    }

    func uploadPhoto(_ imageData: Data, to uploadUrl: URL) async throws {}

    func uploadStatus(photoId: String) async throws -> UploadStatus {
        statusPollCount += 1
        if shouldFailStatus { throw Failure() }
        // Hold on the last scripted value once the script runs out.
        var scripted = statusScript[photoId] ?? ["PENDING"]
        let next = scripted.count > 1 ? scripted.removeFirst() : (scripted.first ?? "PENDING")
        statusScript[photoId] = scripted
        return UploadStatus(photoId: photoId, status: next, errorMessage: next == "FAILED" ? "Too blurry" : nil)
    }

    func askInsights(question: String, history: [ChatTurn], model: String?) async throws -> String {
        asks.append(Ask(question: question, history: history, model: model))
        if shouldFailAsk { throw Failure() }
        return answer
    }
}
