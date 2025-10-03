import Foundation

/// Chats via a managed proxy backend. The proxy handles OpenAI credentials server‑side.
final class ManagedProxyService: ChatService, StreamingChatService {
    struct Config {
        let accessToken: String   // app-issued token (e.g., from OAuth/Sign in with Apple)
        let baseURL: URL          // proxy base URL, e.g., https://api.yourproxy.example
        let model: String
    }

    private let config: Config
    init(config: Config) { self.config = config }

    private func makeRequest(path: String, method: String = "POST", body: [String: Any]) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    func send(messages: [ChatMessage]) async throws -> String {
        let payload: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        let req = try makeRequest(path: "/v1/chat/completions", body: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ManagedProxyService", code: code, userInfo: [NSLocalizedDescriptionKey: "Proxy chat failed", "body": String(data: data, encoding: .utf8) ?? "<no body>"])
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let msg = first["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func stream(messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        let payload: [String: Any] = [
            "model": config.model,
            "stream": true,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        let req = try makeRequest(path: "/v1/chat/completions", body: payload)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                        throw NSError(domain: "ManagedProxyService", code: code, userInfo: [NSLocalizedDescriptionKey: "Proxy stream failed"])
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
