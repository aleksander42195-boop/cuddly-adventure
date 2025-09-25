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
                return .assistant("Ugyldig serversvar.")
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

enum OpenAIAPIMode { ChatService {
    var model: String = "gpt-4o-mini"
    var temperature: Double = 0.7
    var endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!
    var session: URLSession = .shared

    func send(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = APIKeyResolver.apiKey(), !apiKey.isEmpty else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mangler OpenAI API‑nøkkel. Lagre den i Settings → Coach API."])
        }

        // Build input items (system + conversation)
        var items: [RInputItem] = [
            .init(role: "system",
                  content: [.init(type: "input_text",
                                  text: "Du er en vennlig, konkret coach for helse, HRV og produktivitet. Svar kort på norsk og gi ett neste steg.")])
        ]
        items += messages.map { msg in
            .init(role: msg.role.rawValue,
                  content: [.init(type: "input_text", text: msg.content)])
        }

        let body = RRequest(model: model, input: items, temperature: temperature)
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
                throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI (responses) feil \(http.statusCode): \(txt.prefix(160))"])
            }
            let decoded = try JSONDecoder().decode(RResponse.self, from: data)
            if let text = decoded.output_text?.joined().trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            if let out = decoded.output {
                let combined = out.compactMap { $0.content?.compactMap { $0.text }.joined() }.joined()
                if !combined.isEmpty {
                    return combined.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return "Tomt svar (responses). Prøv igjen."
        } catch {
            throw error
        }
    }

    // DTOs
    private struct RInputItem: Codable {
        let role: String          // "system" | "user" | "assistant"
        let content: [RContent]   // array of content blocks
    }
    private struct RContent: Codable {
        let type: String          // "input_text"
        let text: String
    }
    private struct RRequest: Codable {
        let model: String
        let input: [RInputItem]
        let temperature: Double
    }
    private struct RResponse: Codable {
        struct OutputItem: Codable {
            struct OutputContent: Codable { let type: String; let text: String? }
            let id: String?
            let type: String?
            let content: [OutputContent]?
        }
        let id: String
        let model: String
        let output: [OutputItem]?
        let output_text: [String]?
    }
}

// MARK: - Optional adaptive wrapper (choose API style)

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
            return try await OpenAIResponsesService(model: model, temperature: temperature).send(messages: messages)
        }
    }
}
