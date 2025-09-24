import Foundation

@MainActor
final class CoachVM: ObservableObject {
    private var service: any ChatService
    @Published var reply: String = ""

    init(service: any ChatService) {
        self.service = service
    }

    func updateService(_ newService: any ChatService) {
        self.service = newService
    }

    func ask(_ text: String) async {
        let messages: [ChatMessage] = [
            .system("You are a helpful health and wellness coach."),
            .user(text)
        ]
        do {
            let res = try await service.send(messages: messages)
            reply = res
        } catch {
            reply = "Feil: \(error.localizedDescription)"
        }
    }
}
