import KafenoxCore
import KafenoxNetworking
import OSLog
import SwiftUI

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public let id = UUID()
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// Drives the Insights "Ask AI" chat. Context (the cupping log) lives on the
/// backend -- the client only sends the question plus prior turns.
@MainActor
@Observable
public final class AskAIViewModel {
    public var messages: [ChatMessage] = []
    public var input: String = ""
    public var isBusy = false
    public var isError = false

    private let repository: any CoffeeRepository
    private let settings: SettingsStore

    public init(
        repository: any CoffeeRepository = APIClient.shared,
        settings: SettingsStore = .shared
    ) {
        self.repository = repository
        self.settings = settings
    }

    public var showsEmptyState: Bool { messages.isEmpty && !isBusy && !isError }

    public static let suggestions = [
        "Analyze my coffee preferences",
        "What should I try next if I want something new?",
        "Which origin am I overlooking?",
    ]

    public func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isBusy else { return }
        let history = messages.map { ChatTurn(role: $0.role.rawValue, text: $0.text) }
        messages.append(ChatMessage(role: .user, text: question))
        input = ""
        isBusy = true
        isError = false
        Task {
            do {
                let answer = try await repository.askInsights(
                    question: question,
                    history: history,
                    model: settings.model(for: .ask).rawValue
                )
                messages.append(ChatMessage(role: .assistant, text: answer))
            } catch {
                Logger.insights.error("Ask AI request failed: \(error)")
                isError = true
            }
            isBusy = false
        }
    }
}
