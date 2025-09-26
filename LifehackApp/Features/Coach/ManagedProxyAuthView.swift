import SwiftUI

struct ManagedProxyAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var baseURL: String = Secrets.shared.proxyBaseURL?.absoluteString ?? ""
    @State private var token: String = Secrets.shared.proxyAccessToken ?? ""
    @State private var status: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Proxy Server")) {
                    TextField("https://api.yourproxy.example", text: $baseURL)
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
                    HStack {
                        Button("Simulate OAuth Login") {
                            // Placeholder: implement real OAuth/WebAuth flow here
                            token = "demo_access_token"
                            status = "Signed in (demo token)"
                        }
                        Spacer()
                        Button("Save Token") {
                            Secrets.shared.setProxyAccessToken(token)
                            status = "Saved access token"
                        }
                    }
                }
                if let status = status { Text(status).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Managed Proxy Login")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

#Preview { ManagedProxyAuthView() }
