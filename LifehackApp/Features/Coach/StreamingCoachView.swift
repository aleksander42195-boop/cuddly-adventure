import SwiftUI

struct StreamingCoachView: View {
    @EnvironmentObject var engineManager: CoachEngineManager
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var tokenEstimate: Int = 0
    @State private var isStreaming = false

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                Text(output)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            HStack {
                TextField("Skriv til coach …", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button(isStreaming ? "Stop" : "Send") {
                    if isStreaming { isStreaming = false; return }
                    Task { await ask() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming)
            }
            HStack {
                Text("≈ \(tokenEstimate) tokens")
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Streaming Coach")
    }

    func ask() async {
        output = ""
        tokenEstimate = 0
        isStreaming = true
        let service = engineManager.makeService()
        if let streamer = service as? StreamingChatService {
            do {
                let stream = try await streamer.stream(messages: [
                    .init(role: .system, content: "Du er Lifehack Coach – kort, vennlig, konkret."),
                    .init(role: .user, content: input)
                ])
                for try await delta in stream {
                    guard isStreaming else { break }
                    output += delta
                    tokenEstimate = TokenCounter.estimateTokens(output)
                }
            } catch {
                output = "Feil: \(error.localizedDescription)"
            }
        } else {
            // fallback: ikke-streamende service
            do {
                let text = try await service.send(messages: [
                    .init(role: .system, content: "Du er Lifehack Coach – kort, vennlig, konkret."),
                    .init(role: .user, content: input)
                ])
                output = text
                tokenEstimate = TokenCounter.estimateTokens(text)
            } catch {
                output = "Feil: \(error.localizedDescription)"
            }
        }
        isStreaming = false
    }
}

#Preview {
    NavigationStack {
        StreamingCoachView()
            .environmentObject(CoachEngineManager())
    }
}
