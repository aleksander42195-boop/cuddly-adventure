import Foundation

final class OpenAIChatCompletionsService: ChatService {
    struct Config {
        let apiKey: String
        let model: String    // f.eks. "gpt-4o-mini" eller tilsvarende
        let baseURL: URL?    // valgfritt (proxy)
    }

    private let config: Config
    init(config: Config) { self.config = config }

    func send(messages: [ChatMessage]) async throws -> String {
        let url = (config.baseURL ?? URL(string: "https://api.openai.com")!)
            .appendingPathComponent("/v1/chat/completions")

        let payload: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(domain: "OpenAIChatCompletionsService", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Chat Completions API failed (status: \(code))",
                "body": text
            ])
        }

        // Enkelt parse:
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let msg = first["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension OpenAIChatCompletionsService: StreamingChatService {
    func stream(messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        let url = (config.baseURL ?? URL(string: "https://api.openai.com")!)
            .appendingPathComponent("/v1/chat/completions")

        let payload: [String: Any] = [
            "model": config.model,
            "stream": true,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                        throw NSError(domain: "OpenAIChatCompletionsService", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
                    }
                    for try await line in bytes.lines {
                        let str = String(line)
                        guard str.hasPrefix("data: ") else { continue }
                        let payload = String(str.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = (choices.first?["delta"] as? [String: Any])?["content"] as? String,
                           !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
