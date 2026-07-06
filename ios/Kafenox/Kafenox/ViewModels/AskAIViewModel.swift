import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

/// Drives the Insights "Ask AI" chat. Context (the cupping log) lives on the
/// backend -- the client only sends the question plus prior turns.
@MainActor
@Observable
final class AskAIViewModel {
    var messages: [ChatMessage] = []
    var input: String = ""
    var isBusy = false
    var isError = false

    var showsEmptyState: Bool { messages.isEmpty && !isBusy && !isError }

    static let suggestions = [
        "Analyze my coffee preferences",
        "What should I try next if I want something new?",
        "Which origin am I overlooking?",
    ]

    func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isBusy else { return }
        let history = messages.map { (role: $0.role.rawValue, text: $0.text) }
        messages.append(ChatMessage(role: .user, text: question))
        input = ""
        isBusy = true
        isError = false
        Task {
            do {
                let answer = try await APIClient.shared.askInsights(
                    question: question,
                    history: history,
                    model: SettingsStore.shared.model(for: .ask).rawValue
                )
                messages.append(ChatMessage(role: .assistant, text: answer))
            } catch {
                isError = true
            }
            isBusy = false
        }
    }
}
