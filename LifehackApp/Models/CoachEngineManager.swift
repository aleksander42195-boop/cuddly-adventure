import Foundation
import SwiftUI
import UIKit

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
        
        // Setup automatic state saving when app backgrounded
        setupBackgroundSaving()
    }
    
    private func setupBackgroundSaving() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveState()
            }
        }
    }
    
    private func saveState() {
        // Force synchronize all settings to ensure they're persisted
        store.synchronize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Build an appropriate ChatService for the current engine configuration.
    func makeService() -> any ChatService {
        switch engine {
        case .offlineHeuristics:
            return OfflineHeuristicsService()
        case .managedProxy:
            if let token = Secrets.shared.proxyAccessToken, let base = Secrets.shared.proxyBaseURL {
                return ManagedProxyService(config: .init(accessToken: token, baseURL: base, model: chatModel))
            }
            return SimpleMockChatService()
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
