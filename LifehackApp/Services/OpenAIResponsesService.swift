import Foundation

final class OpenAIResponsesService: ChatService {
    struct Config {
        let apiKey: String
        let model: String    // e.g. "gpt-4o-mini" or similar
        let baseURL: URL?    // optional (proxy)
    }

    private let config: Config
    init(config: Config) { self.config = config }

    func send(messages: [ChatMessage]) async throws -> String {
        let url = (config.baseURL ?? URL(string: "https://api.openai.com")!)
            .appendingPathComponent("/v1/responses")

        // Responses API expects a single "input"; adjust as needed.
        let input = messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
        let body: [String: Any] = [
            "model": config.model,
            "input": input
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        // Responses API requires beta header as of 2024/2025
        req.setValue("responses=v1", forHTTPHeaderField: "OpenAI-Beta")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "OpenAIResponsesService",
                code: code,
                userInfo: [
                    NSLocalizedDescriptionKey: "Responses API failed (status: \(code))",
                    "body": text
                ]
            )
        }

        // Try to parse output_text (simplified). Some responses include an array here.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let output = json["output_text"] as? String {
                return output
            }
            if let arr = json["output_text"] as? [String], let first = arr.first {
                return first
            }
            // Fallback to output.content[].text shape
            if let outputs = json["output"] as? [[String: Any]],
               let content = (outputs.first?["content"] as? [[String: Any]])?.first,
               let text = content["text"] as? String {
                return text
            }
        }
        // fallback: raw string
        return String(data: data, encoding: .utf8) ?? ""
    }
}
