import SwiftUI

struct ManagedProxyAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var baseURL: String = Secrets.shared.proxyBaseURL?.absoluteString ?? ""
    @State private var token: String = Secrets.shared.proxyAccessToken ?? ""
    @State private var status: String? = nil
    private let oauth = OAuthWebAuthCoordinator()

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
                        Button("Login with Proxy (Web)") { if DeveloperFlags.enableManagedProxy { startAuth() } else { status = "Managed Proxy disabled" } }
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

private extension ManagedProxyAuthView {
    func startAuth() {
        guard DeveloperFlags.enableManagedProxy else { status = "Managed Proxy disabled"; return }
        guard let base = URL(string: baseURL) else { status = "Invalid base URL"; return }
        // Expect your proxy to start OAuth at /oauth/start and redirect to lifehackapp://oauth?token=...
        let url = base.appendingPathComponent("/oauth/start")
        status = "Opening login…"
        oauth.startAuth(authURL: url) { result in
            switch result {
            case .success(let callback):
                if let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false),
                   let tokenItem = comps.queryItems?.first(where: { $0.name == "token" })?.value {
                    self.token = tokenItem
                    Secrets.shared.setProxyAccessToken(tokenItem)
                    status = "Signed in"
                } else {
                    status = "Login finished, but no token found"
                }
            case .failure(let error):
                status = "Login failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview { ManagedProxyAuthView() }
