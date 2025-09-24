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
            }
        }
        .navigationTitle("Coach Engine")
    }
}

#Preview { CoachEngineSettingsView().environmentObject(CoachEngineManager()) }
