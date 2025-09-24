import Foundation
import Security

public struct SimpleMockChatService: ChatService {
    public init() {}
    public func send(messages: [ChatMessage]) async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        let last = messages.last { $0.role == .user }?.content ?? ""
        return "Echo: \(last)"
    }
}
