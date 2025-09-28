import SwiftUI

struct CoachEngineSettingsView: View {
    @EnvironmentObject var engineManager: CoachEngineManager
    @State private var tempAPIKey: String = Vault.loadOpenAIKey() ?? ""

    var body: some View {
        Form {
            Section(header: Text("Coach engine")) {
                Picker("Motor", selection: $engineManager.engine) {
                    ForEach(CoachEngine.allCases) { eng in
                        Text(eng.rawValue).tag(eng)
                    }
                }
                Text(engineManager.engine.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            if engineManager.engine != .offlineHeuristics {
                Section(header: Text("OpenAI")) {
                    SecureField("API-nøkkel", text: $tempAPIKey)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Valgfri baseURL (proxy)", text: $engineManager.baseURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    TextField("Responses-modell", text: $engineManager.responsesModel)
                    TextField("Chat-modell", text: $engineManager.chatModel)

                    Button("Lagre nøkkel i Keychain") {
                        Vault.saveOpenAIKey(tempAPIKey)
                    }
                }

                if DeveloperFlags.enableManagedProxy {
                    Section(header: Text("Managed Proxy")) {
                        if engineManager.engine == .managedProxy {
                            NavigationLink("Login / Configure", destination: ManagedProxyConfigInlineView())
                            if let url = Secrets.shared.proxyBaseURL { Text("Base: \(url.absoluteString)").font(.footnote) }
                            Text(Secrets.shared.proxyAccessToken == nil ? "Status: signed out" : "Status: signed in").font(.footnote)
                        } else {
                            Text("Switch engine to Managed Proxy to configure.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Coach Engine")
    }
}

#Preview { CoachEngineSettingsView().environmentObject(CoachEngineManager()) }

// Minimal inline configuration view to avoid referencing external ManagedProxyAuthView
private struct ManagedProxyConfigInlineView: View {
    @State private var baseURL: String = Secrets.shared.proxyBaseURL?.absoluteString ?? ""
    @State private var token: String = Secrets.shared.proxyAccessToken ?? ""
    @State private var status: String? = nil

    var body: some View {
        Form {
            Section(header: Text("Proxy Server")) {
                TextField("https://your-proxy.example", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button("Save Base URL") {
                    Secrets.shared.setProxyBaseURL(baseURL)
                    status = "Saved base URL"
                }
            }
            Section(header: Text("Sign In")) {
                SecureField("Access token", text: $token)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button("Save Token") {
                    Secrets.shared.setProxyAccessToken(token)
                    status = "Saved access token"
                }
            }
            if let status = status { Text(status).font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Managed Proxy")
    }
}
