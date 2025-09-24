import Foundation
import SwiftUI

@MainActor
final class CoachEngineManager: ObservableObject {
    private let store = AppGroup.defaults
    @Published var engine: CoachEngine {
        didSet { store.set(engine.rawValue, forKey: SharedKeys.coachEngineSelection) }
    }

    @Published var baseURLString: String {
        didSet { store.set(baseURLString, forKey: SharedKeys.coachBaseURL) }
    }

    @Published var responsesModel: String {
        didSet { store.set(responsesModel, forKey: SharedKeys.coachResponsesModel) }
    }

    @Published var chatModel: String {
        didSet { store.set(chatModel, forKey: SharedKeys.coachChatModel) }
    }

    @Published var wristTipsEnabled: Bool {
        didSet { store.set(wristTipsEnabled, forKey: SharedKeys.coachWristTipsEnabled) }
    }

    var baseURL: URL? { URL(string: baseURLString) }

    private enum Keys {}

    init() {
        let raw = store.string(forKey: SharedKeys.coachEngineSelection) ?? CoachEngine.openAIResponses.rawValue
        self.engine = CoachEngine(rawValue: raw) ?? .openAIResponses
        self.baseURLString = store.string(forKey: SharedKeys.coachBaseURL) ?? ""
        self.responsesModel = store.string(forKey: SharedKeys.coachResponsesModel) ?? "gpt-4o-mini"
        self.chatModel = store.string(forKey: SharedKeys.coachChatModel) ?? "gpt-4o-mini"
        self.wristTipsEnabled = store.bool(forKey: SharedKeys.coachWristTipsEnabled)
    }

    /// Build an appropriate ChatService for the current engine configuration.
    func makeService() -> any ChatService {
        switch engine {
        case .offlineHeuristics:
            return OfflineHeuristicsService()
        case .openAIResponses:
            if let key = Secrets.shared.openAIAPIKey {
                return OpenAIResponsesService(
                    config: .init(apiKey: key, model: responsesModel, baseURL: baseURL)
                )
            }
            return SimpleMockChatService()
        case .openAIChatCompletions:
            if let key = Secrets.shared.openAIAPIKey {
                return OpenAIChatCompletionsService(
                    config: .init(apiKey: key, model: chatModel, baseURL: baseURL)
                )
            }
            return SimpleMockChatService()
        }
    }
}
