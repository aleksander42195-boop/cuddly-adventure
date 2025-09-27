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
        // Preflight: ensure API key present for online engines
        if engineManager.engine != .offlineHeuristics && Secrets.shared.openAIAPIKey == nil {
            output = "No API key configured. Tap Setup AI Coach to add one."
            isStreaming = false
            return
        }
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
                output = detailedErrorMessage(error)
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
                output = detailedErrorMessage(error)
            }
        }
        isStreaming = false
    }

    private func detailedErrorMessage(_ error: Error) -> String {
        let ns = error as NSError
        var parts: [String] = ["Error: \(ns.localizedDescription)"]
        if ns.domain.contains("OpenAI"), ns.code != 0 {
            parts.append("(code: \(ns.code))")
        }
        if let body = ns.userInfo["body"] as? String, !body.isEmpty {
            let snippet = body.prefix(300)
            parts.append("\nServer: \(snippet)")
        }
        if ns.code == 401 { parts.append("\nTip: Check that your API key is valid and not expired.") }
        if ns.code == 429 { parts.append("\nTip: Rate limited. Try again later or use a proxy baseURL.") }
        return parts.joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        StreamingCoachView()
            .environmentObject(CoachEngineManager())
    }
}
