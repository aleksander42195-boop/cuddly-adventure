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

    let (data, resp) = try await sendWithRetry(req: req)
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
                    let (bytes, resp) = try await bytesWithRetry(req: req)
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

// MARK: - Retry helpers for rate limit
private extension OpenAIChatCompletionsService {
    func sendWithRetry(req: URLRequest, maxAttempts: Int = 3) async throws -> (Data, URLResponse) {
        var attempt = 0
        var lastError: Error?
        var lastRetryAfter: Double? = nil
        while attempt < maxAttempts {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                    let retryAfter = (http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }) ?? pow(2.0, Double(attempt))
                    lastRetryAfter = retryAfter
                    let jitter = Double.random(in: 0...0.333)
                    let delay = max(0.5, retryAfter) + jitter
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                return (data, resp)
            } catch {
                lastError = error
                attempt += 1
            }
        }
        if let ra = lastRetryAfter {
            throw NSError(domain: "OpenAIChatCompletionsService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited (429)", "retryAfter": ra])
        }
        throw lastError ?? NSError(domain: "OpenAIChatCompletionsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed after retries"])
    }

    func bytesWithRetry(req: URLRequest, maxAttempts: Int = 3) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var attempt = 0
        var lastError: Error?
        var lastRetryAfter: Double? = nil
        while attempt < maxAttempts {
            do {
                let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                    let retryAfter = (http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }) ?? pow(2.0, Double(attempt))
                    lastRetryAfter = retryAfter
                    let jitter = Double.random(in: 0...0.333)
                    let delay = max(0.5, retryAfter) + jitter
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                return (bytes, resp)
            } catch {
                lastError = error
                attempt += 1
            }
        }
        if let ra = lastRetryAfter {
            throw NSError(domain: "OpenAIChatCompletionsService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited (429)", "retryAfter": ra])
        }
        throw lastError ?? NSError(domain: "OpenAIChatCompletionsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Streaming request failed after retries"])
    }
}
