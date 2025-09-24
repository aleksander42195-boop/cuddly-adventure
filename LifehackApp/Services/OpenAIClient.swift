import Foundation

protocol OpenAIClient {
    func complete(messages: [ChatMessage]) async throws -> ChatMessage
}

struct StubOpenAIClient: OpenAIClient {
    func complete(messages: [ChatMessage]) async throws -> ChatMessage {
        try? await Task.sleep(nanoseconds: 350_000_000)
        let last = messages.last(where: { $0.isUser })?.content ?? ""
        return .assistant("Stub (OpenAI) respons på: \(last.prefix(120))")
    }
}

// TODO: Real implementation (streaming) using URLSession & JSON decoding.
