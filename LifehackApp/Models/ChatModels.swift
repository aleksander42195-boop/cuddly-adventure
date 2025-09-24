import Foundation

public struct ChatMessage: Codable, Sendable, Identifiable {
    public enum Role: String, Codable { case system, user, assistant }
    public var id: UUID
    public var role: Role
    public var content: String
    public init(role: Role, content: String) { self.id = UUID(); self.role = role; self.content = content }
    public init(_ role: Role, _ content: String) { self.id = UUID(); self.role = role; self.content = content }
    public var text: String { content }
}

public protocol ChatService {
    func send(messages: [ChatMessage]) async throws -> String
}

public protocol StreamingChatService {
    func stream(messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error>
}

public extension ChatMessage {
    static func user(_ text: String) -> ChatMessage { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, content: text) }
    static func system(_ text: String) -> ChatMessage { .init(role: .system, content: text) }
}
