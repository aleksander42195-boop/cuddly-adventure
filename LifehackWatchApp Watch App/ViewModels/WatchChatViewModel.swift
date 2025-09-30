import Foundation
import SwiftUI
import Combine

@MainActor
final class WatchChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        .init(role: .system, content: "Du chatter nå på klokka. Si hei!")
    ]
    @Published var draft: String = ""
    @Published var isSending = false
    @Published var lastError: String?

    private let engine: ChatEngine

    init(engine: ChatEngine) {
        self.engine = engine
    }

    // NY: Send direkte med tekst (brukes av diktering)
    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(.init(.user, trimmed))
        isSending = true
        lastError = nil

        Task {
            do {
                let reply = try await engine.send(userText: trimmed)
                messages.append(.init(.assistant, reply))
            } catch {
                lastError = error.localizedDescription
                messages.append(.init(.assistant, "⚠️ Feil: \(error.localizedDescription)"))
            }
            isSending = false
        }
    }

    // Eksisterende: bruker draft
    func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        send(text: trimmed)
    }
}
