import SwiftUI

struct CoachView: View {
    @State private var input = ""
    @State private var messages: [ChatMessage] = []
    @State private var isSending = false
    @State private var apiKeyInput: String = ""
    @State private var showKeySetup = false
    @State private var lastHTTPStatus: Int? = nil
    @State private var lastServerBody: String? = nil
    @EnvironmentObject private var engineManager: CoachEngineManager
    @EnvironmentObject private var app: AppState

    private var hasAPIKey: Bool { Secrets.shared.openAIAPIKey != nil }
    // Obtain the appropriate chat service via the manager (handles feature flags and fallbacks)
    private var onlineService: any ChatService { engineManager.makeService() }
    private var coachEngine: CoachEngine { engineManager.engine }
    private let spacingS: CGFloat = 12
    private let spacingXS: CGFloat = 6

    var body: some View {
        VStack {
            if lastHTTPStatus == 401 {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            Text("Authentication failed (invalid API key)")
                                .font(.subheadline)
                                .bold()
                        }
                        if let body = lastServerBody, !body.isEmpty {
                            Text(body.prefix(300))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Button { showKeySetup = true } label: {
                                Label("Update API Key", systemImage: "key.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            Button {
                                Secrets.shared.clearOpenAIOverride()
                                lastHTTPStatus = nil
                                lastServerBody = nil
                                messages.append(.assistant("API key cleared. Open setup to add a new one."))
                            } label: {
                                Label("Clear Key", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding([.horizontal, .top])
            }

            if !hasAPIKey {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("OpenAI API‑nøkkel mangler")
                            .font(.headline)
                        Text("Lim inn nøkkelen for å aktivere ekte coach-svar. (Lagrer sikkert i Keychain.)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        SecureField("sk-...", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        HStack {
                            Spacer()
                            Button {
                                saveKey()
                            } label: {
                                Label("Lagre nøkkel", systemImage: "key.fill")
                            }
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding([.horizontal, .top])
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: spacingS) {
                        ForEach(messages.indices, id: \.self) { idx in
                            let msg = messages[idx]
                            GlassCard {
                                VStack(alignment: .leading, spacing: spacingXS) {
                                    Text(msg.role == .user ? "You" : "Coach")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(msg.content)
                                }
                            }
                            .id(idx)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if messages.indices.last != nil {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(messages.indices.last!, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: spacingS) {
                TextField("Ask your coach…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSending)
                    .onSubmit { triggerSend() }

                Button {
                    triggerSend()
                } label: {
                    if isSending {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(isSendDisabled)
            }
            .padding()
        }
        .navigationTitle("Coach")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Coach chat with \(messages.count) messages.")
    }

    private var isSendDisabled: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
    }

    private func saveKey() {
        let apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return }
        Vault.saveOpenAIKey(apiKey)      // Keychain
        app.tapHaptic()
        apiKeyInput = ""
        // Confirmation assistant message
        messages.append(.assistant("Nøkkel lagret. Du kan nå stille spørsmål."))
    }

    private func triggerSend() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        messages.append(.user(text))
        input = ""
        app.tapHaptic()
        isSending = true
        // Offline heuristic branch: synthesize a quick local reply using local rules
        if engineManager.engine == .offlineHeuristics {
            Task {
                do {
                    let replyText = try await OfflineHeuristicsService().send(messages: messages)
                    await MainActor.run {
                        messages.append(.assistant(replyText))
                        isSending = false
                    }
                } catch {
                    await MainActor.run {
                        messages.append(.assistant("Feil: \(error.localizedDescription)"))
                        isSending = false
                    }
                }
            }
            return
        }
        Task {
            do {
                let replyText = try await onlineService.send(messages: messages)
                await MainActor.run {
                    messages.append(.assistant(replyText))
                    isSending = false
                }
            } catch {
                let ns = error as NSError
                let body = ns.userInfo["body"] as? String
                await MainActor.run {
                    lastHTTPStatus = ns.code
                    lastServerBody = body
                    messages.append(.assistant("Feil: \(ns.localizedDescription)"))
                    isSending = false
                }
            }
        }
    }
}

#Preview("CoachView") {
    NavigationView { CoachView() }
        .environmentObject(AppState())
        .environmentObject(CoachEngineManager())
}
