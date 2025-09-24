import Foundation

final class OfflineHeuristicsService: ChatService {
    func send(messages: [ChatMessage]) async throws -> String {
        // Minimal lokal coach – kan senere kobles mot dine egne regler/HRV-logikk.
        let lastUser = messages.last { $0.role == .user }?.content ?? ""
        if lastUser.lowercased().contains("stress") {
            return "Pust i 4–6 mønster i 2 min, så 5 min rolig gange. Logg følelsen etterpå."
        }
        return "Jeg er offline nå, men kan foreslå: 10 min lett mobilitet + 10 min fokusblokk. Vil du ha en konkret mini-plan?"
    }
}
