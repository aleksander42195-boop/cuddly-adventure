import SwiftUI

struct StreamingCoachView: View {
    @EnvironmentObject var engineManager: CoachEngineManager
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var tokenEstimate: Int = 0
    @State private var isStreaming = false
    @State private var showKeySetup = false
    @State private var lastHTTPStatus: Int? = nil

    var body: some View {
        VStack(spacing: 10) {
            if lastHTTPStatus == 401 {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            Text("Authentication failed (invalid API key)")
                                .font(.subheadline)
                                .bold()
                        }
                        Text("Your OpenAI API key was rejected. Update the key or clear it to switch back to setup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                showKeySetup = true
                            } label: {
                                Label("Update API Key", systemImage: "key.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button {
                                Secrets.shared.clearOpenAIOverride()
                                lastHTTPStatus = nil
                                output = "API key cleared. Open setup to add a new one."
                            } label: {
                                Label("Clear Key", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if lastHTTPStatus == 429 {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
                            Text("Rate limited (429)")
                                .font(.subheadline)
                                .bold()
                        }
                        Text("You’ve hit the rate limit. Please try again in a bit, or switch to the offline coach temporarily.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                Task { await ask() }
                            } label: { Label("Try Again", systemImage: "arrow.clockwise") }
                            .buttonStyle(.borderedProminent)
                            Button {
                                engineManager.engine = .offlineHeuristics
                                lastHTTPStatus = nil
                                output = "Switched to offline coach."
                            } label: { Label("Switch to Offline", systemImage: "brain") }
                        }
                    }
                }
            }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showKeySetup = true
                } label: {
                    Label("API Key", systemImage: "key.fill")
                }
            }
        }
        .sheet(isPresented: $showKeySetup) {
            NavigationStack {
                ChatGPTLoginView()
                    .navigationTitle("AI Coach Setup")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showKeySetup = false }
                        }
                    }
            }
        }
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
                let ns = error as NSError
                await MainActor.run {
                    lastHTTPStatus = ns.code
                    output = detailedErrorMessage(error)
                }
            }
        } else {
            // fallback: ikke-streamende service
            do {
                let text = try await service.send(messages: [
                    .init(role: .system, content: "Du er Lifehack Coach – kort, vennlig, konkret."),
                    .init(role: .user, content: input)
                ])
                await MainActor.run {
                    output = text
                    tokenEstimate = TokenCounter.estimateTokens(text)
                }
            } catch {
                let ns = error as NSError
                await MainActor.run {
                    lastHTTPStatus = ns.code
                    output = detailedErrorMessage(error)
                }
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
