import Foundation

public enum CoachEngine: String, CaseIterable, Identifiable, Codable {
    case openAIResponses = "OpenAI Responses"
    case openAIChatCompletions = "OpenAI Chat Completions"
    case offlineHeuristics = "Offline Heuristics"

    public var id: String { rawValue }

    var description: String {
        switch self {
        case .openAIResponses: return "Nyeste Responses API (streaming, tools, stateful)."
        case .openAIChatCompletions: return "Klassisk Chat Completions."
        case .offlineHeuristics: return "Lokal fallback (enkle regler, ingen API)."
        }
    }
}
