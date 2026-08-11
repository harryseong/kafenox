import Foundation
import KafenoxCore
import Testing

@testable import KafenoxFeatures

/// `send` is synchronous and spawns a Task, so these wait on the observable
/// result rather than awaiting the call itself.
@Suite("Ask AI")
struct AskAIViewModelTests {
    private func makeModel(
        _ repo: StubCoffeeRepository,
        settings: SettingsStore? = nil
    ) -> AskAIViewModel {
        AskAIViewModel(repository: repo, settings: settings ?? Self.isolatedSettings())
    }

    /// A throwaway defaults suite per store, so these never read or write the
    /// user's real model preferences.
    static func isolatedSettings() -> SettingsStore {
        let suite = UserDefaults(suiteName: "kafenox.tests.\(UUID().uuidString)")!
        return SettingsStore(defaults: suite)
    }

    @Test("A question and its answer both land in the thread")
    func roundTrip() async throws {
        let repo = StubCoffeeRepository()
        await repo.setAsk(answer: "Try a natural Ethiopian.")
        let model = makeModel(repo)

        model.send("What next?")
        try await waitUntil { model.messages.count == 2 }

        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages[0].text == "What next?")
        #expect(model.messages[1].text == "Try a natural Ethiopian.")
        #expect(!model.isBusy)
        #expect(!model.isError)
    }

    @Test("Sending clears the composer immediately")
    func clearsInput() async throws {
        let repo = StubCoffeeRepository()
        let model = makeModel(repo)
        model.input = "What next?"

        model.send(model.input)

        #expect(model.input.isEmpty)
        try await waitUntil { !model.isBusy }
    }

    @Test("Blank input is ignored rather than sent", arguments: ["", "   ", "\n"])
    func ignoresBlankInput(_ text: String) async {
        let repo = StubCoffeeRepository()
        let model = makeModel(repo)

        model.send(text)

        #expect(model.messages.isEmpty)
        #expect(!model.isBusy)
        #expect(await repo.asks.isEmpty)
    }

    @Test("The question is trimmed before it is sent")
    func trimsQuestion() async throws {
        let repo = StubCoffeeRepository()
        let model = makeModel(repo)

        model.send("  What next?  ")
        try await waitUntil { !model.isBusy }

        #expect(await repo.asks.first?.question == "What next?")
    }

    /// The backend needs the prior turns, not the turn being asked -- sending
    /// the new question inside its own history would duplicate it.
    @Test("History carries prior turns only, not the new question")
    func historyExcludesCurrentQuestion() async throws {
        let repo = StubCoffeeRepository()
        await repo.setAsk(answer: "First answer.")
        let model = makeModel(repo)

        model.send("First?")
        try await waitUntil { model.messages.count == 2 }
        model.send("Second?")
        try await waitUntil { model.messages.count == 4 }

        let asks = await repo.asks
        #expect(asks[0].history.isEmpty)
        #expect(
            asks[1].history == [
                ChatTurn(role: "user", text: "First?"),
                ChatTurn(role: "assistant", text: "First answer."),
            ])
        #expect(asks[1].question == "Second?")
    }

    @Test("A failure flags the error and adds no assistant message")
    func failureSurfaces() async throws {
        let repo = StubCoffeeRepository()
        await repo.setAskFailing(true)
        let model = makeModel(repo)

        model.send("What next?")
        try await waitUntil { !model.isBusy }

        #expect(model.isError)
        #expect(model.messages.map(\.role) == [.user], "the question stays; no reply is invented")
    }

    @Test("A later success clears a previous error")
    func recoversFromError() async throws {
        let repo = StubCoffeeRepository()
        await repo.setAskFailing(true)
        let model = makeModel(repo)
        model.send("First?")
        try await waitUntil { model.isError }

        await repo.setAskFailing(false)
        model.send("Second?")
        try await waitUntil { !model.isBusy && !model.isError }

        #expect(!model.isError)
    }

    @Test("A second send while one is in flight is dropped")
    func busyGatesReentrancy() async throws {
        let repo = StubCoffeeRepository()
        let model = makeModel(repo)

        model.send("First?")
        model.send("Second?")  // isBusy is already true
        try await waitUntil { !model.isBusy }

        #expect(await repo.asks.map(\.question) == ["First?"])
    }

    @Test("The Settings-selected model is passed through")
    func usesSelectedModel() async throws {
        let repo = StubCoffeeRepository()
        let settings = Self.isolatedSettings()
        settings.setModel(.haiku, for: .ask)
        let model = makeModel(repo, settings: settings)

        model.send("What next?")
        try await waitUntil { !model.isBusy }

        #expect(await repo.asks.first?.model == ModelChoice.haiku.rawValue)
    }

    @Test("The empty state shows only before anything has happened")
    func emptyState() async throws {
        let repo = StubCoffeeRepository()
        let model = makeModel(repo)
        #expect(model.showsEmptyState)

        model.send("What next?")
        #expect(!model.showsEmptyState, "hidden while a request is in flight")

        try await waitUntil { !model.isBusy }
        #expect(!model.showsEmptyState)
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(10),
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
