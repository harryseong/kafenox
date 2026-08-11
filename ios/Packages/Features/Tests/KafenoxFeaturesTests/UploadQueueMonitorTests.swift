import KafenoxCore
import Testing

@testable import KafenoxFeatures

/// The monitor polls on a 4s interval, so these drive its transitions
/// through the catalog it patches rather than waiting on wall-clock ticks.
@Suite("Upload queue tracking")
struct UploadQueueMonitorTests {
    private func monitor(
        _ repo: StubCoffeeRepository
    ) -> (UploadQueueMonitor, CatalogViewModel, SpyUploadQueueServices) {
        let catalog = CatalogViewModel(repository: repo, useMockData: false)
        let system = SpyUploadQueueServices()
        let monitor = UploadQueueMonitor(repository: repo, system: system)
        monitor.attach(catalog: catalog)
        return (monitor, catalog, system)
    }

    @Test("Resuming adopts only the coffees still extracting")
    func resumeAdoptsInFlight() {
        let repo = StubCoffeeRepository()
        let (monitor, _, _) = monitor(repo)

        monitor.resume(from: [
            Coffee(photoId: "queued", status: "PENDING"),
            Coffee(photoId: "running", status: "PROCESSING"),
            Coffee(photoId: "done", status: "COMPLETE"),
            Coffee(photoId: "broken", status: "FAILED"),
        ])

        #expect(monitor.trackedPhotoIds == ["queued", "running"])
    }

    @Test("Resuming with nothing in flight starts no polling")
    func resumeNoop() {
        let repo = StubCoffeeRepository()
        let (monitor, _, _) = monitor(repo)

        monitor.resume(from: [Coffee(photoId: "done", status: "COMPLETE")])

        #expect(monitor.trackedPhotoIds.isEmpty)
    }

    @Test("Resuming twice does not double-track the same photo")
    func resumeIsIdempotent() {
        let repo = StubCoffeeRepository()
        let (monitor, _, _) = monitor(repo)
        let inFlight = [Coffee(photoId: "queued", status: "PENDING")]

        monitor.resume(from: inFlight)
        monitor.resume(from: inFlight)

        #expect(monitor.trackedPhotoIds.count == 1)
    }

    @Test("A completed scan stops being tracked and lands in the catalog")
    func completionUpdatesCatalog() async throws {
        let repo = StubCoffeeRepository()
        await repo.setStatusScript(["COMPLETE"], for: "queued")
        await repo.setCoffee(Coffee(photoId: "queued", status: "COMPLETE", coffeeName: "Konga"))
        let (monitor, catalog, system) = monitor(repo)

        monitor.resume(from: [Coffee(photoId: "queued", status: "PENDING")])
        try await waitUntil { !catalog.coffees.isEmpty }

        #expect(monitor.trackedPhotoIds.isEmpty)
        #expect(catalog.coffees.map(\.photoId) == ["queued"])
        #expect(catalog.coffees.first?.coffeeName == "Konga")
        #expect(
            system.posted == [
                .init(title: "Scan ready", body: "Konga is ready to review.", photoId: "queued")
            ])
    }

    @Test("A failed scan stops being tracked and the row is marked failed")
    func failureMarksCatalog() async throws {
        let repo = StubCoffeeRepository()
        await repo.setStatusScript(["FAILED"], for: "queued")
        let (monitor, catalog, system) = monitor(repo)
        catalog.upsert(Coffee(photoId: "queued", status: "PENDING"))

        monitor.resume(from: catalog.coffees)
        try await waitUntil { catalog.coffees.first?.status == "FAILED" }

        #expect(monitor.trackedPhotoIds.isEmpty)
        #expect(catalog.coffees.first?.errorMessage == "Too blurry")
        #expect(system.posted.first?.title == "Scan failed")
    }

    /// If the completed item can't be fetched, the row must still leave the
    /// "Processing" state -- otherwise it spins forever.
    @Test("An unfetchable completion still clears the processing spinner")
    func completionWithFailedFetch() async throws {
        let repo = StubCoffeeRepository()
        await repo.setStatusScript(["COMPLETE"], for: "queued")
        await repo.setFetchFailing(true)
        let (monitor, catalog, system) = monitor(repo)
        catalog.upsert(Coffee(photoId: "queued", status: "PENDING"))

        monitor.resume(from: catalog.coffees)
        try await waitUntil { catalog.coffees.first?.status == "COMPLETE" }

        #expect(monitor.trackedPhotoIds.isEmpty)
    }

    @Test("Queueing a scan asks for notification permission and holds a background task")
    func trackOpensBackgroundWindow() async throws {
        let repo = StubCoffeeRepository()
        await repo.setStatusScript(["COMPLETE"], for: "queued")
        await repo.setCoffee(Coffee(photoId: "queued", status: "COMPLETE"))
        let (monitor, _, system) = monitor(repo)

        monitor.track(photoId: "queued")
        #expect(system.authorizationRequests == 1)
        #expect(system.backgroundTasksBegun == 1)

        // The window is released once nothing is left to watch.
        try await waitUntil { system.backgroundTasksEnded == 1 }
    }

    @Test("A transient status failure is retried rather than dropping the scan")
    func transientFailureKeepsTracking() async throws {
        let repo = StubCoffeeRepository()
        await repo.setStatusFailing(true)
        await repo.setStatusScript(["COMPLETE"], for: "queued")
        await repo.setCoffee(Coffee(photoId: "queued", status: "COMPLETE"))
        let (monitor, catalog, _) = monitor(repo)

        monitor.track(photoId: "queued")
        try await waitUntil { await repo.statusPollCount >= 1 }
        #expect(monitor.trackedPhotoIds == ["queued"], "a failed poll must not abandon the scan")

        await repo.setStatusFailing(false)
        try await waitUntil { monitor.trackedPhotoIds.isEmpty && !catalog.coffees.isEmpty }
    }
}

/// Polls a condition on the main actor until it holds or the budget expires.
/// Cheaper and less flaky than sleeping for the monitor's full interval.
@MainActor
private func waitUntil(
    timeout: Duration = .seconds(15),
    _ condition: () async -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("Condition never became true within \(timeout)", sourceLocation: sourceLocation)
}
