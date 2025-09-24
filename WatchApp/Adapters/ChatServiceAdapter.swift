import Foundation

/// Liten protokoll så UI ikke er avhengig av en spesifikk implementasjon.
protocol ChatEngine {
    func send(userText: String) async throws -> String
}

final class ChatServiceAdapter: ChatEngine, ChatServiceProvider {
    func makeService() -> any ChatService {
        let store = AppGroup.defaults
        let raw = store.string(forKey: SharedKeys.coachEngineSelection) ?? CoachEngine.openAIResponses.rawValue
        let engine = CoachEngine(rawValue: raw) ?? .openAIResponses
        let baseURL = URL(string: store.string(forKey: SharedKeys.coachBaseURL) ?? "")
        let responsesModel = store.string(forKey: SharedKeys.coachResponsesModel) ?? "gpt-4o-mini"
        let chatModel = store.string(forKey: SharedKeys.coachChatModel) ?? "gpt-4o-mini"

        switch engine {
        case .offlineHeuristics:
            return OfflineHeuristicsService()
        case .openAIResponses:
            if let key = Secrets.shared.openAIAPIKey {
                return OpenAIResponsesService(config: .init(apiKey: key, model: responsesModel, baseURL: baseURL))
            }
            return SimpleMockChatService()
        case .openAIChatCompletions:
            if let key = Secrets.shared.openAIAPIKey {
                return OpenAIChatCompletionsService(config: .init(apiKey: key, model: chatModel, baseURL: baseURL))
            }
            return SimpleMockChatService()
        }
    }

    func send(userText: String) async throws -> String {
        let service = makeService()
        let messages: [ChatMessage] = [
            .system("Du er Lifehack Coach – kort, vennlig, konkret."),
            .user(userText)
        ]
        return try await service.send(messages: messages)
    }
}
