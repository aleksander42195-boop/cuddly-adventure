import Foundation

// Shared key resolver (Keychain → Secrets.plist)
private enum APIKeyResolver {
    static func apiKey() -> String? {
        Secrets.shared.openAIAPIKey
    }
}

// MARK: - Chat Completions (existing service refactored to use resolver)

struct OpenAIChatService: ChatService {
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0.7
    var endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    var session: URLSession = .shared

    func send(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = APIKeyResolver.apiKey(), !apiKey.isEmpty else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mangler OpenAI API‑nøkkel. Gå til Settings → Coach API og lagre nøkkelen."])
        }

        // System prompt (concise Norwegian coaching tone)
        var apiMessages: [APIMessage] = [
            .init(role: "system", content:
"""
Du er en vennlig, konkret coach for helse, HRV, struktur og appbygging.
Svar kort, på norsk, og gi ett konkret neste steg.
""")
        ]
        apiMessages += messages.map { .init(role: $0.role.rawValue, content: $0.content) }

        let body = ChatRequest(model: model, messages: apiMessages, temperature: temperature)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        do {
            req.httpBody = try JSONEncoder().encode(body)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ugyldig serversvar."])
            }
            guard (200..<300).contains(http.statusCode) else {
                let txt = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI-feil \(http.statusCode): \(txt.prefix(160))"])
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            if let first = decoded.choices.first?.message.content, !first.isEmpty {
                return first.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return "Tomt svar – prøv igjen med mer kontekst."
        } catch {
            throw error
        }
    }

    // MARK: - API models

    private struct APIMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let model: String
        let messages: [APIMessage]
        let temperature: Double
    }

    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let role: String; let content: String }
            let index: Int
            let message: Message
        }
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
    }
}

// MARK: - Adaptive service using existing implementations

enum OpenAIAPIMode {
    case chatCompletions
    case responses
}

struct OpenAIAdaptiveService: ChatService {
    var mode: OpenAIAPIMode = .chatCompletions
    var temperature: Double = 0.7
    var model: String = "gpt-4o-mini"

    func send(messages: [ChatMessage]) async throws -> String {
        switch mode {
        case .chatCompletions:
            return try await OpenAIChatService(model: model, temperature: temperature).send(messages: messages)
        case .responses:
            let config = OpenAIResponsesService.Config(
                apiKey: APIKeyResolver.apiKey() ?? "",
                model: model,
                baseURL: nil
            )
            return try await OpenAIResponsesService(config: config).send(messages: messages)
        }
    }
}